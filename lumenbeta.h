#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QNetworkAccessManager>

// Beta update channel for the Lumen client (liblumen.so) of Flatpak installs, shown on the launcher's Beta page.
// Only linked Owner/Developer/Beta Tester users get capable=true (the presence Worker decides, GET /update).
// A beta is offered only after gpgv verified the manifest signature against the bundled public key; installed only after the sha256 and ELF check.
class LumenBeta : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString kind READ kind WRITE setKind) // "client" (liblumen.so) or "launcher" (.flatpak bundle); set before refresh()
    Q_PROPERTY(bool capable READ capable NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY stateChanged) // -1 = not downloading
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(QString version READ version NOTIFY stateChanged)   // newest verified beta ("" = none published)
    Q_PROPERTY(QString build READ build NOTIFY stateChanged)
    Q_PROPERTY(QString notes READ notes NOTIFY stateChanged)
    Q_PROPERTY(QString games READ games NOTIFY stateChanged)       // game versions the build supports (optional in the manifest)
    Q_PROPERTY(bool restartNeeded READ restartNeeded NOTIFY stateChanged) // launcher update or switch back to stable is staged: restart to finish it
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY stateChanged)
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)       // client: "current" (the offered beta runs), "older" (an older beta of ours), "stable" (the bundled client), "local" (anything else)
    Q_PROPERTY(bool canInstallAnyway READ canInstallAnyway NOTIFY stateChanged) // a local build is installed: the beta may still be installed over it on purpose
    Q_PROPERTY(QString installed READ installed NOTIFY stateChanged) // what runs now: a beta version or "Stable"

public:
    explicit LumenBeta(QObject *parent = nullptr);
    bool capable() const { return m_capable; }
    bool busy() const { return m_busy; }
    qreal progress() const { return m_progress; }
    QString status() const { return m_status; }
    QString error() const { return m_error; }
    QString version() const { return m_version; }
    QString build() const { return m_build; }
    QString notes() const { return m_notes; }
    QString kind() const { return m_kind; }
    void setKind(const QString &k) { m_kind = k; }
    QString games() const { return m_games; }
    bool restartNeeded() const { return !m_pending.isEmpty(); }
    bool updateAvailable() const { return m_update; }
    QString installed() const;
    QString state() const { return m_state; }
    bool canInstallAnyway() const { return m_state == "local" && !m_version.isEmpty(); }

    Q_INVOKABLE void refresh();       // asks the Worker, verifies the signature
    Q_INVOKABLE void install();
    Q_INVOKABLE void installAnyway(); // client: replace a local build with the beta on purpose       // downloads and installs the beta found by refresh()
    Q_INVOKABLE void restoreStable(); // client: the one bundled with this launcher; launcher: reinstall from the public Lumen remote
    // launcher only: closes the launcher; a detached host script then waits until every instance has exited, swaps the app, writes a result file and starts it again
    Q_INVOKABLE void applyAndRestart();

signals:
    void stateChanged();

private:
    void set(const QString &status, const QString &error = QString(), bool busy = false, qreal progress = -1);
    void check(const QByteArray &manifest, const QByteArray &sig);
    void finishInstall(const QString &err);
    void readUpdateResult();
    bool isLauncher() const { return m_kind == "launcher"; }
    QString recordedSha() const;
    QString key(const char *k) const { return (isLauncher() ? "lumenLauncherBeta" : "lumenBeta") + QString(k); } // QSettings key

    QNetworkAccessManager m_net;
    QString m_kind = "client", m_games;
    bool m_capable = false, m_busy = false, m_update = false;
    QString m_pending; // "beta" or "stable" while a launcher swap is staged
    QString m_state, m_offerSha; // client card state (see state()), sha256 of the offered beta
    qreal m_progress = -1;
    QString m_status, m_error, m_version, m_build, m_notes;
    QByteArray m_manifest;
    QUrl m_url;
};
