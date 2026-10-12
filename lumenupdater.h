#pragma once

#include <QObject>
#include <QString>
#include <QProcess>
#include <QNetworkAccessManager>

class QNetworkReply;
class QFile;

// One-click self update for the three ways Lumen Launcher is installed:
//  flatpak  - flatpak update (through the host when running sandboxed), falling back to the install.sh one-liner
//  appimage - downloads the new AppImage next to the current one and swaps it in (the old one is kept on any failure)
//  script   - anything else: runs the install.sh one-liner
class LumenUpdater : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode CONSTANT)
    Q_PROPERTY(bool running READ running NOTIFY stateChanged)
    Q_PROPERTY(bool done READ done NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY stateChanged)
    Q_PROPERTY(QString manualCommand READ manualCommand CONSTANT)

public:
    explicit LumenUpdater(QObject *parent = nullptr);

    QString mode() const { return m_mode; }
    bool running() const { return m_running; }
    bool done() const { return m_done; }
    QString status() const { return m_status; }
    QString error() const { return m_error; }
    qreal progress() const { return m_progress; }
    QString manualCommand() const;

    // assetUrl: the release's .AppImage download, only used for AppImage installs
    Q_INVOKABLE void start(const QString &assetUrl = QString());
    Q_INVOKABLE void restart();

signals:
    void stateChanged();

private:
    void setState(bool running, bool done, const QString &status, const QString &error, qreal progress);
    void startScript();
    void startAppImage(const QString &assetUrl);
    void fail(const QString &error);
    void onAppImageFinished();

    QString m_mode;
    bool m_running = false;
    bool m_done = false;
    QString m_status;
    QString m_error;
    qreal m_progress = -1;
    QString m_tail;
    QProcess *m_proc = nullptr;
    QNetworkAccessManager m_net;
    QNetworkReply *m_reply = nullptr;
    QFile *m_file = nullptr;
    QString m_appImagePath;
    QString m_tmpPath;
};
