#include "lumenprofiles.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QMap>
#include <QSaveFile>
#include <QTextStream>

QString LumenProfiles::path() const {
    return m_dataDir.toLocalFile() + "/lumen_profiles.txt";
}

void LumenProfiles::setDataDir(const QUrl &dir) {
    if (m_dataDir == dir)
        return;
    m_dataDir = dir;
    reload();
}

void LumenProfiles::reload() {
    m_lines.clear();
    m_available = false;
    QFile f(path());
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&f);
        while (!in.atEnd())
            m_lines.append(in.readLine());
        m_available = true;
    }
    m_catalog.clear();
    QFile cf(m_dataDir.toLocalFile() + "/lumen_modules.json");
    if (cf.open(QIODevice::ReadOnly))
        m_catalog = QJsonDocument::fromJson(cf.readAll()).object().value("modules").toArray().toVariantList();
    emit changed();
}

LumenProfiles::Range LumenProfiles::findProfile(const QString &name) const {
    Range r;
    const QString header = "[profile " + name + "]";
    for (int i = 0; i < m_lines.size(); i++) {
        if (r.begin < 0) {
            if (m_lines[i].trimmed() == header)
                r.begin = i;
        } else if (m_lines[i].trimmed().startsWith('[')) {
            r.end = i;
            break;
        }
    }
    if (r.begin >= 0 && r.end < 0)
        r.end = m_lines.size();
    return r;
}

QVariantList LumenProfiles::profiles() const {
    QVariantList out;
    QVariantMap cur;
    QVariantList mods, vals;
    bool inProfile = false;
    auto flush = [&]() {
        if (inProfile) {
            cur["modules"] = mods;
            cur["values"] = vals;
            out.append(cur);
        }
        cur.clear();
        mods.clear();
        vals.clear();
        inProfile = false;
    };
    for (const QString &raw : m_lines) {
        QString s = raw.trimmed();
        if (s.startsWith('[')) {
            flush();
            if (s.startsWith("[profile ") && s.endsWith(']')) {
                inProfile = true;
                cur["name"] = s.mid(9, s.size() - 10);
                cur["hosts"] = QString();
                cur["packs"] = QString();
                cur["packList"] = QStringList();
                cur["setPacks"] = false;
            }
            continue;
        }
        if (!inProfile)
            continue;
        int eq = s.indexOf('=');
        if (eq < 0)
            continue;
        QString k = s.left(eq).trimmed(), v = s.mid(eq + 1).trimmed();
        if (k == "hosts") cur["hosts"] = v;
        else if (k == "packs") {
            cur["packs"] = v;
            QStringList list;
            for (const QString &p : v.split('|'))
                if (!p.trimmed().isEmpty())
                    list << p.trimmed();
            cur["packList"] = list;
        }
        else if (k == "pack_stack") cur["setPacks"] = (v == "1");
        else if (k.startsWith("set.")) {
            QString full = k.mid(4);
            int bar = full.indexOf('|');
            QVariantMap m;
            m["key"] = full;
            m["module"] = bar > 0 ? full.left(bar) : QString();
            m["label"] = bar > 0 ? full.mid(bar + 1) : full;
            m["value"] = v.toDouble();
            vals.append(m);
        } else if (k.startsWith("module.")) {
            QVariantMap m;
            m["name"] = k.mid(7);
            m["on"] = (v == "on");
            mods.append(m);
        }
    }
    flush();
    return out;
}

QStringList LumenProfiles::knownModules() const {
    // The [baseline] block lists every module the client can switch per server.
    QStringList out;
    bool inBase = false;
    for (const QString &raw : m_lines) {
        QString s = raw.trimmed();
        if (s.startsWith('[')) {
            inBase = (s == "[baseline]");
            continue;
        }
        if (inBase && s.startsWith("mod.")) {
            int eq = s.indexOf('=');
            if (eq > 0)
                out.append(s.mid(4, eq - 4).trimmed());
        }
    }
    out.sort();
    return out;
}

bool LumenProfiles::addProfile(const QString &nameIn, const QString &hostsIn) {
    QString name = nameIn.trimmed(), hosts = hostsIn.trimmed();
    if (name.isEmpty() || hosts.isEmpty() || name.contains(']') || name.contains('\n') || hosts.contains('\n'))
        return false;
    if (findProfile(name).begin >= 0)
        return false;
    // new profiles go before a trailing [baseline] block, otherwise at the end
    int at = m_lines.size();
    for (int i = 0; i < m_lines.size(); i++)
        if (m_lines[i].trimmed() == "[baseline]") { at = i; break; }
    QStringList block = {"[profile " + name + "]", "hosts = " + hosts, ""};
    for (int i = 0; i < block.size(); i++)
        m_lines.insert(at + i, block[i]);
    bool ok = write();
    emit changed();
    return ok;
}

void LumenProfiles::removeProfile(const QString &name) {
    Range r = findProfile(name);
    if (r.begin < 0)
        return;
    for (int i = r.end - 1; i >= r.begin; i--)
        m_lines.removeAt(i);
    write();
    emit changed();
}

