#include "discordpresence.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QStandardPaths>

#ifndef LUMEN_DISCORD_APP_ID
#define LUMEN_DISCORD_APP_ID ""
#endif

bool DiscordPresence::send(int opcode, const QByteArray& json) {
    QByteArray frame;
    for (int v : {opcode, (int)json.size()})
        for (int i = 0; i < 4; i++)
            frame.append((char)((v >> (8 * i)) & 0xff));
    frame.append(json);
    return socket.write(frame) == frame.size() && socket.waitForBytesWritten(500);
}

DiscordPresence::DiscordPresence(QObject* parent) : QObject(parent) {
    poll.setInterval(5000);
    connect(&poll, &QTimer::timeout, this, &DiscordPresence::checkServer);
}

void DiscordPresence::setActivity() {
    // Only a friendly name leaves the machine, never the raw server address.
    QString host = lastServer.toLower(), state;
    if (host.contains("hive")) state = "on The Hive";
    else if (host.contains("swim")) state = "on Swim";
    else if (!host.isEmpty()) state = "Multiplayer";
    QJsonObject activity{{"details", "Playing Lumen"}, {"timestamps", QJsonObject{{"start", startTime}}}};
    if (!state.isEmpty()) activity["state"] = state;
    QJsonObject msg{{"cmd", "SET_ACTIVITY"}, {"nonce", QString::number(QDateTime::currentMSecsSinceEpoch())},
                    {"args", QJsonObject{{"pid", (qint64)QCoreApplication::applicationPid()}, {"activity", activity}}}};
    send(1, QJsonDocument(msg).toJson(QJsonDocument::Compact));
}

void DiscordPresence::checkServer() {
    if (socket.state() != QLocalSocket::ConnectedState)
        return;
    QFile f(serverFile);
    QString now = f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()).trimmed() : QString();
    if (now != lastServer) {
        lastServer = now;
        setActivity();
    }
}

void DiscordPresence::start(const QString& dataDir) {
    // shortcut: the application ID is fixed at build time, override with the "discordAppId" setting for testing
    QString appId = QSettings().value("discordAppId", LUMEN_DISCORD_APP_ID).toString();
    if (appId.isEmpty() || !QSettings().value("discordPresence", true).toBool())
        return;
    stop();
    // Native/AppImage Discord, then the Flatpak variants (Flatpak apps expose the socket under app/<id>/)
    QString run = qEnvironmentVariable("XDG_RUNTIME_DIR");
    QStringList dirs = {"", "app/com.discordapp.Discord/", "app/dev.vencord.Vesktop/", "snap.discord/"};
    for (auto& d : dirs) {
        for (int i = 0; i < 10; i++) {
            socket.connectToServer(run + "/" + d + "discord-ipc-" + QString::number(i));
            if (!socket.waitForConnected(200))
                continue;
            send(0, QJsonDocument(QJsonObject{{"v", 1}, {"client_id", appId}}).toJson(QJsonDocument::Compact));
            if (!socket.waitForReadyRead(1000)) { // READY reply; Discord ignores SET_ACTIVITY before it
                socket.abort();
                continue;
            }
            socket.readAll();
            startTime = QDateTime::currentSecsSinceEpoch();
            serverFile = dataDir + "/lumen_server.txt";
            QFile::remove(serverFile); // a stale file from a crashed run
            lastServer.clear();
            setActivity();
            poll.start();
            return;
        }
    }
}

void DiscordPresence::stop() {
    poll.stop();
    if (socket.state() != QLocalSocket::UnconnectedState)
        socket.abort();
}
