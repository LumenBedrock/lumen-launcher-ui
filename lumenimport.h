#pragma once

#include <QList>
#include <QObject>
#include <QUrl>
#include <QVariantList>

// Installs dropped texture packs, skin packs, skins, capes and custom models into the game data
// folder (games/com.mojang). Packs come from strangers, so zips are checked entry by entry (no
// "..", no absolute names, no symlinks, size caps) and extracted into a temp folder first.
class LumenImport : public QObject {
    Q_OBJECT
    Q_PROPERTY(QUrl dataDir READ dataDir WRITE setDataDir NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)

public:
    explicit LumenImport(QObject *parent = nullptr) : QObject(parent) {}

    QUrl dataDir() const { return m_dataDir; }
    void setDataDir(const QUrl &dir) { if (m_dataDir != dir) { m_dataDir = dir; emit changed(); } }
    bool busy() const { return m_busy; }

    // activate: put dropped texture packs on top of the active stack (only done when the game is not running)
    Q_INVOKABLE void importUrls(const QList<QUrl> &urls, bool activate, bool gameRunning);

signals:
    void changed();
    void finished(QVariantList results); // [{file, kind, ok, message}]
    void skinPackDropped(QString pack);  // a drop installed or changed this skin pack folder (sent after finished)

private:
    QUrl m_dataDir;
    bool m_busy = false;
};
