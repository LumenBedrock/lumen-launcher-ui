#ifndef DISCORDPRESENCE_H
#define DISCORDPRESENCE_H

#include <QLocalSocket>
#include <QObject>
#include <QTimer>

// Lumen: Discord Rich Presence over the local IPC socket. Discord clears the activity when we disconnect.
class DiscordPresence : public QObject {
    Q_OBJECT
    QLocalSocket socket;

    QTimer poll;
    QString serverFile, lastServer;
    qint64 startTime = 0;

    bool send(int opcode, const QByteArray& json);
    void setActivity();
    void checkServer();

public:
    explicit DiscordPresence(QObject* parent = nullptr);
    // dataDir: the game's data folder, where the client publishes lumen_server.txt
    void start(const QString& dataDir);
    void stop();
};

#endif // DISCORDPRESENCE_H
