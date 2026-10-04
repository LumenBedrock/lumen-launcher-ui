#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QStringList>
#include <QMap>

// Reads and edits the Lumen client mod's lumen.conf (key=value lines) so the
// launcher can toggle modules. Only touches the lines it changes; every other
// line (including ones it doesn't know) is preserved as is.
class LumenConfig : public QObject {
    Q_OBJECT
    Q_PROPERTY(QUrl dataDir READ dataDir WRITE setDataDir NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)

public:
    explicit LumenConfig(QObject *parent = nullptr) : QObject(parent) {}

    QUrl dataDir() const { return m_dataDir; }
    void setDataDir(const QUrl &dir);
    bool available() const { return m_available; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE bool getBool(const QString &key, bool def) const;
    Q_INVOKABLE void setBool(const QString &key, bool value);

signals:
    void changed();

private:
    QString path() const;
    bool write();

    QUrl m_dataDir;
    bool m_available = false;
    QMap<QString, QString> m_values;
    QStringList m_lines; // original file lines, order preserved
};
