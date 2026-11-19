#include "lumenimport.h"

#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QUuid>
#include <QtConcurrent>
#include <cstdio>
#include <cstring>
#include <sys/stat.h>
#include <zip.h>

namespace {

constexpr int kMaxEntries = 20000;
constexpr qint64 kMaxUnpacked = 2LL * 1024 * 1024 * 1024;
constexpr qint64 kMaxJson = 5 * 1024 * 1024;

QString clean(QString s) { return s.remove(QRegularExpression("[^A-Za-z0-9_-]")); }

bool validUuid(const QString &u) {
    static const QRegularExpression re("^[0-9a-fA-F-]{36}$");
    return re.match(u).hasMatch();
}

QJsonDocument readJson(const QString &path) {
    QFile f(path);
    if (f.size() > kMaxJson || !f.open(QIODevice::ReadOnly)) return {};
    return QJsonDocument::fromJson(f.readAll());
}

bool writeJson(const QString &path, const QJsonDocument &doc) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly)) return false;
    f.write(doc.toJson(QJsonDocument::Indented));
    return f.commit();
}

// Entry names from a zip are untrusted: refuse anything that could leave the target folder.
bool safeName(const QString &n) {
    if (n.isEmpty() || n.startsWith('/') || n.contains('\\') || n.contains(QChar(0))) return false;
    if (n.size() > 1 && n[1] == ':') return false;
    for (const QString &part : n.split('/'))
        if (part == "..") return false;
    return true;
}

// Extracts a zip below dest. Returns an empty string on success, else the reason.
QString extractZip(const QString &zipPath, const QString &dest) {
    int zerr = 0;
    zip_t *za = zip_open(QFile::encodeName(zipPath).constData(), ZIP_RDONLY, &zerr);
    if (!za) return "not a readable zip file";
    QString err;
    const zip_int64_t count = zip_get_num_entries(za, 0);
    if (count > kMaxEntries) err = "pack too large";
    qint64 total = 0;
    QDir().mkpath(dest);
    const QString base = QDir(dest).absolutePath();
    for (zip_int64_t i = 0; err.isEmpty() && i < count; i++) {
        zip_stat_t st;
        if (zip_stat_index(za, i, 0, &st) != 0 || !(st.valid & ZIP_STAT_NAME)) { err = "damaged zip"; break; }
        const QString name = QString::fromUtf8(st.name);
        if (name.startsWith("__MACOSX/")) continue;
        if (!safeName(name)) { err = "refused: unsafe file name in the zip (" + name.left(60) + ")"; break; }
        zip_uint8_t opsys; zip_uint32_t attr;
        if (zip_file_get_external_attributes(za, i, 0, &opsys, &attr) == 0 && opsys == ZIP_OPSYS_UNIX) {
            const mode_t m = attr >> 16;
            if ((m & S_IFMT) != 0 && !S_ISREG(m) && !S_ISDIR(m)) { err = "refused: symlink or special file in the zip"; break; }
        }
        const QString out = QDir::cleanPath(base + "/" + name);
        if (!out.startsWith(base + "/")) { err = "refused: unsafe file name in the zip"; break; }
        if (name.endsWith('/')) { QDir().mkpath(out); continue; }
        if ((st.valid & ZIP_STAT_SIZE) && (qint64)st.size > kMaxUnpacked - total) { err = "pack too large"; break; }
        QDir().mkpath(QFileInfo(out).absolutePath());
        zip_file_t *zf = zip_fopen_index(za, i, 0);
        QFile of(out);
        if (!zf || !of.open(QIODevice::WriteOnly)) { if (zf) zip_fclose(zf); err = "cannot unpack " + name.left(60); break; }
        char buf[65536];
        zip_int64_t n;
        while ((n = zip_fread(zf, buf, sizeof buf)) > 0) {
            total += n; // counted while reading, a zip header can lie about its size
            if (total > kMaxUnpacked) { err = "pack too large"; break; }
            of.write(buf, n);
        }
        if (err.isEmpty() && n < 0) err = "damaged zip";
        zip_fclose(zf);
    }
    zip_close(za);
    return err;
}

