#include "RoadInfoController.h"
#include "GpsController.h"

#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QDateTime>
#include <QSettings>
#include <QtMath>
#include <algorithm>

namespace {
constexpr double kCell        = 0.1;     // tile grid, must match build.py
constexpr double kLimitBox    = 0.004;   // ~440 m search box for speed limit
constexpr double kLimitSnapM  = 28.0;    // max distance to "be on" a road
constexpr double kSetRadius   = 0.06;    // ~6 km working set for cams/pois
constexpr double kSetRefreshM = 1500.0;  // refetch sets after moving this far
constexpr double kLimitMoveM  = 18.0;    // re-query limit after moving this far
constexpr double kCamAlertM   = 500.0;   // camera proximity alert range
constexpr double kCamAheadDeg = 80.0;    // camera must be within this of heading
constexpr int    kOverTolKph  = 5;       // over-limit tolerance

inline double distM(double la1, double lo1, double la2, double lo2) {
    const double mlat = (la1 + la2) * 0.5 * M_PI / 180.0;
    const double dx = (lo2 - lo1) * 111320.0 * std::cos(mlat);
    const double dy = (la2 - la1) * 111320.0;
    return std::sqrt(dx * dx + dy * dy);
}

// Distance from query point Q to segment A-B, in metres (equirectangular).
double segDistM(double qla, double qlo,
                double la1, double lo1, double la2, double lo2) {
    const double c = std::cos(qla * M_PI / 180.0);
    const double ax = (lo1 - qlo) * 111320.0 * c, ay = (la1 - qla) * 111320.0;
    const double bx = (lo2 - qlo) * 111320.0 * c, by = (la2 - qla) * 111320.0;
    const double dx = bx - ax, dy = by - ay;
    const double len2 = dx * dx + dy * dy;
    double t = len2 > 0 ? -(ax * dx + ay * dy) / len2 : 0.0;
    t = std::clamp(t, 0.0, 1.0);
    const double px = ax + t * dx, py = ay + t * dy;
    return std::sqrt(px * px + py * py);
}

inline double bearingDeg(double la1, double lo1, double la2, double lo2) {
    const double dLon = (lo2 - lo1) * M_PI / 180.0;
    const double y = std::sin(dLon) * std::cos(la2 * M_PI / 180.0);
    const double x = std::cos(la1 * M_PI / 180.0) * std::sin(la2 * M_PI / 180.0)
                   - std::sin(la1 * M_PI / 180.0) * std::cos(la2 * M_PI / 180.0) * std::cos(dLon);
    double b = std::atan2(y, x) * 180.0 / M_PI;
    return std::fmod(b + 360.0, 360.0);
}
} // namespace

RoadInfoController::RoadInfoController(QObject *parent) : QObject(parent) {
    m_net = new QNetworkAccessManager(this);

    // Resolve a writable DB path; seed from the read-only bundle on first run.
    // Fixed location (not HOME-based — the service runs with HOME unset).
    const QString dir = QStringLiteral("/var/lib/hermes");
    QDir().mkpath(dir);
    const QString writable = dir + QStringLiteral("/roaddata.sqlite");
    const QString seed = QStringLiteral("/usr/share/hermes/roaddata.sqlite");
    if (!QFile::exists(writable) && QFile::exists(seed))
        QFile::copy(seed, writable);

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
                                     QStringLiteral("roadinfo"));
    m_db.setDatabaseName(writable);
    if (!m_db.open()) {
        qWarning("RoadInfo: cannot open DB %s: %s",
                 qPrintable(writable), qPrintable(m_db.lastError().text()));
        return;
    }
    ensureSchema();

    QSqlQuery q(m_db);
    q.exec(QStringLiteral("SELECT COUNT(*) FROM tile"));
    if (q.next() && q.value(0).toInt() > 0) {
        m_dataReady = true;
        emit dataReadyChanged();
    }
}

