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
    // Viewport-clustered markers (Supercluster-style grid by zoom). Each entry
    // is either {type:"point", ...poi} or {type:"cluster", lat, lon, count}.
    Q_PROPERTY(QVariantList clusters    READ clusters    NOTIFY clustersChanged)
    Q_PROPERTY(bool         poisVisible READ poisVisible WRITE setPoisVisible NOTIFY poisVisibleChanged)

    // ── Coverage / status ────────────────────────────────────────────────
    Q_PROPERTY(bool dataReady   READ dataReady   NOTIFY dataReadyChanged)
    Q_PROPERTY(bool downloading READ downloading NOTIFY downloadingChanged)

    // ── Saved places (search shortcuts) ──────────────────────────────────
    Q_PROPERTY(QVariantList favorites READ favorites NOTIFY favoritesChanged)
    Q_PROPERTY(QVariantList recents   READ recents   NOTIFY recentsChanged)
    Q_PROPERTY(QVariantMap  home      READ home      NOTIFY placesChanged)
    Q_PROPERTY(QVariantMap  work      READ work      NOTIFY placesChanged)
    // While non-empty ("home"/"work") the next picked place is saved to that
    // slot instead of routed to.
    Q_PROPERTY(QString pendingPlace READ pendingPlace NOTIFY pendingPlaceChanged)

public:
    explicit RoadInfoController(QObject *parent = nullptr);

    int  speedLimit()         const { return m_speedLimit; }
    bool overLimit()          const { return m_overLimit; }
    QVariantList cameras()    const { return m_camerasView; }
    double nearestCameraDist() const { return m_nearestCamDist; }
    int  nearestCameraLimit() const { return m_nearestCamLimit; }
    bool cameraAlert()        const { return m_cameraAlert; }
    QVariantList clusters()   const { return m_clustersView; }
    bool poisVisible()        const { return m_poisVisible; }

    // Recluster the POIs inside the current map viewport for the given zoom.
    // Called (debounced) by CarMap whenever the map pans/zooms.
    Q_INVOKABLE void updateViewport(double minLat, double minLon,
                                    double maxLat, double maxLon, double zoom);
    bool dataReady()          const { return m_dataReady; }
    bool downloading()        const { return m_downloading; }

    void setPoisVisible(bool on);

    // Wire to a GpsController; connects to positionChanged internally.
    void attachGps(GpsController *gps);

    QVariantList favorites()  const;
    QVariantList recents()    const;
    QVariantMap  home()       const;
    QVariantMap  work()       const;
    QString      pendingPlace() const { return m_pendingPlace; }

    // Favorites (persisted in QSettings, keyed by rounded lat/lon).
    Q_INVOKABLE bool isFavorite(double lat, double lon) const;
    Q_INVOKABLE void toggleFavorite(double lat, double lon,
                                    const QString &name, const QString &category = QString());

    // Recents — most-recent-first, capped. Pushed on every navigation.
    Q_INVOKABLE void addRecent(double lat, double lon,
                               const QString &name, const QString &address);
    Q_INVOKABLE void clearRecents();

    // Home / Work slots. beginSetPlace puts the UI in "pick" mode; savePlace
    // commits the chosen coordinate; the QML reads pendingPlace to decide
    // whether a tap saves or routes.
    Q_INVOKABLE void beginSetPlace(const QString &which);   // "home"|"work"|""
    Q_INVOKABLE void cancelSetPlace();
    Q_INVOKABLE void savePlace(const QString &which, double lat, double lon,
                               const QString &name);

signals:
    void roadChanged();
    void camerasChanged();
    void clustersChanged();
    void poisVisibleChanged();
    void dataReadyChanged();
    void downloadingChanged();
    void favoritesChanged();
    void recentsChanged();
    void placesChanged();
    void pendingPlaceChanged();

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

    // Camera state — GPS-radius markers + proximity alert.
    QVariantList m_camerasView;
    double m_nearestCamDist = -1;
    int    m_nearestCamLimit = 0;
    bool   m_cameraAlert    = false;

    // POI state — clustered for the current viewport. Always on now (the
    // basemap has no POIs of its own), so there's no toggle.
    QVariantList m_clustersView;
    bool   m_poisVisible    = true;
    double m_vpMinLat = 0, m_vpMinLon = 0, m_vpMaxLat = 0, m_vpMaxLon = 0, m_vpZoom = 0;

    // Coverage / housekeeping
    bool   m_dataReady      = false;
    bool   m_downloading    = false;
    double m_lastSetLat     = 1000;    // where local sets were last refreshed
    double m_lastSetLon     = 1000;
    double m_lastLimitLat   = 1000;
    double m_lastLimitLon   = 1000;
    QSet<QPair<int,int>> m_pendingTiles;   // tiles currently downloading/failed-recent

    // Saved-places state
    QString m_pendingPlace;                // "", "home" or "work"
};
