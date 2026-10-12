#include "lumenupdater.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <cstdio>

static const char *const kApp = "io.github.LumenBedrock.LumenLauncher";
static const char *const kInstall = "curl -fsSL https://raw.githubusercontent.com/LumenBedrock/lumen-launcher/main/install.sh | bash";

LumenUpdater::LumenUpdater(QObject *parent) : QObject(parent) {
    if (QFile::exists("/.flatpak-info"))
        m_mode = "flatpak";
    else if (!qEnvironmentVariable("APPIMAGE").isEmpty() && qEnvironmentVariableIsSet("LUMEN_APPIMAGE"))
        m_mode = "appimage";
    else
        m_mode = "script";
    m_appImagePath = qEnvironmentVariable("APPIMAGE");
}

QString LumenUpdater::manualCommand() const {
    return QString::fromLatin1(kInstall);
}

void LumenUpdater::setState(bool running, bool done, const QString &status, const QString &error, qreal progress) {
    m_running = running;
    m_done = done;
    m_status = status;
    m_error = error;
    m_progress = progress;
    emit stateChanged();
}

void LumenUpdater::fail(const QString &error) {
    setState(false, false, tr("Update failed"), error, -1);
}

void LumenUpdater::start(const QString &assetUrl) {
    if (m_running)
        return;
    setState(true, false, tr("Starting update..."), QString(), -1);
    if (m_mode == "appimage")
        startAppImage(assetUrl);
    else
        startScript();
}

void LumenUpdater::startScript() {
    // Flatpak update first (works for user and system installs), the installer one-liner as fallback.
    // The installer is told not to start the launcher again (LUMEN_NO_START).
    QString script = QString(
        "set -o pipefail\nAPP=%1\n"
        "if flatpak info \"$APP\" >/dev/null 2>&1; then\n"
        "  echo 'Updating Lumen Launcher with Flatpak...'\n"
        "  flatpak update -y --noninteractive \"$APP\" 2>&1 && exit 0\n"
        "  echo 'Flatpak update did not work, trying the installer...'\n"
        "fi\n"
        "echo 'Running the Lumen installer...'\n"
        "if command -v curl >/dev/null 2>&1; then GET='curl -fsSL'; elif command -v wget >/dev/null 2>&1; then GET='wget -qO-'; else echo 'Neither curl nor wget is installed.' >&2; exit 127; fi\n"
        "$GET https://raw.githubusercontent.com/LumenBedrock/lumen-launcher/main/install.sh | LUMEN_NO_START=1 bash 2>&1\n"
        ).arg(kApp);

    m_tail.clear();
    m_proc = new QProcess(this);
    m_proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_proc, &QProcess::readyRead, this, [this]() {
        const QString out = QString::fromUtf8(m_proc->readAll());
        m_tail = (m_tail + out).right(4000);
        // flatpak redraws its progress bar with \r; show the latest non-empty line
        const QStringList lines = out.split(QRegularExpression("[\r\n]+"), Qt::SkipEmptyParts);
        if (!lines.isEmpty()) {
            m_status = lines.last().trimmed().left(140);
            emit stateChanged();
        }
    });
    connect(m_proc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) {
            m_proc->deleteLater(); m_proc = nullptr;
            fail(tr("Could not start the updater. Run this command in a terminal instead:\n%1").arg(manualCommand()));
        }
    });
    connect(m_proc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus st) {
        m_proc->deleteLater(); m_proc = nullptr;
        if (st == QProcess::NormalExit && code == 0) {
            setState(false, true, tr("Updated. Restart Lumen Launcher to use the new version."), QString(), 1);
            return;
        }
        QString detail = m_tail.trimmed().split('\n').mid(qMax(0, m_tail.trimmed().split('\n').size() - 6)).join('\n');
        if (m_mode == "flatpak" && (code == 127 || m_tail.contains("Portal") || m_tail.contains("not allowed") || m_tail.contains("org.freedesktop.Flatpak")))
            detail = tr("This install is not allowed to update itself yet.");
        fail(tr("%1\nYour game, worlds and settings in ~/Lumen are untouched. You can also run this in a terminal:\n%2").arg(detail, manualCommand()));
    });

    if (m_mode == "flatpak")
        m_proc->start("flatpak-spawn", {"--host", "bash", "-c", script});
    else
        m_proc->start("bash", {"-c", script});
}

