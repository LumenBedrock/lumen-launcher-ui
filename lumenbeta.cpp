#include "lumenbeta.h"

#include <QCryptographicHash>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkReply>
#include <QProcess>
#include <QSettings>
#include <QTemporaryDir>
#include <cstdio>

static const QString kBase = QStringLiteral("https://presence.lumenclient.net");
static const QString kBundled = QStringLiteral("/app/share/lumen/liblumen.so");
static const QString kPubKey = QStringLiteral("/app/share/lumen/lumen-public.gpg");
static QString lumenHome() { return QDir::homePath() + "/Lumen"; }
static const QString kApp = QStringLiteral("io.github.LumenBedrock.LumenLauncher");
static QString liveSo() { return lumenHome() + "/mods/liblumen.so"; }

static QString fileHash(const QString &path, QCryptographicHash::Algorithm alg) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return QString();
    QCryptographicHash h(alg);
    h.addData(&f);
    return QString::fromLatin1(h.result().toHex());
}

LumenBeta::LumenBeta(QObject *parent) : QObject(parent) {
    // set kind before the first use: a result of the last launcher swap is read lazily from refresh()
}

// the beta build bakes its label into /app/share/lumen/BETA_LABEL (stable builds have no such file): what runs is what the card shows, however it was installed
static QString launcherLabel() {
    QFile f(QStringLiteral("/app/share/lumen/BETA_LABEL"));
    return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()).trimmed() : QString();
}
static QString resultFile() { return lumenHome() + "/.lumen-launcher-update-result"; }
static QString bundleFile() { return lumenHome() + "/.lumen-launcher-beta.flatpak"; }

// the host script of the last launcher swap leaves "ok beta" / "ok stable" / "failed ..." here; show it once
void LumenBeta::readUpdateResult() {
    QFile f(resultFile());
    if (!isLauncher() || !f.open(QIODevice::ReadOnly)) return;
    const QString res = QString::fromUtf8(f.readAll()).trimmed();
    f.close();
    QFile::remove(resultFile());
    QSettings st;
    if (res == "ok beta") {
        st.setValue(key("Build"), st.value(key("PendingBuild")));
        st.setValue(key("Version"), st.value(key("PendingVersion")));
        set(tr("Launcher beta %1 is installed.").arg(st.value(key("Version")).toString()));
    } else if (res == "ok stable") {
        st.remove(key("Version"));
        set(tr("The stable launcher is back."));
    } else if (res.startsWith("failed stable-restored")) {
        st.remove(key("Version"));
        set(QString(), tr("The launcher beta did not install, so the stable launcher was put back."));
    } else if (res.startsWith("failed running")) {
        set(QString(), tr("The update did not start because the launcher or the game was still running. Close both and try again."));
    } else if (!res.isEmpty()) {
        set(QString(), tr("The launcher update failed (%1). If the launcher is missing, run the Lumen install command again.").arg(res));
    }
}

// copy of the client that is about to be replaced: ~/Lumen/.beta-backup/liblumen-<sha8>.so (kept, one file per distinct build)
static void backupLive() {
    const QString live = liveSo();
    if (!QFile::exists(live)) return;
    const QString dir = lumenHome() + "/.beta-backup";
    QDir().mkpath(dir);
    const QString dst = dir + "/liblumen-" + fileHash(live, QCryptographicHash::Sha256).left(8) + ".so";
    if (!QFile::exists(dst)) QFile::copy(live, dst);
}
static QString betaRecordFile() { return lumenHome() + "/.lumen-beta-client"; } // version / build / sha256 of the beta this launcher installed
QString LumenBeta::recordedSha() const {
    const QString s = QSettings().value(key("Sha")).toString();
    if (!s.isEmpty()) return s;
    QFile f(betaRecordFile());
    if (!f.open(QIODevice::ReadOnly)) return QString();
    for (const QByteArray &l : f.readAll().split('\n'))
        if (l.startsWith("sha256=")) return QString::fromLatin1(l.mid(7)).trimmed();
    return QString();
}

