#include "lumenconfig.h"

#include <QFile>
#include <QSaveFile>
#include <QTextStream>

QString LumenConfig::path() const {
    return m_dataDir.toLocalFile() + "/lumen.conf";
}

void LumenConfig::setDataDir(const QUrl &dir) {
    if (m_dataDir == dir)
        return;
    m_dataDir = dir;
    reload();
}

void LumenConfig::reload() {
    m_values.clear();
    m_lines.clear();
    m_available = false;
    QFile f(path());
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&f);
        while (!in.atEnd()) {
            QString line = in.readLine();
            m_lines.append(line);
            int eq = line.indexOf('=');
            if (eq > 0)
                m_values[line.left(eq).trimmed()] = line.mid(eq + 1).trimmed();
        }
        m_available = true;
    }
    emit changed();
}

bool LumenConfig::getBool(const QString &key, bool def) const {
    auto it = m_values.constFind(key);
    if (it == m_values.constEnd())
        return def;
    return it.value() != "0" && it.value().compare("false", Qt::CaseInsensitive) != 0;
}

void LumenConfig::setBool(const QString &key, bool value) {
    QString v = value ? "1" : "0";
    m_values[key] = v;
    bool found = false;
    for (QString &line : m_lines) {
        int eq = line.indexOf('=');
        if (eq > 0 && line.left(eq).trimmed() == key) {
            line = key + "=" + v;
            found = true;
            break;
        }
    }
    if (!found)
        m_lines.append(key + "=" + v);
    write();
    emit changed();
}

bool LumenConfig::write() {
    QSaveFile f(path());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    QTextStream out(&f);
    for (const QString &line : m_lines)
        out << line << "\n";
    out.flush();
    m_available = true;
    return f.commit();
}
