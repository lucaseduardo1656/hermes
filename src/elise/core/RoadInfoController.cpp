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
constexpr double kSetRadius   = 0.06;    // ~6 km working set for cameras
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
        "CREATE TABLE IF NOT EXISTS poi (lat REAL,lon REAL,category TEXT,subcat TEXT,"
        "importance REAL DEFAULT 0.4,name TEXT,"
        "address TEXT,phone TEXT,website TEXT,socials TEXT,src TEXT,osm_id INTEGER UNIQUE)"));
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_poi ON poi(lat,lon)"));
    // Migrate older DBs that lack the rich columns (errors ignored if present).
    for (const char *col : {"subcat TEXT", "importance REAL", "address TEXT", "phone TEXT",
                            "website TEXT", "socials TEXT", "src TEXT"})
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
    // Recluster the last viewport immediately so markers appear/clear at once.
    if (m_vpZoom > 0)
        updateViewport(m_vpMinLat, m_vpMinLon, m_vpMaxLat, m_vpMaxLon, m_vpZoom);
    else { m_clustersView.clear(); emit clustersChanged(); }
}

namespace {
QString favKey(double lat, double lon) {
    return QStringLiteral("%1,%2").arg(lat, 0, 'f', 5).arg(lon, 0, 'f', 5);
}
// Build a {lat,lon,name,...} map from a "lat,lon|name|extra" record.
QVariantMap recordToMap(const QString &rec) {
    const QStringList parts = rec.split('|');
    const QStringList ll = parts.value(0).split(',');
    QVariantMap m;
    m["lat"]  = ll.value(0).toDouble();
    m["lon"]  = ll.value(1).toDouble();
    m["name"] = parts.value(1);
    return m;
}
} // namespace

bool RoadInfoController::isFavorite(double lat, double lon) const {
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    const QStringList favs = s.value(QStringLiteral("favorites")).toStringList();
    const QString key = favKey(lat, lon);
    for (const QString &f : favs)
        if (f.section('|', 0, 0) == key) return true;
    return false;
}

void RoadInfoController::toggleFavorite(double lat, double lon,
                                        const QString &name, const QString &category) {
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    QStringList favs = s.value(QStringLiteral("favorites")).toStringList();
    const QString key = favKey(lat, lon);
    bool removed = false;
    for (int i = 0; i < favs.size(); ++i) {
        if (favs[i].section('|', 0, 0) == key) { favs.removeAt(i); removed = true; break; }
    }
    if (!removed)
        favs.append(key + QStringLiteral("|") + name + QStringLiteral("|") + category);
    s.setValue(QStringLiteral("favorites"), favs);
    s.sync();
    emit favoritesChanged();
}

QVariantList RoadInfoController::favorites() const {
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    QVariantList out;
    const QStringList favs = s.value(QStringLiteral("favorites")).toStringList();
    for (const QString &f : favs) {
        QVariantMap m = recordToMap(f);
        m["category"] = f.section('|', 2, 2);
        out.append(m);
    }
    return out;
}

QVariantList RoadInfoController::recents() const {
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    QVariantList out;
    const QStringList recs = s.value(QStringLiteral("recents")).toStringList();
    for (const QString &r : recs) {
        QVariantMap m = recordToMap(r);
        m["address"] = r.section('|', 2, 2);
        out.append(m);
    }
    return out;
}

void RoadInfoController::addRecent(double lat, double lon,
                                   const QString &name, const QString &address) {
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    QStringList recs = s.value(QStringLiteral("recents")).toStringList();
    const QString key = favKey(lat, lon);
    for (int i = 0; i < recs.size(); ++i)            // drop existing dup
        if (recs[i].section('|', 0, 0) == key) { recs.removeAt(i); break; }
    recs.prepend(key + QStringLiteral("|") + name + QStringLiteral("|") + address);
    while (recs.size() > 12) recs.removeLast();      // cap
    s.setValue(QStringLiteral("recents"), recs);
    s.sync();
    emit recentsChanged();
}

void RoadInfoController::clearRecents() {
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    s.remove(QStringLiteral("recents"));
    s.sync();
    emit recentsChanged();
}

static QVariantMap loadPlace(const QString &which) {
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    const QString rec = s.value(QStringLiteral("place/") + which).toString();
    if (rec.isEmpty()) return QVariantMap();
    return recordToMap(rec);
}

QVariantMap RoadInfoController::home() const { return loadPlace(QStringLiteral("home")); }
QVariantMap RoadInfoController::work() const { return loadPlace(QStringLiteral("work")); }