// Copies a dropped folder, skipping symlinks, with the same caps as a zip.
QString copyTree(const QString &src, const QString &dst) {
    QDir().mkpath(dst);
    qint64 total = 0;
    int files = 0;
    QDirIterator it(src, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System, QDirIterator::Subdirectories);
    const QDir sd(src);
    while (it.hasNext()) {
        it.next();
        const QFileInfo fi = it.fileInfo();
        if (fi.isSymLink()) return "refused: symlink in the folder";
        const QString rel = sd.relativeFilePath(fi.filePath());
        if (fi.isDir()) { QDir().mkpath(dst + "/" + rel); continue; }
        total += fi.size();
        if (++files > kMaxEntries || total > kMaxUnpacked) return "pack too large";
        QDir().mkpath(QFileInfo(dst + "/" + rel).absolutePath());
        if (!QFile::copy(fi.filePath(), dst + "/" + rel)) return "cannot copy " + rel.left(60);
    }
    return {};
}


struct SkinIn { QString display, path; QImage img; QString base; };
struct GeoIn { QString display, path; QJsonArray models; QString base; };

class Importer {
public:
    QString games, work;
    QString data, skinPack; // data folder, skin pack this drop installed or changed
    bool activate = false, gameRunning = false;
    QVariantList results;
    QList<SkinIn> pngs;
    QList<GeoIn> geos;
    QList<QPair<QString, QJsonArray>> activations; // uuid, version
    int seq = 0;

    void add(const QString &file, const QString &kind, bool ok, const QString &msg) {
        results.append(QVariantMap{{"file", file}, {"kind", kind}, {"ok", ok}, {"message", msg}});
    }
    QString tmp() { return work + "/t" + QString::number(seq++); }

    // A path the sandbox can open. Inside Flatpak a file from Downloads needs the host to copy it in.
    QString readable(const QString &p, QString &err) {
        if (QFileInfo(p).isReadable()) return p;
        if (!QFile::exists("/.flatpak-info")) { err = "cannot read this file"; return {}; }
        const QString dir = tmp();
        QDir().mkpath(dir);
        QProcess pr;
        pr.start("flatpak-spawn", {"--host", "cp", "-rP", "--", p, dir});
        if (!pr.waitForFinished(10 * 60 * 1000) || pr.exitCode() != 0) { err = "cannot read this file"; return {}; }
        return dir + "/" + QFileInfo(p).fileName();
    }

    void handle(const QString &display, const QString &p) {
        const QFileInfo fi(p);
        if (fi.isSymLink()) { add(display, "unknown", false, "refused: symlink"); return; }
        if (fi.isDir()) {
            const QString d = tmp();
            const QString e = copyTree(p, d);
            if (!e.isEmpty()) add(display, "pack", false, e); else installTree(display, d, 0);
            return;
        }
        QFile f(p);
        if (!f.open(QIODevice::ReadOnly)) { add(display, "unknown", false, "cannot read this file"); return; }
        const QByteArray head = f.read(8);
        f.close();
        if (head.startsWith("PK\x03\x04")) {
            const QString d = tmp();
            const QString e = extractZip(p, d);
            if (!e.isEmpty()) add(display, "pack", false, e); else installTree(display, d, 0);
        } else if (head.startsWith("\x89PNG")) {
            QImageReader r(p);
            const QSize s = r.size();
            if (fi.size() > 8 * 1024 * 1024 || s.width() <= 0 || s.width() > 512 || s.height() > 512) {
                add(display, "skin", false, "not a skin image (wrong size)"); return;
            }
            QImage img = r.read();
            if (img.isNull()) add(display, "skin", false, "not a valid PNG");
            else pngs.append({display, p, img.convertToFormat(QImage::Format_ARGB32), QFileInfo(p).completeBaseName()});
        } else if (p.endsWith(".json", Qt::CaseInsensitive)) {
            const QJsonObject o = readJson(p).object();
            if (o["minecraft:geometry"].isArray()) geos.append({display, p, o["minecraft:geometry"].toArray(), QFileInfo(p).completeBaseName()});
            else if (const QStringList ks = o.keys(); std::any_of(ks.begin(), ks.end(), [](const QString &k) { return k.startsWith("geometry."); }))
                add(display, "model", false, "re-export this model as 1.12 geometry (Blockbench: Bedrock Model)");
            else add(display, "unknown", false, "not a model file, nothing changed");
        } else {
            add(display, "unknown", false, "unknown file type, nothing changed");
        }
    }

