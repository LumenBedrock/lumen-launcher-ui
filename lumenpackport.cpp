#include "lumenpackport.h"

#include <QCryptographicHash>
#include <QDesktopServices>
#include <QDirIterator>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QNetworkReply>
#include <QUuid>
#include <zip.h>
#include <QFileInfo>
#include <QJsonValue>

static const QString kBase = QStringLiteral("https://presence.lumenclient.net");
static QString lumenHome() { return QDir::homePath() + "/Lumen"; }
static QString newId() { return QUuid::createUuid().toString(QUuid::Id128); } // 32 hex

static QString installId() {
    const QString path = lumenHome() + "/lumen_install_id";
    QFile f(path);
    if (f.open(QIODevice::ReadOnly)) {
        const QString s = QString::fromUtf8(f.readAll()).trimmed();
        if (s.size() == 32) return s;
        f.close();
    }
    const QString id = newId();
    QFile w(path);
    if (w.open(QIODevice::WriteOnly)) { w.write(id.toUtf8()); w.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner); }
    return id;
}
static QString hwid() { // salted hash; the Worker hashes it again
    QFile f("/etc/machine-id");
    const QByteArray raw = f.open(QIODevice::ReadOnly) ? f.readAll().trimmed() : QByteArray();
    return QString::fromLatin1(QCryptographicHash::hash("lumen-hw-v1|" + raw, QCryptographicHash::Sha256).toHex().left(32));
}

// Zips a texture pack folder (entries relative to it, symlinks skipped) into zipPath; "" = ok.
static QString zipFolder(const QString &dir, const QString &zipPath) {
    zip_t *za = zip_open(QFile::encodeName(zipPath).constData(), ZIP_CREATE | ZIP_TRUNCATE, nullptr);
    if (!za) return "cannot write the temporary pack file";
    const QDir d(dir);
    QDirIterator it(dir, QDir::Files | QDir::NoSymLinks, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString p = it.next();
        zip_source_t *s = zip_source_file(za, QFile::encodeName(p).constData(), 0, 0);
        if (!s || zip_file_add(za, d.relativeFilePath(p).toUtf8().constData(), s, ZIP_FL_ENC_UTF_8) < 0) {
            if (s) zip_source_free(s);
            zip_discard(za);
            return "cannot zip the pack folder";
        }
    }
    return zip_close(za) == 0 ? QString() : "cannot zip the pack folder";
}

bool LumenPackPort::isDir(const QUrl &url) { return url.isLocalFile() && QFileInfo(url.toLocalFile()).isDir(); }

LumenPackPort::LumenPackPort(QObject *parent) : QObject(parent) {
    m_poll.setInterval(3000);
    connect(&m_poll, &QTimer::timeout, this, &LumenPackPort::refresh);
}

QByteArray LumenPackPort::token() const {
    QFile f(lumenHome() + "/lumen_presence_token");
    const QByteArray t = f.open(QIODevice::ReadOnly) ? f.readAll().trimmed() : QByteArray();
    return t.size() <= 100 ? t : QByteArray();
}

void LumenPackPort::apply(const QJsonObject &o) {
    if (o.contains("role")) m_role = o.value("role").toString();
    if (o.contains("allowed")) m_allowed = o.value("allowed").toBool();
    if (o.contains("balance")) m_balance = o.value("balance").toInt();
    if (o.contains("cost")) m_cost = o.value("cost").toInt(100);
    if (o.contains("next")) m_next = o.value("next").isNull() ? QString() : QLocale().toString(QDateTime::fromMSecsSinceEpoch(o.value("next").toVariant().toLongLong()), QLocale::ShortFormat);
    m_error.clear();
    if (o.contains("configured") && !o.value("configured").toBool()) m_status = tr("Pack porting is not available yet.");
    else if (!o.value("job").isNull() && o.contains("job")) m_status = tr("Porting...");
    else if (!m_busy) m_status.clear();
}

void LumenPackPort::refresh() {
    if (!linked()) { emit stateChanged(); return; }
    QNetworkRequest req{QUrl(kBase + "/pack/balance")}; // the hashed machine id goes only with an actual port
    req.setRawHeader("Authorization", "Bearer " + token());
    QNetworkReply *r = m_net.get(req);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        if (r->error() == QNetworkReply::NoError || r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 403) apply(o); // 403 = rank not allowed
        else if (r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 401) { m_error = tr("Your Discord login expired, log in again."); logout(); return; }
        else if (!m_busy) m_error = tr("Could not reach Lumen.");
        emit stateChanged();
    });
    QNetworkRequest me{QUrl(kBase + "/me")};
    me.setRawHeader("Authorization", "Bearer " + token());
    QNetworkReply *m = m_net.get(me);
    connect(m, &QNetworkReply::finished, this, [this, m]() {
        m->deleteLater();
        if (m->error() != QNetworkReply::NoError) return;
        const QJsonObject o = QJsonDocument::fromJson(m->readAll()).object();
        m_name = o.value("name").toString();
        if (m_role.isEmpty()) m_role = o.value("role").toString();
        emit stateChanged();
    });
}