void LumenProfiles::setKey(const QString &name, const QString &key, const QString &value) {
    Range r = findProfile(name);
    if (r.begin < 0)
        return;
    for (int i = r.begin + 1; i < r.end; i++) {
        int eq = m_lines[i].indexOf('=');
        if (eq > 0 && m_lines[i].left(eq).trimmed() == key) {
            m_lines[i] = key + " = " + value;
            write();
            emit changed();
            return;
        }
    }
    // insert after the last non-blank line of the section
    int at = r.end;
    while (at > r.begin + 1 && m_lines[at - 1].trimmed().isEmpty())
        at--;
    m_lines.insert(at, key + " = " + value);
    write();
    emit changed();
}

void LumenProfiles::removeKey(const QString &name, const QString &key) {
    Range r = findProfile(name);
    if (r.begin < 0)
        return;
    for (int i = r.begin + 1; i < r.end; i++) {
        int eq = m_lines[i].indexOf('=');
        if (eq > 0 && m_lines[i].left(eq).trimmed() == key) {
            m_lines.removeAt(i);
            write();
            emit changed();
            return;
        }
    }
}

void LumenProfiles::setHosts(const QString &name, const QString &hosts) {
    QString h = hosts.trimmed();
    if (!h.isEmpty() && !h.contains('\n'))
        setKey(name, "hosts", h);
}

void LumenProfiles::setModule(const QString &name, const QString &module, bool on) {
    setKey(name, "module." + module, on ? "on" : "off");
}

void LumenProfiles::clearModule(const QString &name, const QString &module) {
    removeKey(name, "module." + module);
}

bool LumenProfiles::write() {
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

// ---- texture packs ----

static QString stripFormatting(QString s) {
    static const QRegularExpression re(QString::fromUtf8("\u00a7."));
    s.remove(re);
    return s.trimmed();
}

namespace {
struct PackInfo { QString name, folder, uuid; };

bool readManifest(const QString &dir, const QString &rel, PackInfo &out) {
    QFile f(dir + "/" + rel + "/manifest.json");
    if (!f.open(QIODevice::ReadOnly))
        return false;
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject())
        return false;
    QJsonObject header = doc.object().value("header").toObject();
    QString name = stripFormatting(header.value("name").toString());
    if (name.isEmpty() || name.startsWith("pack."))
        name = rel;
    out = {name, rel, header.value("uuid").toString()};
    return true;
}

QList<PackInfo> scanPacks(const QString &dataDir) {
    QString dir = dataDir + "/games/com.mojang/resource_packs";
    QList<PackInfo> found;
    for (const QString &folder : QDir(dir).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        PackInfo p;
        if (readManifest(dir, folder, p)) {
            found.append(p);
            continue;
        }
        for (const QString &inner : QDir(dir + "/" + folder).entryList(QDir::Dirs | QDir::NoDotAndDotDot))
            if (readManifest(dir, folder + "/" + inner, p))
                found.append(p);
    }
    std::sort(found.begin(), found.end(), [](const PackInfo &a, const PackInfo &b) { return a.name < b.name; });
    return found;
}
} // namespace

QVariantList LumenProfiles::availablePacks() const {
    QVariantList out;
    QStringList seen;
    for (const PackInfo &p : scanPacks(m_dataDir.toLocalFile())) {
        if (seen.contains(p.name))
            continue; // duplicate folders with the same pack name: the game matches by name
        seen << p.name;
        QVariantMap m;
        m["name"] = p.name;
        m["folder"] = p.folder;
        out.append(m);
    }
    return out;
}

QStringList LumenProfiles::currentPackNames() const {
    QString root = m_dataDir.toLocalFile();
    QFile f(root + "/games/com.mojang/minecraftpe/global_resource_packs.json");
    QStringList names;
    if (!f.open(QIODevice::ReadOnly))
        return names;
    QJsonArray arr = QJsonDocument::fromJson(f.readAll()).array();
    QList<PackInfo> all = scanPacks(root);
    for (const QJsonValue &v : arr) {
        QString id = v.toObject().value("pack_id").toString();
        for (const PackInfo &p : all)
            if (p.uuid.compare(id, Qt::CaseInsensitive) == 0) {
                names << p.name;
                break;
            }
    }
    return names;
}

void LumenProfiles::setPacks(const QString &name, const QStringList &packs) {
    setKey(name, "packs", packs.join(" | "));
}

void LumenProfiles::setPacksEnabled(const QString &name, bool on) {
    if (on) {
        setKey(name, "pack_stack", "1");
        Range r = findProfile(name);
        bool hasPacks = false;
        for (int i = r.begin + 1; i < r.end; i++)
            if (m_lines[i].left(m_lines[i].indexOf('=')).trimmed() == "packs")
                hasPacks = true;
        if (!hasPacks)
            setPacks(name, currentPackNames()); // start from what's active now, like "Copy current stack" in game
    } else {
        removeKey(name, "pack_stack");
        removeKey(name, "packs");
    }
}

void LumenProfiles::setValue(const QString &name, const QString &key, double value) {
    setKey(name, "set." + key, QString::number(value, 'f', 6));
}

void LumenProfiles::clearValue(const QString &name, const QString &key) {
    removeKey(name, "set." + key);
}