    // Finds pack roots (folders holding manifest.json, at most 3 levels down) in an unpacked tree.
    void findRoots(const QString &dir, int depth, QStringList &out) {
        if (QFile::exists(dir + "/manifest.json")) { out << dir; return; }
        if (depth >= 3) return;
        for (const QString &s : QDir(dir).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) findRoots(dir + "/" + s, depth + 1, out);
    }

    void installTree(const QString &display, const QString &dir, int depth) {
        QStringList roots;
        findRoots(dir, 0, roots);
        if (roots.isEmpty()) {
            // .mcaddon: packs inside as .mcpack / .zip
            QStringList inner;
            QDirIterator it(dir, {"*.mcpack", "*.zip", "*.mcaddon"}, QDir::Files, QDirIterator::Subdirectories);
            while (it.hasNext()) inner << it.next();
            if (!inner.isEmpty() && depth < 2) {
                for (const QString &z : inner) {
                    const QString d = tmp();
                    const QString e = extractZip(z, d);
                    const QString name = display + " > " + QFileInfo(z).fileName();
                    if (!e.isEmpty()) add(name, "pack", false, e); else installTree(name, d, depth + 1);
                }
                return;
            }
            bool world = QFile::exists(dir + "/level.dat");
            for (const QString &s : QDir(dir).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) world |= QFile::exists(dir + "/" + s + "/level.dat");
            add(display, world ? "world" : "unknown", false, world ? "this is a world, use Import World or Pack in Settings" : "no manifest.json found, nothing changed");
            return;
        }
        for (const QString &r : roots) installPack(roots.size() > 1 ? display + " > " + QFileInfo(r).fileName() : display, r);
    }

    void installPack(const QString &display, const QString &root) {
        const QJsonObject m = readJson(root + "/manifest.json").object();
        const QJsonObject h = m["header"].toObject();
        const QString uuid = h["uuid"].toString().toLower();
        if (m.isEmpty() || !validUuid(uuid)) { add(display, "pack", false, "manifest.json is broken or has no valid uuid, nothing changed"); return; }
        QString type;
        for (const QJsonValue &mod : m["modules"].toArray()) {
            const QString t = mod.toObject()["type"].toString();
            if (t == "resources" || t == "skin_pack") type = t;
            else if (type.isEmpty()) type = t;
        }
        if (type != "resources" && type != "skin_pack") {
            add(display, "pack", false, "behaviour packs are not handled here, use Import World or Pack in Settings"); return;
        }
        const bool tex = type == "resources";
        const QString baseDir = games + (tex ? "/resource_packs" : "/skin_packs");
        QDir().mkpath(baseDir);
        QString dest;
        for (const QString &s : QDir(baseDir).entryList(QDir::Dirs | QDir::NoDotAndDotDot))
            if (readJson(baseDir + "/" + s + "/manifest.json").object()["header"].toObject()["uuid"].toString().toLower() == uuid) { dest = baseDir + "/" + s; break; }
        if (dest.isEmpty()) {
            const QString n = clean(h["name"].toString());
            dest = baseDir + "/" + (n.isEmpty() ? "pack" : n) + "_" + uuid.left(8);
            while (QFile::exists(dest)) dest += "_" + QString::number(seq++);
        }
        const QString old = tmp();
        const bool hadOld = QFile::exists(dest);
        if (hadOld && !QDir().rename(dest, old)) { add(display, "pack", false, "cannot replace the installed pack"); return; }
        if (!QDir().rename(root, dest)) {
            if (hadOld) QDir().rename(old, dest);
            add(display, "pack", false, "cannot move the pack into place");
            return;
        }
        if (hadOld) QDir(old).removeRecursively();
        QString msg = hadOld ? "Updated." : "Installed.";
        if (tex) {
            QJsonArray ver = h["version"].toArray();
            if (ver.size() != 3) ver = QJsonArray{1, 0, 0};
            if (activate && !gameRunning) { activations.append({uuid, ver}); msg += " Put on top of your active packs."; }
            else if (activate) msg += " Turn it on in Lumen > Packs, or restart the game.";
        }
        if (!tex) skinPack = dest;
        add(display, tex ? "texture pack" : "skin pack", true, msg);
    }

