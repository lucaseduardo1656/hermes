#pragma once
#include <QObject>
#include <QVariantList>
#include <QSqlDatabase>
#include <QSet>
#include <QPair>

class QNetworkAccessManager;
class QNetworkReply;
class GpsController;

// Offline road-metadata provider. Opens the SQLite built by
// tools/roaddata/build.py and answers local spatial queries on every GPS
// update: current speed limit, nearby speed cameras, nearby POIs. When the
// car enters a 0.1° grid cell not yet present in the DB and the network is
// reachable, it auto-downloads that cell from Overpass and caches it — so a
// trip into uncovered territory fills in as you drive.
class RoadInfoController : public QObject {
    Q_OBJECT

    // ── Speed limit ──────────────────────────────────────────────────────
    Q_PROPERTY(int  speedLimit     READ speedLimit     NOTIFY roadChanged)
    Q_PROPERTY(bool overLimit      READ overLimit      NOTIFY roadChanged)

    // ── Cameras ──────────────────────────────────────────────────────────
    Q_PROPERTY(QVariantList cameras           READ cameras           NOTIFY camerasChanged)
    Q_PROPERTY(double       nearestCameraDist READ nearestCameraDist NOTIFY roadChanged)
    Q_PROPERTY(int          nearestCameraLimit READ nearestCameraLimit NOTIFY roadChanged)
    Q_PROPERTY(bool         cameraAlert       READ cameraAlert       NOTIFY roadChanged)

    // ── POIs ─────────────────────────────────────────────────────────────
    Q_PROPERTY(QVariantList pois        READ pois        NOTIFY poisChanged)
    Q_PROPERTY(bool         poisVisible READ poisVisible WRITE setPoisVisible NOTIFY poisVisibleChanged)

    // ── Coverage / status ────────────────────────────────────────────────
    Q_PROPERTY(bool dataReady   READ dataReady   NOTIFY dataReadyChanged)
    Q_PROPERTY(bool downloading READ downloading NOTIFY downloadingChanged)

public:
    explicit RoadInfoController(QObject *parent = nullptr);

    int  speedLimit()         const { return m_speedLimit; }
    bool overLimit()          const { return m_overLimit; }
    QVariantList cameras()    const { return m_camerasView; }
    double nearestCameraDist() const { return m_nearestCamDist; }
    int  nearestCameraLimit() const { return m_nearestCamLimit; }
    bool cameraAlert()        const { return m_cameraAlert; }
    QVariantList pois()       const { return m_poisView; }
    bool poisVisible()        const { return m_poisVisible; }
    bool dataReady()          const { return m_dataReady; }
    bool downloading()        const { return m_downloading; }

    void setPoisVisible(bool on);

    // Wire to a GpsController; connects to positionChanged internally.
    void attachGps(GpsController *gps);

    // Favorites (persisted in QSettings, keyed by rounded lat/lon).
    Q_INVOKABLE bool isFavorite(double lat, double lon) const;
    Q_INVOKABLE void toggleFavorite(double lat, double lon, const QString &name);

signals:
    void roadChanged();
    void camerasChanged();
    void poisChanged();
    void poisVisibleChanged();
    void dataReadyChanged();
    void downloadingChanged();
    void favoritesChanged();

private:
    void onPosition(double lat, double lon, double speedMps, double course, bool dirValid);
    void refreshSpeedLimit(double lat, double lon);
    void refreshLocalSets(double lat, double lon);     // cameras + pois near
    void recomputeNearestCamera(double lat, double lon, double course, bool dirValid);
    void maybeDownloadTile(double lat, double lon);
    void onDownloadFinished(QNetworkReply *reply, int cx, int cy);
    void ingestOverpass(const QByteArray &json);
    bool tileCovered(int cx, int cy);
    void ensureSchema();

    QSqlDatabase m_db;
    QNetworkAccessManager *m_net = nullptr;

    // Live road state
    int    m_speedLimit     = 0;       // 0 = unknown
    bool   m_overLimit      = false;
    double m_lastSpeedKph   = 0;

    // Camera state
    QVariantList m_camerasView;        // {lat, lon, maxspeed} within working radius
    double m_nearestCamDist = -1;
    int    m_nearestCamLimit = 0;
    bool   m_cameraAlert    = false;

    // POI state
    QVariantList m_poisView;
    bool   m_poisVisible    = false;

    // Coverage / housekeeping
    bool   m_dataReady      = false;
    bool   m_downloading    = false;
    double m_lastSetLat     = 1000;    // where local sets were last refreshed
    double m_lastSetLon     = 1000;
    double m_lastLimitLat   = 1000;
    double m_lastLimitLon   = 1000;
    QSet<QPair<int,int>> m_pendingTiles;   // tiles currently downloading/failed-recent
};
