#include "discordpresence.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
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

void DiscordPresence::start() {
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
            QJsonObject activity{{"details", "Playing Lumen"}, {"timestamps", QJsonObject{{"start", QDateTime::currentSecsSinceEpoch()}}}};
            QJsonObject msg{{"cmd", "SET_ACTIVITY"}, {"nonce", QString::number(QDateTime::currentMSecsSinceEpoch())},
                            {"args", QJsonObject{{"pid", (qint64)QCoreApplication::applicationPid()}, {"activity", activity}}}};
            send(1, QJsonDocument(msg).toJson(QJsonDocument::Compact));
            return;
        }
    }
}

void DiscordPresence::stop() {
    if (socket.state() != QLocalSocket::UnconnectedState)
        socket.abort();
}