QString LumenBeta::installed() const {
    QSettings st;
    if (isLauncher()) return launcherLabel().isEmpty() ? tr("Stable") : launcherLabel();
    const QString live = fileHash(liveSo(), QCryptographicHash::Sha256);
    if (live.isEmpty()) return tr("Not installed");
    if (live == recordedSha()) return st.value(key("Version")).toString(); // a beta installed through this launcher
    if (!m_offerSha.isEmpty() && live == m_offerSha) return m_version;      // the offered beta, however it got there (installer script)
    if (live == fileHash(kBundled, QCryptographicHash::Sha256)) return tr("Stable");
    return tr("Local build"); // a dev/test build replaced liblumen.so: never shown as "Stable"
}

void LumenBeta::set(const QString &status, const QString &error, bool busy, qreal progress) {
    m_status = status; m_error = error; m_busy = busy; m_progress = progress;
    emit stateChanged();
}

void LumenBeta::refresh() {
    readUpdateResult();
    // Flatpak only: needs the bundled public key; AppImage/script installs never get the Beta page
    if (m_busy || !QFile::exists(kPubKey)) return;
    // lumen_beta_token comes from the Discord beta installer, lumen_presence_token from linking Discord in the game
    QFile tf(lumenHome() + "/lumen_beta_token");
    if (!tf.open(QIODevice::ReadOnly)) {
        tf.setFileName(lumenHome() + "/lumen_presence_token");
        if (!tf.open(QIODevice::ReadOnly)) return; // not linked
    }
    const QByteArray tok = tf.readAll().trimmed();
    if (tok.isEmpty() || tok.size() > 100) return;
    QNetworkRequest req{QUrl(kBase + "/update?channel=beta")};
    req.setRawHeader("Authorization", "Bearer " + tok); // header, not the url: never ends up in logs
    QNetworkReply *r = m_net.get(req);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) return;
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        m_capable = o.value("canBeta").toBool();
        const QJsonObject offer = isLauncher() ? o.value("launcher").toObject() : o;
        m_url = QUrl(offer.value("url").toString());
        if (m_capable && o.value("channel").toString() == "beta" && !m_url.isEmpty())
            check(offer.value("manifest").toString().toUtf8(), offer.value("sig").toString().toUtf8());
        else emit stateChanged();
    });
}

// signature first: nothing unsigned is even offered, let alone downloaded
void LumenBeta::check(const QByteArray &manifest, const QByteArray &sig) {
    QTemporaryDir tmp;
    if (!tmp.isValid()) return;
    const QString mp = tmp.filePath("manifest.json"), sp = tmp.filePath("manifest.json.sig");
    QFile mf(mp), sf(sp);
    if (!mf.open(QIODevice::WriteOnly) || !sf.open(QIODevice::WriteOnly)) return;
    mf.write(manifest); mf.close(); sf.write(sig); sf.close();
    QProcess gpgv;
    gpgv.start("gpgv", {"--homedir", tmp.path(), "--keyring", kPubKey, sp, mp});
    if (!gpgv.waitForFinished(15000) || gpgv.exitCode() != 0) {
        set(QString(), tr("The beta's signature is not valid, so it was ignored."));
        return;
    }
    const QJsonObject m = QJsonDocument::fromJson(manifest).object();
    const qint64 build = m.value("build").toVariant().toLongLong();
    const qint64 have = QSettings().value(key("Build"), 0).toLongLong();
    m_manifest = manifest;
    m_version = m.value("version").toString();
    m_build = QDateTime::fromSecsSinceEpoch(build).toString("yyyy-MM-dd HH:mm"); // build = unix time of the upload
    m_notes = m.value("notes").toString();
    QStringList g;
    for (const QJsonValue &v : m.value("games").toArray()) g << v.toString();
    m_games = g.join(", ");
    // older (replayed) manifests are never offered; a launcher beta is offered until it is installed
    if (isLauncher()) // news when the running launcher is not that version; an older (replayed) manifest than the last recorded swap is never offered
        m_update = launcherLabel() != m_version && build >= have;
    else {
        m_offerSha = m.value("sha256").toString();
        const QString live = fileHash(liveSo(), QCryptographicHash::Sha256), bundled = fileHash(kBundled, QCryptographicHash::Sha256);
        if (live == m_offerSha) { m_state = "current"; m_update = false; }
        else if (!live.isEmpty() && live == recordedSha()) { m_state = "older"; m_update = build > have; }  // an older beta of ours; an older offer than that is never pushed
        else if (live.isEmpty() || (!bundled.isEmpty() && live == bundled)) { m_state = "stable"; m_update = build >= have; }
        else { m_state = "local"; m_update = false; } // a dev/test build: not replaced silently, the card offers "Install beta anyway"
    }
    set(QString());
}

