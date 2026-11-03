#ifndef DISCORDPRESENCE_H
#define DISCORDPRESENCE_H

#include <QLocalSocket>
#include <QObject>

// Lumen: Discord Rich Presence over the local IPC socket. Discord clears the activity when we disconnect.
class DiscordPresence : public QObject {
    Q_OBJECT
    QLocalSocket socket;

    bool send(int opcode, const QByteArray& json);

public:
    explicit DiscordPresence(QObject* parent = nullptr) : QObject(parent) {}
    void start();
    void stop();
};

#endif // DISCORDPRESENCE_H