void LumenUpdater::startAppImage(const QString &assetUrl) {
    // no usable asset or a read-only location: use the installer instead of leaving the user stuck
    QFileInfo target(m_appImagePath);
    if (assetUrl.isEmpty() || !target.exists() || !QFileInfo(target.absolutePath()).isWritable()) {
        startScript();
        return;
    }
    m_tmpPath = m_appImagePath + ".lumen-update";
    m_file = new QFile(m_tmpPath, this);
    if (!m_file->open(QIODevice::WriteOnly)) {
        delete m_file; m_file = nullptr;
        fail(tr("Cannot write next to the AppImage (%1).").arg(target.absolutePath()));
        return;
    }
    m_status = tr("Downloading the new AppImage...");
    QNetworkRequest req{QUrl(assetUrl)};
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    m_reply = m_net.get(req);
    connect(m_reply, &QNetworkReply::readyRead, this, [this]() { m_file->write(m_reply->readAll()); });
    connect(m_reply, &QNetworkReply::downloadProgress, this, [this](qint64 got, qint64 total) {
        if (total > 0) {
            m_progress = qreal(got) / total;
            m_status = tr("Downloading the new AppImage... %1 / %2 MB").arg(got / 1048576).arg(total / 1048576);
            emit stateChanged();
        }
    });
    connect(m_reply, &QNetworkReply::finished, this, &LumenUpdater::onAppImageFinished);
}

void LumenUpdater::onAppImageFinished() {
    QNetworkReply *r = m_reply;
    m_reply = nullptr;
    m_file->write(r->readAll());
    m_file->close();
    const bool ok = r->error() == QNetworkReply::NoError;
    const QString err = r->errorString();
    r->deleteLater();
    m_file->deleteLater();
    m_file = nullptr;
    if (!ok) {
        QFile::remove(m_tmpPath);
        fail(tr("Download failed: %1\nThe current AppImage was not changed.").arg(err));
        return;
    }
    // sanity check: an ELF binary of a plausible size, so an error page can never replace the working AppImage
    QFile f(m_tmpPath);
    QByteArray magic;
    if (f.open(QIODevice::ReadOnly)) { magic = f.read(4); f.close(); }
    if (magic != QByteArray("\x7f" "ELF", 4) || QFileInfo(m_tmpPath).size() < 5 * 1024 * 1024) {
        QFile::remove(m_tmpPath);
        fail(tr("The downloaded file is not a valid AppImage. The current one was not changed."));
        return;
    }
    QFile::setPermissions(m_tmpPath, QFile::permissions(m_appImagePath) | QFileDevice::ExeOwner | QFileDevice::ExeUser);
    // renaming over the running file is safe on Linux; the running copy keeps its old inode until it exits
    if (::rename(QFile::encodeName(m_tmpPath), QFile::encodeName(m_appImagePath)) != 0) {
        QFile::remove(m_tmpPath);
        fail(tr("Could not replace %1. The current AppImage was not changed.").arg(m_appImagePath));
        return;
    }
    setState(false, true, tr("Updated. Restart Lumen Launcher to use the new version."), QString(), 1);
}

void LumenUpdater::restart() {
    if (m_mode == "flatpak")
        QProcess::startDetached("flatpak-spawn", {"--host", "bash", "-c", QString("sleep 1; exec flatpak run %1").arg(kApp)});
    else if (m_mode == "appimage")
        QProcess::startDetached(m_appImagePath, {});
    else
        QProcess::startDetached(QCoreApplication::applicationFilePath(), {});
    QCoreApplication::quit();
}
