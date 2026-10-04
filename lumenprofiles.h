#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantList>

// Reads and edits lumen_profiles.txt, the per-server profile file the Lumen client
// uses in game. Same format as the game writes ([profile NAME] / hosts / module.X = on|off
// ...), and every line the launcher doesn't edit (texture packs, per-module values,
// the [baseline] block) is kept untouched.
class LumenProfiles : public QObject {
    Q_OBJECT
    Q_PROPERTY(QUrl dataDir READ dataDir WRITE setDataDir NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY changed)
    Q_PROPERTY(QStringList knownModules READ knownModules NOTIFY changed)
    Q_PROPERTY(QVariantList availablePacks READ availablePacks NOTIFY changed)
    Q_PROPERTY(QVariantList moduleCatalog READ moduleCatalog NOTIFY changed) // from lumen_modules.json, written by the client at startup

public:
    explicit LumenProfiles(QObject *parent = nullptr) : QObject(parent) {}

    QUrl dataDir() const { return m_dataDir; }
    void setDataDir(const QUrl &dir);
    bool available() const { return m_available; }
    QVariantList profiles() const;
    QStringList knownModules() const;
    QVariantList moduleCatalog() const { return m_catalog; }
    QVariantList availablePacks() const; // [{name, folder}] from resource_packs/*/manifest.json

    Q_INVOKABLE void reload();
    Q_INVOKABLE bool addProfile(const QString &name, const QString &hosts);
    Q_INVOKABLE void removeProfile(const QString &name);
    Q_INVOKABLE void setHosts(const QString &name, const QString &hosts);
    Q_INVOKABLE void setModule(const QString &name, const QString &module, bool on);
    Q_INVOKABLE void clearModule(const QString &name, const QString &module);
    Q_INVOKABLE void setPacksEnabled(const QString &name, bool on); // "Change texture packs here"
    Q_INVOKABLE void setPacks(const QString &name, const QStringList &packs);
    Q_INVOKABLE QStringList currentPackNames() const; // the game's active stack right now
    Q_INVOKABLE void setValue(const QString &name, const QString &key, double value); // per-module value (set.X)
    Q_INVOKABLE void clearValue(const QString &name, const QString &key);

signals:
    void changed();

private:
    struct Range { int begin = -1, end = -1; }; // [begin, end) lines of a section, header included
    QString path() const;
    Range findProfile(const QString &name) const;
    void setKey(const QString &name, const QString &key, const QString &value);
    void removeKey(const QString &name, const QString &key);
    bool write();

    QUrl m_dataDir;
    bool m_available = false;
    QStringList m_lines;
    QVariantList m_catalog;
};