void RoadInfoController::ensureSchema() {
    QSqlQuery q(m_db);
    q.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS road_seg (lat1 REAL,lon1 REAL,lat2 REAL,lon2 REAL,"
        "minlat REAL,maxlat REAL,minlon REAL,maxlon REAL,maxspeed INTEGER)"));
    q.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_seg_bbox ON road_seg(minlat,maxlat,minlon,maxlon)"));
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS camera (lat REAL,lon REAL,maxspeed INTEGER,osm_id INTEGER UNIQUE)"));
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_cam ON camera(lat,lon)"));
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS poi (lat REAL,lon REAL,category TEXT,name TEXT,"
        "address TEXT,phone TEXT,website TEXT,src TEXT,osm_id INTEGER UNIQUE)"));
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_poi ON poi(lat,lon)"));
    // Migrate older DBs that lack the rich columns (errors ignored if present).
    for (const char *col : {"address TEXT", "phone TEXT", "website TEXT", "src TEXT"})
        q.exec(QStringLiteral("ALTER TABLE poi ADD COLUMN %1").arg(QLatin1String(col)));
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS tile (cx INTEGER,cy INTEGER,fetched_at INTEGER,PRIMARY KEY(cx,cy))"));
}

void RoadInfoController::attachGps(GpsController *gps) {
    if (!gps) return;
    connect(gps, &GpsController::positionChanged, this, [this, gps]() {
        if (!gps->valid()) return;
        onPosition(gps->coordinate().latitude(), gps->coordinate().longitude(),
                   gps->speed(), gps->direction(), gps->directionValid());
    });
}

void RoadInfoController::setPoisVisible(bool on) {
    if (on == m_poisVisible) return;
    m_poisVisible = on;
    emit poisVisibleChanged();
}

static QString favKey(double lat, double lon) {
    return QStringLiteral("%1,%2")
        .arg(lat, 0, 'f', 5).arg(lon, 0, 'f', 5);
}

bool RoadInfoController::isFavorite(double lat, double lon) const {
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    const QStringList favs = s.value(QStringLiteral("favorites")).toStringList();
    const QString key = favKey(lat, lon);
    for (const QString &f : favs)
        if (f.section('|', 0, 0) == key) return true;
    return false;
}

void RoadInfoController::toggleFavorite(double lat, double lon, const QString &name) {
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    QStringList favs = s.value(QStringLiteral("favorites")).toStringList();
    const QString key = favKey(lat, lon);
    bool removed = false;
    for (int i = 0; i < favs.size(); ++i) {
        if (favs[i].section('|', 0, 0) == key) {
            favs.removeAt(i); removed = true; break;
        }
    }
    if (!removed)
        favs.append(key + QStringLiteral("|") + name);
    s.setValue(QStringLiteral("favorites"), favs);
    s.sync();
    emit favoritesChanged();
}

void RoadInfoController::onPosition(double lat, double lon, double speedMps,
                                    double course, bool dirValid) {
    m_lastSpeedKph = speedMps * 3.6;

    if (distM(m_lastLimitLat, m_lastLimitLon, lat, lon) > kLimitMoveM) {
        m_lastLimitLat = lat; m_lastLimitLon = lon;
        refreshSpeedLimit(lat, lon);
    }
    if (distM(m_lastSetLat, m_lastSetLon, lat, lon) > kSetRefreshM) {
        m_lastSetLat = lat; m_lastSetLon = lon;
        refreshLocalSets(lat, lon);
        maybeDownloadTile(lat, lon);
    }
    recomputeNearestCamera(lat, lon, course, dirValid);

    const bool over = m_speedLimit > 0
                   && m_lastSpeedKph > m_speedLimit + kOverTolKph;
    if (over != m_overLimit) m_overLimit = over;
    emit roadChanged();
}

void RoadInfoController::refreshSpeedLimit(double lat, double lon) {
    if (!m_db.isOpen()) return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT lat1,lon1,lat2,lon2,maxspeed FROM road_seg "
        "WHERE maxlat>=:a AND minlat<=:b AND maxlon>=:c AND minlon<=:d"));
    q.bindValue(":a", lat - kLimitBox);
    q.bindValue(":b", lat + kLimitBox);
    q.bindValue(":c", lon - kLimitBox);
    q.bindValue(":d", lon + kLimitBox);
    if (!q.exec()) return;

    double best = 1e9; int bestSpeed = 0;
    while (q.next()) {
        const double d = segDistM(lat, lon,
                                  q.value(0).toDouble(), q.value(1).toDouble(),
                                  q.value(2).toDouble(), q.value(3).toDouble());
        if (d < best) { best = d; bestSpeed = q.value(4).toInt(); }
    }
    const int lim = (best <= kLimitSnapM) ? bestSpeed : 0;
    if (lim != m_speedLimit) m_speedLimit = lim;   // roadChanged emitted by caller
}

