#pragma once

#include <QDateTime>
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QUrl>

// "Pack porting" backend: Discord login, balance and port against the presence Worker (/pack/login/start + /link/poll, /me, /pack/balance, /pack/port).
// Login = the Discord link token in ~/Lumen/lumen_presence_token, the same file the game reads, so one login covers launcher and client. Identity sent with a port: random install id
// (~/Lumen/lumen_install_id) and a hashed machine id (the raw machine-id never leaves the machine).
class LumenPackPort : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool linked READ linked NOTIFY stateChanged)
    Q_PROPERTY(int balance READ balance NOTIFY stateChanged)
    Q_PROPERTY(int cost READ cost NOTIFY stateChanged)
    Q_PROPERTY(QString nextRefill READ nextRefill NOTIFY stateChanged) // "" = full
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(QString role READ role NOTIFY stateChanged)
    Q_PROPERTY(QString gamertag READ gamertag NOTIFY stateChanged)
    Q_PROPERTY(bool allowed READ allowed NOTIFY stateChanged)       // rank may port (Worker decides)
    Q_PROPERTY(bool loggingIn READ loggingIn NOTIFY stateChanged)
    Q_PROPERTY(QString loginUrl READ loginUrl NOTIFY stateChanged)  // shown when the browser did not open
public:
    explicit LumenPackPort(QObject *parent = nullptr);
    bool linked() const { return !token().isEmpty(); }
    int balance() const { return m_balance; }
    int cost() const { return m_cost; }
    QString nextRefill() const { return m_next; }
    bool busy() const { return m_busy; }
    QString status() const { return m_status; }
    QString error() const { return m_error; }
    QString role() const { return m_role; }
    QString gamertag() const { return m_name; }
    bool allowed() const { return m_allowed; }
    bool loggingIn() const { return m_loggingIn; }
    QString loginUrl() const { return m_loginUrl; }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool isDir(const QUrl &url); // a dropped local folder
    Q_INVOKABLE void login();   // Discord login in the browser, then polls for the token
    Q_INVOKABLE void logout();  // removes the local token file (the in-game link on the server is untouched)
    // Ports the pack file at `path` (a local path). TODO(pleeder's API): the file itself is not uploaded yet, only its name/size/sha256 go into the signed job.
    Q_INVOKABLE void port(const QString &pathOrUrl);

signals:
    void stateChanged();

private:
    QByteArray token() const;
    void apply(const QJsonObject &o);
    QNetworkAccessManager m_net;
    QTimer m_poll;
    int m_balance = 0, m_cost = 100;
    QString m_next, m_status, m_error, m_role, m_name, m_loginUrl;
    bool m_busy = false, m_allowed = true, m_loggingIn = false;
    void pollLogin(const QString &state, int tries);
};