void LumenPackPort::port(const QString &pathOrUrl) {
    if (m_busy || !linked()) return;
    const QString path = pathOrUrl.startsWith("file:") ? QUrl(pathOrUrl).toLocalFile() : pathOrUrl; // drop urls are percent-encoded
    // a pack folder is zipped to a temp file first; that zip is what the job describes (and what the upload will send), removed when the job ends
    QString file = path, tmpZip;
    if (QFileInfo(path).isDir()) {
        tmpZip = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/lumen-port-" + newId() + ".mcpack";
        const QString e = zipFolder(path, tmpZip);
        if (!e.isEmpty()) { QFile::remove(tmpZip); m_error = tr("Could not zip the pack folder."); emit stateChanged(); return; }
        file = tmpZip;
    }
    QFile pf(file);
    if (!pf.open(QIODevice::ReadOnly)) { if (!tmpZip.isEmpty()) QFile::remove(tmpZip); m_error = tr("Cannot read the pack."); emit stateChanged(); return; }
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(&pf);
    const QJsonObject pack{{"name", (QFileInfo(path).isDir() ? QFileInfo(path).fileName() + ".mcpack" : QFileInfo(path).fileName()).left(120)}, {"size", pf.size()}, {"sha256", QString::fromLatin1(hash.result().toHex())}};
    pf.close();
    m_busy = true; m_error.clear(); m_status = tr("Porting...");
    emit stateChanged();
    m_poll.start();
    QNetworkRequest req{QUrl(kBase + "/pack/port")};
    req.setRawHeader("Authorization", "Bearer " + token());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setTransferTimeout(330000);
    const QJsonObject body{{"inst", installId()}, {"hw", hwid()}, {"job", newId()}, {"pack", pack}};
    QNetworkReply *r = m_net.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(r, &QNetworkReply::finished, this, [this, r, tmpZip]() {
        r->deleteLater();
        if (!tmpZip.isEmpty()) QFile::remove(tmpZip); // job ended
        m_poll.stop();
        m_busy = false;
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QString e = o.value("error").toString();
        apply(o);
        m_status = o.value("state").toString() == "done" ? tr("Done. %1 tokens charged.").arg(m_cost) : QString();
        if (!e.isEmpty()) {
            m_error = e == "funds" ? tr("Not enough tokens. Next refill: %1").arg(m_next)
                    : e == "busy" ? tr("A port is already running.")
                    : e == "rate" ? tr("You can port one pack every 5 minutes. Try again in %1 s.").arg(o.value("wait").toInt())
                    : e == "unavailable" ? tr("Pack porting is not available yet. Nothing was charged.")
                    : e == "login" ? tr("Log in with Discord first.")
                    : e == "rank" ? tr("Your rank can't use pack porting.")
                    : tr("The port failed, tokens were refunded (%1).").arg(e);
        }
        emit stateChanged();
    });
}

void LumenPackPort::login() {
    if (m_loggingIn) return;
    m_loggingIn = true; m_error.clear(); m_loginUrl.clear();
    emit stateChanged();
    QNetworkReply *r = m_net.get(QNetworkRequest{QUrl(kBase + "/pack/login/start")});
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QString state = o.value("state").toString(), url = o.value("url").toString();
        if (r->error() != QNetworkReply::NoError || state.isEmpty() || !url.startsWith(kBase)) {
            m_loggingIn = false; m_error = tr("Could not start the Discord login."); emit stateChanged(); return;
        }
        m_loginUrl = url; emit stateChanged();
        QDesktopServices::openUrl(QUrl(url));
        pollLogin(state, 100); // 100 x 3 s = 5 min
    });
}

void LumenPackPort::pollLogin(const QString &state, int tries) {
    QTimer::singleShot(3000, this, [this, state, tries]() {
        QNetworkReply *r = m_net.get(QNetworkRequest{QUrl(kBase + "/link/poll?state=" + state)});
        connect(r, &QNetworkReply::finished, this, [this, r, state, tries]() {
            r->deleteLater();
            const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
            const QString tok = o.value("token").toString();
            if (!tok.isEmpty() && tok.size() <= 100) {
                QFile f(lumenHome() + "/lumen_presence_token");
                QDir().mkpath(lumenHome());
                if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) { f.write(tok.toUtf8()); f.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner); }
                else m_error = tr("Could not save the login.");
                m_loggingIn = false; m_loginUrl.clear(); emit stateChanged();
                refresh();
            } else if (tries > 0 && (o.value("pending").toBool() || r->error() != QNetworkReply::ContentNotFoundError)) pollLogin(state, tries - 1);
            else { m_loggingIn = false; m_loginUrl.clear(); m_error = tr("The Discord login expired, try again."); emit stateChanged(); }
        });
    });
}

void LumenPackPort::logout() {
    QFile::remove(lumenHome() + "/lumen_presence_token");
    m_role.clear(); m_name.clear(); m_next.clear(); m_balance = 0; m_status.clear();
    emit stateChanged();
}