void LumenBeta::install() {
    if (m_busy || !m_update) return;
    const QJsonObject m = QJsonDocument::fromJson(m_manifest).object();
    const qint64 build = m.value("build").toVariant().toLongLong();
    const QString want = m.value("sha256").toString(), ver = m.value("version").toString();
    set(tr("Downloading beta %1...").arg(ver), QString(), true, 0);
    QNetworkRequest req(m_url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *r = m_net.get(req);
    connect(r, &QNetworkReply::downloadProgress, this, [this](qint64 got, qint64 total) {
        if (total > 0) { m_progress = qreal(got) / total; emit stateChanged(); }
    });
    connect(r, &QNetworkReply::finished, this, [=]() {
        r->deleteLater();
        const QByteArray data = r->error() == QNetworkReply::NoError ? r->readAll() : QByteArray();
        QString err;
        if (data.isEmpty()) err = tr("download failed");
        else if (!isLauncher() && data.left(4) != QByteArray("\x7f" "ELF", 4)) err = tr("not a valid client");
        else if (isLauncher() && data.size() < 1000000) err = tr("not a valid launcher bundle");
        else if (QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex()) != want) err = tr("checksum mismatch");
        if (!err.isEmpty()) return finishInstall(err);
        auto done = [=](const QString &e) {
            if (e.isEmpty()) {
                QSettings st;
                if (!isLauncher()) {
                    st.setValue(key("Build"), build);
                    st.setValue(key("Version"), ver);
                    st.setValue(key("Sha"), want);
                    QFile rec(betaRecordFile());
                    if (rec.open(QIODevice::WriteOnly)) rec.write(QString("version=%1\nbuild=%2\nsha256=%3\n").arg(ver).arg(build).arg(want).toUtf8());
                } else { // recorded as installed by readUpdateResult() once the swap really happened
                    st.setValue(key("PendingBuild"), build);
                    st.setValue(key("PendingVersion"), ver);
                    m_pending = "beta";
                }
            }
            finishInstall(e);
        };
        if (isLauncher()) {
            // Installing over the running app fails ("Directory not empty"): only stage the verified bundle in ~/Lumen (the host sees it too);
            // applyAndRestart() swaps it in after the launcher has exited.
            QFile out(bundleFile());
            if (!out.open(QIODevice::WriteOnly) || out.write(data) != data.size()) return done(tr("cannot write the bundle"));
            out.close();
            return done(QString());
        }
        const QString dst = liveSo(), part = dst + ".beta-new";
        QDir().mkpath(lumenHome() + "/mods");
        QFile out(part);
        if (!out.open(QIODevice::WriteOnly) || out.write(data) != data.size()) return done(tr("cannot write the client"));
        out.close();
        backupLive(); // into ~/Lumen/.beta-backup, never next to liblumen.so (a second lib in mods loads twice)
        // rename is atomic and safe while the game runs (it keeps the old inode); the new client loads on the next start
        done(::rename(QFile::encodeName(part), QFile::encodeName(dst)) != 0 ? tr("cannot replace the client") : QString());
    });
}

void LumenBeta::finishInstall(const QString &err) {
    if (err.isEmpty()) { m_update = false; if (!isLauncher()) m_state = "current"; }
    set(err.isEmpty() ? (isLauncher() ? tr("Launcher beta %1 is ready. Restart to finish the update.").arg(m_version)
                                      : tr("Beta %1 installed. It loads the next time you start the game.").arg(m_version)) : QString(),
        err.isEmpty() ? QString() : tr("Beta update failed: %1").arg(err));
}

