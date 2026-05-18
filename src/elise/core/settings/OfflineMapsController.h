#pragma once
#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariantList>

// Tracks user-saved offline map regions. Each region is a name + a
// geographic bounding box (north / south / east / west) + min/max zoom.
//
// The actual tile data lives in MapLibre's HTTP cache (configured
// via the maplibre.cache.* plugin parameters in CarMap.qml). This
// controller only owns the list — the CarMap QML side is the one
// that pre-warms the cache by panning over the bbox and that wipes
// the cache directory on "Limpar cache".
class OfflineMapsController : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList regions     READ regions     NOTIFY regionsChanged)
    Q_PROPERTY(qint64       cacheBytes  READ cacheBytes  NOTIFY cacheChanged)
    Q_PROPERTY(QString      cacheDir    READ cacheDir    CONSTANT)

public:
    explicit OfflineMapsController(QObject *parent = nullptr);

    QVariantList regions() const;
    qint64  cacheBytes() const;
    QString cacheDir()   const { return m_cacheDir; }

    Q_INVOKABLE void saveRegion(const QString &name,
                                double north, double south,
                                double east,  double west,
                                int minZoom, int maxZoom);
    Q_INVOKABLE void deleteRegion(const QString &name);
    Q_INVOKABLE void clearCache();
    Q_INVOKABLE void refresh();   // re-scan disk for cache size

signals:
    void regionsChanged();
    void cacheChanged();

private:
    void persist();

    QSettings    m_settings;
    QString      m_cacheDir = QStringLiteral("/var/cache/elise-maplibre");
    QVariantList m_regions;
};