void RoadInfoController::beginSetPlace(const QString &which) {
    if (m_pendingPlace == which) return;
    m_pendingPlace = which;
    emit pendingPlaceChanged();
}

void RoadInfoController::cancelSetPlace() {
    if (m_pendingPlace.isEmpty()) return;
    m_pendingPlace.clear();
    emit pendingPlaceChanged();
}

void RoadInfoController::savePlace(const QString &which, double lat, double lon,
                                   const QString &name) {
    if (which != QLatin1String("home") && which != QLatin1String("work")) return;
    QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
    s.setValue(QStringLiteral("place/") + which,
               favKey(lat, lon) + QStringLiteral("|") + name);
    s.sync();
    if (!m_pendingPlace.isEmpty()) { m_pendingPlace.clear(); emit pendingPlaceChanged(); }
    emit placesChanged();
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

    // Cameras near GPS — both the map markers and the proximity alert.
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
    // POIs are viewport-declustered separately (updateViewport).
}

// Importance + collision decluttering (how Google Maps picks labels): rank POIs
// in the viewport by prominence, then greedily place them — a high-rank POI gets
// a full marker; lower-rank ones that fall within a marker's label box are
// demoted to a small dot, or dropped if even that overlaps. Zooming in grows the
// metres-per-pixel budget so more POIs clear the collision test and promote from
// dot → full. Camera markers are always loaded for the viewport (safety).
void RoadInfoController::updateViewport(double minLat, double minLon,
                                        double maxLat, double maxLon, double zoom) {
    m_vpMinLat = minLat; m_vpMinLon = minLon;
    m_vpMaxLat = maxLat; m_vpMaxLon = maxLon; m_vpZoom = zoom;
    if (!m_db.isOpen()) { emit clustersChanged(); return; }

    const double midLat = (minLat + maxLat) * 0.5;
    const double mpp = 156543.03392 * std::cos(midLat * M_PI / 180.0)
                       / std::pow(2.0, zoom);            // metres per pixel
    const double fullM = 66.0 * mpp;                     // label box ~66px
    const double dotM  = 16.0 * mpp;                     // dots only need elbow room

    // POIs only — cameras stay GPS-radius (refreshLocalSets).
    m_clustersView.clear();
    if (!m_poisVisible) { emit clustersChanged(); return; }

    auto catWeight = [](const QString &c) -> double {
        if (c == QLatin1String("hospital") || c == QLatin1String("pharmacy")) return 1.40;
        if (c == QLatin1String("fuel")     || c == QLatin1String("charging")) return 1.30;
        if (c == QLatin1String("attraction")) return 1.25;
        if (c == QLatin1String("bank"))        return 1.15;
        if (c == QLatin1String("supermarket")) return 1.10;
        if (c == QLatin1String("park"))        return 1.10;
        if (c == QLatin1String("food"))        return 1.00;
        if (c == QLatin1String("worship") || c == QLatin1String("education")) return 1.00;
        if (c == QLatin1String("lodging"))     return 0.95;
        return 0.82;                                       // shopping / place / other
    };

    struct P { double score, lat, lon; QVariantMap m; };
    QVector<P> all;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT lat,lon,category,name,address,phone,website,subcat,socials,importance FROM poi "
        "WHERE lat BETWEEN :a AND :b AND lon BETWEEN :c AND :d LIMIT 8000"));
    q.bindValue(":a", minLat); q.bindValue(":b", maxLat);
    q.bindValue(":c", minLon); q.bindValue(":d", maxLon);
    if (q.exec()) {
        while (q.next()) {
            const double pla = q.value(0).toDouble(), plo = q.value(1).toDouble();
            const QString cat = q.value(2).toString();
            const double imp = q.value(9).isNull() ? 0.4 : q.value(9).toDouble();
            // rank ≈ 0.7..2.0; derive a per-POI minzoom like a vector tile so a
            // far-out view never even considers a corner bakery. Floor ~13.5 to
            // match the basemap's own POI labels (they only show from ~z14), so
            // ours appear/vanish at the same scale; state/region view = none.
            const double rank = catWeight(cat) * (0.4 + imp);
            const double minZoom = qBound(13.5, 17.0 - rank * 1.6, 17.0);
            if (zoom + 0.4 < minZoom) continue;
            QVariantMap m;
            m["lat"] = pla; m["lon"] = plo; m["category"] = cat;
            m["name"] = q.value(3).toString(); m["address"] = q.value(4).toString();
            m["phone"] = q.value(5).toString(); m["website"] = q.value(6).toString();
            m["subcat"] = q.value(7).toString(); m["socials"] = q.value(8).toString();
            all.push_back({ rank, pla, plo, m });
        }
    }
    std::sort(all.begin(), all.end(),
              [](const P &a, const P &b){ return a.score > b.score; });

    struct Pt { double lat, lon; };
    QVector<Pt> fullPts, allPts;
    fullPts.reserve(256); allPts.reserve(512);
    auto clearOf = [](const QVector<Pt> &pts, double la, double lo, double minM) {
        for (const Pt &p : pts) if (distM(la, lo, p.lat, p.lon) < minM) return false;
        return true;
    };

    for (const P &p : std::as_const(all)) {
        if (m_clustersView.size() >= 280) break;          // hard render cap
        QVariantMap m = p.m;
        if (clearOf(fullPts, p.lat, p.lon, fullM)) {
            m["type"] = QStringLiteral("point");
            fullPts.push_back({ p.lat, p.lon }); allPts.push_back({ p.lat, p.lon });
            m_clustersView.append(m);
        } else if (clearOf(allPts, p.lat, p.lon, dotM)) {
            m["type"] = QStringLiteral("dot");
            allPts.push_back({ p.lat, p.lon });
            m_clustersView.append(m);
        }
    }
    emit clustersChanged();
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
        if (m_vpZoom > 0)
            updateViewport(m_vpMinLat, m_vpMinLon, m_vpMaxLat, m_vpMaxLon, m_vpZoom);
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
            {"bank","bank"},{"atm","bank"},{"bureau_de_change","bank"},
            {"place_of_worship","worship"},
            {"school","education"},{"university","education"},{"college","education"},
            {"kindergarten","education"},{"library","education"}};
        static const QHash<QString,QString> shop = {
            {"supermarket","supermarket"},{"convenience","supermarket"},
            {"bakery","food"},{"butcher","food"},{"greengrocer","food"},
            {"mall","shopping"},{"department_store","shopping"},
            {"hairdresser","beauty"},{"beauty","beauty"},{"cosmetics","beauty"},
            {"optician","beauty"},
            {"car","automotive"},{"car_repair","automotive"},{"car_parts","automotive"},
            {"tyres","automotive"},{"motorcycle","automotive"}};
        static const QHash<QString,QString> tourism = {
            {"hotel","lodging"},{"motel","lodging"},{"guest_house","lodging"},
            {"museum","attraction"},{"attraction","attraction"},{"viewpoint","attraction"},
            {"gallery","attraction"},{"zoo","attraction"},{"theme_park","attraction"}};
        static const QHash<QString,QString> leisure = {
            {"park","park"},{"garden","park"},{"playground","park"},
            {"nature_reserve","park"},{"stadium","attraction"},
            {"fitness_centre","gym"},{"sports_centre","gym"}};
        const QString a = tags.value(QStringLiteral("amenity")).toString();
        if (amenity.contains(a)) return amenity.value(a);
        const QString s = tags.value(QStringLiteral("shop")).toString();
        if (!s.isEmpty()) return shop.value(s, QStringLiteral("shopping"));
        const QString t = tags.value(QStringLiteral("tourism")).toString();
        if (tourism.contains(t)) return tourism.value(t);
        const QString l = tags.value(QStringLiteral("leisure")).toString();
        if (leisure.contains(l)) return leisure.value(l);
        // Anything else named with a useful tag → generic place.
        if (!a.isEmpty() || !tags.value(QStringLiteral("tourism")).toString().isEmpty()
            || !l.isEmpty())
            return QStringLiteral("place");
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
                // Fine category for the label: amenity / shop / tourism raw value.
                QString sub = tags.value(QStringLiteral("amenity")).toString();
                if (sub.isEmpty()) sub = tags.value(QStringLiteral("shop")).toString();
                if (sub.isEmpty()) sub = tags.value(QStringLiteral("tourism")).toString();
                QSqlQuery q(m_db);
                q.prepare(QStringLiteral(
                    "INSERT OR IGNORE INTO poi(lat,lon,category,subcat,name,address,phone,website,src,osm_id)"
                    " VALUES(?,?,?,?,?,?,?,?,?,?)"));
                q.addBindValue(la); q.addBindValue(lo); q.addBindValue(cat);
                q.addBindValue(sub);
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