void LumenBeta::applyAndRestart() {
    if (!isLauncher() || m_pending.isEmpty()) return;
    // detached host script: wait for every instance of the app (launcher and game) to exit, uninstall (data is kept, no --delete-data), fresh install of
    // the staged bundle (or the stable launcher from the lumen-launcher remote), record the result, start the launcher again. A bundle that does not
    // install falls back to the stable launcher so nobody is left without one.
    const QString script = QString(
        "APP=%1; B='%2'; R='%3'; MODE=%4\n"
        "for i in $(seq 1 120); do flatpak ps --columns=application 2>/dev/null | grep -qx \"$APP\" || break; sleep 1; done\n"
        "if flatpak ps --columns=application 2>/dev/null | grep -qx \"$APP\"; then echo 'failed running' > \"$R\"; exec flatpak run \"$APP\"; fi\n"
        "# a system-wide stable launcher stays (no sudo): the beta is a user install that shadows it, and \"stable\" just removes the user copy\n"
        "SYS=0; if flatpak info --system \"$APP\" >/dev/null 2>&1; then SYS=1; fi\n"
        "if flatpak info --user \"$APP\" >/dev/null 2>&1; then flatpak uninstall --user -y --noninteractive \"$APP\" >/dev/null 2>&1 || true; fi\n"
        "stable_back() { [ \"$SYS\" = 1 ] || flatpak install --user -y --noninteractive lumen-launcher \"$APP\" >/dev/null 2>&1; }\n"
        "# leftover remotes of earlier bundle installs (named lumenlauncher*-origin, no URL); never the ones that have a URL\n"
        "clean() { for r in $(flatpak remotes --user --show-disabled --columns=name,url 2>/dev/null | awk -F'\\t' '$1 ~ /^lumenlauncher[0-9]*-origin$/ && $2 == \"\" {print $1}'); do flatpak remote-delete --user --force \"$r\" >/dev/null 2>&1 || true; done; }\n"
        "if [ \"$MODE\" = beta ] && flatpak install --user --bundle -y --noninteractive \"$B\" >/dev/null 2>&1; then echo 'ok beta' > \"$R\"\n"
        "elif [ \"$MODE\" = stable ] && stable_back; then echo 'ok stable' > \"$R\"; clean\n"
        "elif stable_back; then echo 'failed stable-restored' > \"$R\"; clean\n"
        "else echo 'failed no-launcher' > \"$R\"; fi\n"
        "rm -f \"$B\"\n"
        "exec flatpak run \"$APP\"\n").arg(kApp, bundleFile(), resultFile(), m_pending);
    QProcess::startDetached("flatpak-spawn", {"--host", "setsid", "-f", "bash", "-c", script});
    QCoreApplication::quit();
}

void LumenBeta::installAnyway() {
    if (isLauncher() || !canInstallAnyway() || m_busy) return;
    m_update = true; // the card asked for it: the local build is backed up as liblumen.so.bak by install()
    install();
}

// the client that came with this launcher again (same bookkeeping as lumen-launcher.sh, so it is not replaced by mistake)
void LumenBeta::restoreStable() {
    if (m_busy) return;
    if (isLauncher()) {
        // switching back also happens after the launcher has exited (applyAndRestart): uninstall, then install from the signed lumen-launcher remote
        m_pending = "stable";
        m_update = !m_version.isEmpty();
        set(tr("Restart to switch back to the stable launcher."));
        return;
    }
    backupLive();
    const QString dst = liveSo(), part = dst + ".new";
    QFile::remove(part);
    if (!QFile::exists(kBundled) || !QFile::copy(kBundled, part) || ::rename(QFile::encodeName(part), QFile::encodeName(dst)) != 0) {
        set(QString(), tr("Could not restore the stable client."));
        return;
    }
    QFile rec(lumenHome() + "/mods/.lumen-bundled-md5");
    if (rec.open(QIODevice::WriteOnly)) rec.write(fileHash(kBundled, QCryptographicHash::Md5).toLatin1() + "\n");
    QSettings().remove(key("Sha")); // keep the build: an older beta must not be offered again
    QFile::remove(betaRecordFile());
    m_state = "stable";
    m_update = !m_version.isEmpty();
    set(tr("Stable client restored. It loads the next time you start the game."));
}