    // Moves the dropped packs to the top of global_resource_packs.json. Never while the game runs.
    void applyActivations() {
        if (activations.isEmpty()) return;
        const QString path = games + "/minecraftpe/global_resource_packs.json";
        QJsonArray arr;
        if (QFile::exists(path)) {
            const QJsonDocument d = readJson(path);
            if (!d.isArray()) return; // do not touch a file we cannot read
            arr = d.array();
        }
        for (const auto &a : activations) {
            for (int i = arr.size() - 1; i >= 0; i--)
                if (arr[i].toObject()["pack_id"].toString().toLower() == a.first) arr.removeAt(i);
            arr.prepend(QJsonObject{{"pack_id", a.first}, {"version", a.second}});
        }
        writeJson(path, QJsonDocument(arr));
    }

    static QString norm(QString b, bool geo) {
        b = b.toLower();
        static const QRegularExpression capeRe("([_.-]cape$|^cape[_.-])");
        if (geo) b.remove(QRegularExpression("\\.geo$"));
        else b.remove(capeRe);
        return b;
    }

    void processSkins() {
        QList<SkinIn> skins, capes;
        for (const SkinIn &s : pngs) {
            const bool named = s.base.contains("cape", Qt::CaseInsensitive);
            const bool is6432 = s.img.width() == 64 && s.img.height() == 32;
            if (is6432 && named) capes << s;
            else if (is6432) add(s.display, "skin", false, "64x32 image: add \"cape\" to the file name to use it as a cape");
            else if (named) add(s.display, "cape", false, "a cape must be 64x32");
            else skins << s;
        }
        QList<GeoIn> geoL = geos;
        QList<int> capeOf(skins.size(), -1), geoOf(skins.size(), -1);
        QSet<int> capeUsed, geoUsed;
        for (int i = 0; i < skins.size(); i++) {
            const QString b = norm(skins[i].base, false);
            for (int c = 0; c < capes.size(); c++) if (!capeUsed.contains(c) && norm(capes[c].base, false) == b) { capeOf[i] = c; capeUsed << c; break; }
            for (int g = 0; g < geoL.size(); g++) if (!geoUsed.contains(g) && norm(geoL[g].base, true) == b) { geoOf[i] = g; geoUsed << g; break; }
        }
        if (skins.size() == 1) { // one skin and one extra file: pair them even when the names differ
            if (capeOf[0] < 0 && capes.size() - capeUsed.size() == 1) { for (int c = 0; c < capes.size(); c++) if (!capeUsed.contains(c)) { capeOf[0] = c; capeUsed << c; } }
            if (geoOf[0] < 0 && geoL.size() - geoUsed.size() == 1) { for (int g = 0; g < geoL.size(); g++) if (!geoUsed.contains(g)) { geoOf[0] = g; geoUsed << g; } }
        }
        for (int c = 0; c < capes.size(); c++) if (!capeUsed.contains(c)) add(capes[c].display, "cape", false, "not attached: drop it together with its skin");
        for (int g = 0; g < geoL.size(); g++) if (!geoUsed.contains(g)) add(geoL[g].display, "model", false, "not attached: drop it together with its skin");

        for (int i = 0; i < skins.size(); i++) addSkin(skins[i], capeOf[i] >= 0 ? &capes[capeOf[i]] : nullptr, geoOf[i] >= 0 ? &geoL[geoOf[i]] : nullptr);
    }

