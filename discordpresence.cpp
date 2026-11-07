#include "discordpresence.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
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
    // lastServer = the client's status file: host, "hub"/"game"/"", Hive game code. Only friendly names leave the machine.
    static const QMap<QString, QString> games = {
        {"bed", "BedWars"}, {"wars", "TreasureWars"}, {"sky", "SkyWars"}, {"dr", "DeathRun"}, {"murder", "Murder Mystery"},
        {"sg", "Survival Games"}, {"ctf", "Capture the Flag"}, {"drop", "Block Drop"}, {"ground", "Ground Wars"},
        {"build", "Just Build"}, {"party", "Block Party"}, {"bridge", "The Bridge"}, {"grav", "Gravity"}, {"hide", "Hide and Seek"}};
    const QStringList lines = lastServer.split('\n');
    const QString host = lines.value(0).trimmed().toLower(), kind = lines.value(1).trimmed(), game = lines.value(2).trimmed();
    QString server, image = "lumen", state;
    if (host.contains("hive")) {
        server = "Hive Network"; image = "hive";
        if (kind == "hub") state = "In the Hub";
        else if (kind == "game") state = game.isEmpty() ? "Playing a game" : "Playing " + games.value(game, game);
    } else if (host.contains("swim")) {
        server = "Swim"; image = "swim";
    } else if (!host.isEmpty()) {
        server = "Multiplayer";
    }
    QJsonObject activity{{"timestamps", QJsonObject{{"start", startTime}}},
                         {"assets", QJsonObject{{"large_image", image}, {"large_text", "Lumen"}, {"small_image", "minecraft"}, {"small_text", "Minecraft Bedrock"}}},
                         {"buttons", QJsonArray{QJsonObject{{"label", "Website"}, {"url", "https://lumenclient.net"}}}}};
    if (!server.isEmpty()) activity["details"] = server;
    if (!state.isEmpty()) activity["state"] = state;
    QJsonObject msg{{"cmd", "SET_ACTIVITY"}, {"nonce", QString::number(QDateTime::currentMSecsSinceEpoch())},
                    {"args", QJsonObject{{"pid", (qint64)QCoreApplication::applicationPid()}, {"activity", activity}}}};
    send(1, QJsonDocument(msg).toJson(QJsonDocument::Compact));
}

void DiscordPresence::checkServer() {
    if (socket.state() != QLocalSocket::ConnectedState) {
        // Discord not running yet, or closed/restarted: look again every 30 s (6 ticks of 5 s)
        if (++idleTicks >= 6) {
            idleTicks = 0;
            connectOnce();
        }
        return;
    }
    QFile f(serverFile);
    QString now = f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
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
    serverFile = dataDir + "/lumen_server.txt";
    startTime = QDateTime::currentSecsSinceEpoch();
    idleTicks = 0;
    poll.start(); // keeps retrying while Discord is not there (checkServer)
    connectOnce();
}

bool DiscordPresence::connectOnce() {
    QString appId = QSettings().value("discordAppId", LUMEN_DISCORD_APP_ID).toString();
    // Native/AppImage Discord, then the Flatpak and Snap variants (their sockets live under app/<id>/ or snap.<name>/)
    QString run = qEnvironmentVariable("XDG_RUNTIME_DIR");
    QStringList dirs = {"", "app/com.discordapp.Discord/", "app/com.discordapp.DiscordCanary/", "app/com.discordapp.DiscordPTB/",
                        "app/dev.vencord.Vesktop/", "snap.discord/"};
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
            QFile::remove(serverFile); // a stale file from a crashed run
            lastServer.clear();
            setActivity();
            return true;
        }
    }
    return false;
}

void DiscordPresence::stop() {
    poll.stop();
    if (socket.state() != QLocalSocket::UnconnectedState)
        socket.abort();
}