void RoadInfoController::refreshLocalSets(double lat, double lon) {
    if (!m_db.isOpen()) return;

    // Cameras
    m_camerasView.clear();
    {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral(
            "SELECT lat,lon,maxspeed FROM camera "
            "WHERE lat BETWEEN :a AND :b AND lon BETWEEN :c AND :d"));
        q.bindValue(":a", lat - kSetRadius); q.bindValue(":b", lat + kSetRadius);
        q.bindValue(":c", lon - kSetRadius); q.bindValue(":d", lon + kSetRadius);
        if (q.exec()) {
            while (q.next()) {
                QVariantMap m;
                m["lat"] = q.value(0).toDouble();
                m["lon"] = q.value(1).toDouble();
                m["maxspeed"] = q.value(2).toInt();
                m_camerasView.append(m);
            }
        }
    }
    emit camerasChanged();

    // POIs
    m_poisView.clear();
    {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral(
            "SELECT lat,lon,category,name,address,phone,website FROM poi "
            "WHERE lat BETWEEN :a AND :b AND lon BETWEEN :c AND :d"));
        q.bindValue(":a", lat - kSetRadius); q.bindValue(":b", lat + kSetRadius);
        q.bindValue(":c", lon - kSetRadius); q.bindValue(":d", lon + kSetRadius);
        if (q.exec()) {
            while (q.next()) {
                QVariantMap m;
                m["lat"]      = q.value(0).toDouble();
                m["lon"]      = q.value(1).toDouble();
                m["category"] = q.value(2).toString();
                m["name"]     = q.value(3).toString();
                m["address"]  = q.value(4).toString();
                m["phone"]    = q.value(5).toString();
                m["website"]  = q.value(6).toString();
                m_poisView.append(m);
            }
        }
    }
    emit poisChanged();
}

void RoadInfoController::recomputeNearestCamera(double lat, double lon,
                                                double course, bool dirValid) {
    double best = -1; int bestLimit = 0;
    for (const QVariant &v : std::as_const(m_camerasView)) {
        const QVariantMap m = v.toMap();
        const double cla = m.value("lat").toDouble();
        const double clo = m.value("lon").toDouble();
        const double d = distM(lat, lon, cla, clo);
        if (d > kCamAlertM * 2) continue;
        if (dirValid) {
            const double brg = bearingDeg(lat, lon, cla, clo);
            double diff = std::fmod(std::fabs(brg - course), 360.0);
            if (diff > 180.0) diff = 360.0 - diff;
            if (diff > kCamAheadDeg) continue;     // behind us
        }
        if (best < 0 || d < best) { best = d; bestLimit = m.value("maxspeed").toInt(); }
    }
    m_nearestCamDist  = best;
    m_nearestCamLimit = bestLimit;
    m_cameraAlert     = (best >= 0 && best <= kCamAlertM);
}

bool RoadInfoController::tileCovered(int cx, int cy) {
    if (!m_db.isOpen()) return true;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT 1 FROM tile WHERE cx=:x AND cy=:y"));
    q.bindValue(":x", cx); q.bindValue(":y", cy);
    return q.exec() && q.next();
}

void RoadInfoController::maybeDownloadTile(double lat, double lon) {
    const int cx = int(std::floor(lon / kCell));
    const int cy = int(std::floor(lat / kCell));
    const QPair<int,int> key(cx, cy);
    if (tileCovered(cx, cy) || m_pendingTiles.contains(key)) return;

    const double la = cy * kCell, lo = cx * kCell;
    const QString bbox = QStringLiteral("%1,%2,%3,%4")
        .arg(la).arg(lo).arg(la + kCell).arg(lo + kCell);
    const QString ql = QStringLiteral(
        "[out:json][timeout:120];("
        "way[\"maxspeed\"](%1);"
        "node[\"highway\"=\"speed_camera\"](%1);"
        "nwr[\"amenity\"~\"^(fuel|charging_station|restaurant|fast_food|cafe|bar|pub|ice_cream|food_court|hospital|clinic|doctors|pharmacy|bank|atm|bureau_de_change)$\"](%1);"
        "nwr[\"shop\"](%1);"
        "nwr[\"tourism\"~\"^(hotel|motel|guest_house)$\"](%1);"
        ");out body geom;").arg(bbox);

    QNetworkRequest req{QUrl(QStringLiteral("https://overpass-api.de/api/interpreter"))};
    req.setHeader(QNetworkRequest::ContentTypeHeader,
                  QStringLiteral("application/x-www-form-urlencoded"));
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("hermes-roaddata/1.0"));
    QUrlQuery body; body.addQueryItem(QStringLiteral("data"), ql);

    m_pendingTiles.insert(key);
    m_downloading = true; emit downloadingChanged();

    QNetworkReply *reply = m_net->post(req, body.toString(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, cx, cy]() { onDownloadFinished(reply, cx, cy); });
}