    void addSkin(const SkinIn &s, const SkinIn *cape, const GeoIn *geo) {
        const int w = s.img.width(), h = s.img.height();
        QString geometry, warn;
        QJsonArray models;
        if (geo) {
            QString first;
            for (const QJsonValue &v : geo->models) {
                const QString id = v.toObject()["description"].toObject()["identifier"].toString();
                if (id.isEmpty()) continue;
                models << v;
                if (first.isEmpty() && id != "geometry.cape") {
                    first = id;
                    const QJsonObject d = v.toObject()["description"].toObject();
                    const int tw = d["texture_width"].toInt(), th = d["texture_height"].toInt();
                    if (tw > 0 && th > 0 && (w % tw || h % th)) warn = " Warning: the image size does not match the model's texture size.";
                }
            }
            if (first.isEmpty()) { add(s.display, "skin", false, "the model file has no usable model"); return; }
            geometry = first;
        } else {
            if (!((w == 64 && h == 64) || (w == 128 && h == 128))) { add(s.display, "skin", false, "a skin must be 64x64 or 128x128"); return; }
            const bool slim = (w == 64 ? s.img.pixelColor(54, 20) : s.img.pixelColor(108, 40)).alpha() == 0;
            geometry = slim ? "geometry.humanoid.customSlim" : "geometry.humanoid.custom";
            warn = slim ? " (slim arms)" : " (classic arms)";
        }

        const QString pack = games + "/skin_packs/Lumen_Skins";
        QDir().mkpath(pack + "/texts");
        if (!QFile::exists(pack + "/manifest.json"))
            writeJson(pack + "/manifest.json", QJsonDocument(QJsonObject{
                {"format_version", 1},
                {"header", QJsonObject{{"name", "Lumen Skins"}, {"description", "Skins added with the Lumen Launcher"},
                    {"uuid", QUuid::createUuid().toString(QUuid::WithoutBraces)}, {"version", QJsonArray{1, 0, 0}}}},
                {"modules", QJsonArray{QJsonObject{{"type", "skin_pack"}, {"uuid", QUuid::createUuid().toString(QUuid::WithoutBraces)}, {"version", QJsonArray{1, 0, 0}}}}}}));
        if (!QFile::exists(pack + "/texts/languages.json")) writeJson(pack + "/texts/languages.json", QJsonDocument(QJsonArray{"en_US"}));

        const auto sha = [](const QString &p) { QFile f(p); return f.open(QIODevice::ReadOnly) ? QCryptographicHash::hash(f.readAll(), QCryptographicHash::Sha256).toHex() : QByteArray(); };
        const QByteArray hash = sha(s.path);
        QString id = clean(s.base);
        if (id.isEmpty()) id = "skin";
        for (const QString &f : QDir(pack).entryList({"skin_*.png"}, QDir::Files))
            if (sha(pack + "/" + f) == hash) { skinPack = pack; add(s.display, "skin", true, "Already in Lumen Skins."); return; }
        if (QFile::exists(pack + "/skin_" + id + ".png")) id += "_" + QString(hash.left(6));

        QJsonObject skinsDoc = readJson(pack + "/skins.json").object();
        QJsonArray list = skinsDoc["skins"].toArray();
        QJsonObject entry{{"localization_name", id}, {"geometry", geometry}, {"texture", "skin_" + id + ".png"}, {"type", "free"}};
        if (!QFile::copy(s.path, pack + "/skin_" + id + ".png")) { add(s.display, "skin", false, "cannot write into Lumen Skins"); return; }
        skinPack = pack;
        QString extra;
        if (cape) {
            if (QFile::copy(cape->path, pack + "/cape_" + id + ".png")) { entry["cape"] = "cape_" + id + ".png"; extra += " + cape"; }
        }
        if (geo) {
            QJsonObject g = readJson(pack + "/geometry.json").object();
            QJsonArray have = g["minecraft:geometry"].toArray();
            QSet<QString> ids;
            for (const QJsonValue &v : have) ids << v.toObject()["description"].toObject()["identifier"].toString();
            for (const QJsonValue &v : models)
                if (!ids.contains(v.toObject()["description"].toObject()["identifier"].toString())) have << v;
            g["format_version"] = "1.12.0";
            g["minecraft:geometry"] = have;
            writeJson(pack + "/geometry.json", QJsonDocument(g));
            extra += " + model " + geometry;
        }
        list << entry;
        skinsDoc["skins"] = list;
        skinsDoc["serialize_name"] = "lumenskins";
        skinsDoc["localization_name"] = "lumenskins";
        writeJson(pack + "/skins.json", QJsonDocument(skinsDoc));

        QFile lang(pack + "/texts/en_US.lang");
        QByteArray txt;
        if (lang.open(QIODevice::ReadOnly)) { txt = lang.readAll(); lang.close(); }
        if (!txt.contains("skinpack.lumenskins=")) txt += "skinpack.lumenskins=Lumen Skins\n";
        else if (!txt.endsWith('\n')) txt += "\n";
        txt += "skin.lumenskins." + id.toUtf8() + "=" + id.toUtf8() + "\n";
        QSaveFile out(pack + "/texts/en_US.lang");
        if (out.open(QIODevice::WriteOnly)) { out.write(txt); out.commit(); }
        add(s.display, "skin", true, "Added to Lumen Skins" + extra + warn + ". Pick it in the dressing room under Classic skins.");
    }
};

QVariantList runImport(const QStringList &paths, const QString &dataDir, bool activate, bool gameRunning, QString *skinPack) {
    Importer im;
    im.data = dataDir;
    im.games = dataDir + "/games/com.mojang";
    im.activate = activate;
    im.gameRunning = gameRunning;
    im.work = dataDir + "/.import/" + QUuid::createUuid().toString(QUuid::WithoutBraces);
    QDir().mkpath(im.work);
    for (const QString &p : paths) {
        const QString shown = QFileInfo(p).fileName();
        QString err;
        const QString local = im.readable(p, err);
        if (local.isEmpty()) im.add(shown, "unknown", false, err); else im.handle(shown, local);
    }
    im.processSkins();
    im.applyActivations();
    QDir(im.work).removeRecursively();
    QDir(dataDir).rmdir(".import"); // only succeeds when empty
    *skinPack = QFileInfo(im.skinPack).fileName();
    return im.results;
}

} // namespace

void LumenImport::importUrls(const QList<QUrl> &urls, bool activate, bool gameRunning) {
    if (m_busy) return;
    QStringList paths;
    for (const QUrl &u : urls) {
        if (u.isLocalFile()) paths << u.toLocalFile();
        else if (u.scheme().isEmpty() && u.path().startsWith('/')) paths << u.path(); // some drag sources send a bare path
    }
    if (paths.isEmpty()) {
        // say what arrived: a link dragged out of a browser or chat app is not a file
        const QString got = urls.isEmpty() ? "nothing arrived" : "got " + urls.first().toString().left(100);
        emit finished({QVariantMap{{"file", ""}, {"kind", "unknown"}, {"ok", false}, {"message", "no local files in this drop (" + got + ")"}}});
        return;
    }
    m_busy = true;
    emit changed();
    const QString dir = m_dataDir.toLocalFile();
    (void)QtConcurrent::run([=] {
        QString pack;
        const QVariantList r = runImport(paths, dir, activate, gameRunning, &pack);
        QMetaObject::invokeMethod(this, [this, r, pack] {
            m_busy = false;
            emit changed();
            emit finished(r);
            if (!pack.isEmpty()) emit skinPackDropped(pack);
        }, Qt::QueuedConnection);
    });
}