void RoadInfoController::onDownloadFinished(QNetworkReply *reply, int cx, int cy) {
    reply->deleteLater();
    const QPair<int,int> key(cx, cy);
    m_pendingTiles.remove(key);

    if (reply->error() == QNetworkReply::NoError) {
        ingestOverpass(reply->readAll());
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral(
            "INSERT OR REPLACE INTO tile(cx,cy,fetched_at) VALUES(:x,:y,:t)"));
        q.bindValue(":x", cx); q.bindValue(":y", cy);
        q.bindValue(":t", QDateTime::currentSecsSinceEpoch());
        q.exec();
        if (!m_dataReady) { m_dataReady = true; emit dataReadyChanged(); }
        // Refresh working sets so new data appears immediately.
        refreshLocalSets(m_lastSetLat < 999 ? m_lastSetLat : cy * kCell + kCell / 2,
                         m_lastSetLon < 999 ? m_lastSetLon : cx * kCell + kCell / 2);
        refreshSpeedLimit(m_lastLimitLat, m_lastLimitLon);
        emit roadChanged();
    }

    if (m_pendingTiles.isEmpty() && m_downloading) {
        m_downloading = false; emit downloadingChanged();
    }
}

void RoadInfoController::ingestOverpass(const QByteArray &json) {
    const QJsonDocument doc = QJsonDocument::fromJson(json);
    if (!doc.isObject()) return;
    const QJsonArray els = doc.object().value(QStringLiteral("elements")).toArray();

    auto parseSpeed = [](const QString &raw) -> int {
        if (raw.isEmpty()) return 0;
        QString num; bool mph = raw.contains("mph", Qt::CaseInsensitive);
        for (QChar ch : raw) { if (ch.isDigit()) num += ch; else if (!num.isEmpty()) break; }
        if (num.isEmpty()) return 0;
        int v = num.toInt();
        if (mph) v = int(std::lround(v * 1.60934));
        return (v >= 5 && v <= 140) ? v : 0;
    };

    auto category = [](const QJsonObject &tags) -> QString {
        static const QHash<QString,QString> amenity = {
            {"fuel","fuel"},{"charging_station","charging"},
            {"restaurant","food"},{"fast_food","food"},{"cafe","food"},
            {"bar","food"},{"pub","food"},{"ice_cream","food"},{"food_court","food"},
            {"hospital","hospital"},{"clinic","hospital"},{"doctors","hospital"},
            {"pharmacy","pharmacy"},
            {"bank","bank"},{"atm","bank"},{"bureau_de_change","bank"}};
        static const QHash<QString,QString> shop = {
            {"supermarket","supermarket"},{"convenience","supermarket"},
            {"bakery","food"},{"butcher","food"},{"greengrocer","food"},
            {"mall","shopping"},{"department_store","shopping"}};
        static const QHash<QString,QString> tourism = {
            {"hotel","lodging"},{"motel","lodging"},{"guest_house","lodging"}};
        const QString a = tags.value(QStringLiteral("amenity")).toString();
        if (amenity.contains(a)) return amenity.value(a);
        const QString s = tags.value(QStringLiteral("shop")).toString();
        if (!s.isEmpty()) return shop.value(s, QStringLiteral("shopping"));
        const QString t = tags.value(QStringLiteral("tourism")).toString();
        if (tourism.contains(t)) return tourism.value(t);
        return QString();
    };
    auto addrOf = [](const QJsonObject &tags) -> QString {
        QStringList parts;
        const QString st = tags.value(QStringLiteral("addr:street")).toString();
        if (!st.isEmpty()) {
            const QString hn = tags.value(QStringLiteral("addr:housenumber")).toString();
            parts << (hn.isEmpty() ? st : st + QStringLiteral(", ") + hn);
        }
        const QString sub = tags.value(QStringLiteral("addr:suburb")).toString();
        if (!sub.isEmpty()) parts << sub;
        return parts.join(QStringLiteral(", "));
    };

    m_db.transaction();
    for (const QJsonValue &ev : els) {
        const QJsonObject e = ev.toObject();
        const QString type = e.value(QStringLiteral("type")).toString();
        const QJsonObject tags = e.value(QStringLiteral("tags")).toObject();
        const qint64 id = e.value(QStringLiteral("id")).toVariant().toLongLong();

        // Roads with a speed limit → segments.
        if (type == QLatin1String("way") && tags.contains(QStringLiteral("maxspeed"))) {
            const int ms = parseSpeed(tags.value(QStringLiteral("maxspeed")).toString());
            if (ms > 0) {
                const QJsonArray geom = e.value(QStringLiteral("geometry")).toArray();
                for (int i = 0; i + 1 < geom.size(); ++i) {
                    const QJsonObject a = geom[i].toObject(), b = geom[i + 1].toObject();
                    const double la1 = a.value("lat").toDouble(), lo1 = a.value("lon").toDouble();
                    const double la2 = b.value("lat").toDouble(), lo2 = b.value("lon").toDouble();
                    QSqlQuery q(m_db);
                    q.prepare(QStringLiteral(
                        "INSERT INTO road_seg(lat1,lon1,lat2,lon2,minlat,maxlat,minlon,maxlon,maxspeed)"
                        " VALUES(?,?,?,?,?,?,?,?,?)"));
                    q.addBindValue(la1); q.addBindValue(lo1);
                    q.addBindValue(la2); q.addBindValue(lo2);
                    q.addBindValue(qMin(la1, la2)); q.addBindValue(qMax(la1, la2));
                    q.addBindValue(qMin(lo1, lo2)); q.addBindValue(qMax(lo1, lo2));
                    q.addBindValue(ms);
                    q.exec();
                }
            }
        }

        // Speed cameras (nodes).
        if (type == QLatin1String("node")
            && tags.value(QStringLiteral("highway")).toString() == QLatin1String("speed_camera")) {
            QSqlQuery q(m_db);
            q.prepare(QStringLiteral(
                "INSERT OR IGNORE INTO camera(lat,lon,maxspeed,osm_id) VALUES(?,?,?,?)"));
            q.addBindValue(e.value("lat").toDouble()); q.addBindValue(e.value("lon").toDouble());
            q.addBindValue(parseSpeed(tags.value(QStringLiteral("maxspeed")).toString()));
            q.addBindValue(id); q.exec();
            continue;
        }

        // POIs — node lat/lon or way/relation centroid.
        const QString cat = category(tags);
        if (!cat.isEmpty()) {
            double la = 0, lo = 0; bool ok = false;
            if (type == QLatin1String("node")) {
                la = e.value("lat").toDouble(); lo = e.value("lon").toDouble(); ok = true;
            } else {
                const QJsonArray geom = e.value(QStringLiteral("geometry")).toArray();
                if (!geom.isEmpty()) {
                    for (const QJsonValue &gv : geom) {
                        la += gv.toObject().value("lat").toDouble();
                        lo += gv.toObject().value("lon").toDouble();
                    }
                    la /= geom.size(); lo /= geom.size(); ok = true;
                }
            }
            if (ok) {
                const qint64 uid = type == QLatin1String("node") ? id : id + 10000000000LL;
                QSqlQuery q(m_db);
                q.prepare(QStringLiteral(
                    "INSERT OR IGNORE INTO poi(lat,lon,category,name,address,phone,website,src,osm_id)"
                    " VALUES(?,?,?,?,?,?,?,?,?)"));
                q.addBindValue(la); q.addBindValue(lo); q.addBindValue(cat);
                q.addBindValue(tags.value(QStringLiteral("name")).toString());
                q.addBindValue(addrOf(tags));
                QString phone = tags.value(QStringLiteral("phone")).toString();
                if (phone.isEmpty()) phone = tags.value(QStringLiteral("contact:phone")).toString();
                QString web = tags.value(QStringLiteral("website")).toString();
                if (web.isEmpty()) web = tags.value(QStringLiteral("contact:website")).toString();
                q.addBindValue(phone); q.addBindValue(web);
                q.addBindValue(QStringLiteral("osm")); q.addBindValue(uid);
                q.exec();
            }
        }
    }
    m_db.commit();
}
