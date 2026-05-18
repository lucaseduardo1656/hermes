#include "OfflineMapsController.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QVariantMap>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>

OfflineMapsController::OfflineMapsController(QObject *parent)
    : QObject(parent)
    , m_settings(QStringLiteral("hermes"), QStringLiteral("elise"))
{
    // QSettings list-of-maps: store as JSON to keep the format stable
    // across QVariant <-> ini round-trips.
    const QString blob = m_settings.value(QStringLiteral("offlineRegions")).toString();
    if (!blob.isEmpty()) {
        QJsonDocument doc = QJsonDocument::fromJson(blob.toUtf8());
        if (doc.isArray()) {
            for (const QJsonValue &v : doc.array())
                m_regions.append(v.toObject().toVariantMap());
        }
    }
    QDir().mkpath(m_cacheDir);
}

QVariantList OfflineMapsController::regions() const { return m_regions; }

qint64 OfflineMapsController::cacheBytes() const {
    qint64 total = 0;
    QDirIterator it(m_cacheDir, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) { it.next(); total += it.fileInfo().size(); }
    return total;
}

void OfflineMapsController::persist() {
    QJsonArray arr;
    for (const QVariant &v : std::as_const(m_regions))
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    m_settings.setValue(QStringLiteral("offlineRegions"),
                        QString::fromUtf8(QJsonDocument(arr).toJson(
                            QJsonDocument::Compact)));
    m_settings.sync();
    emit regionsChanged();
}

void OfflineMapsController::saveRegion(const QString &name,
                                       double north, double south,
                                       double east,  double west,
                                       int minZoom, int maxZoom) {
    // Drop any region with the same name — replacing.
    for (int i = m_regions.size() - 1; i >= 0; --i)
        if (m_regions.at(i).toMap().value("name").toString() == name)
            m_regions.removeAt(i);

    QVariantMap m;
    m.insert("name",    name);
    m.insert("north",   north);
    m.insert("south",   south);
    m.insert("east",    east);
    m.insert("west",    west);
    m.insert("minZoom", minZoom);
    m.insert("maxZoom", maxZoom);
    m.insert("savedAt", QDateTime::currentSecsSinceEpoch());
    m_regions.append(m);
    persist();
}

void OfflineMapsController::deleteRegion(const QString &name) {
    bool removed = false;
    for (int i = m_regions.size() - 1; i >= 0; --i) {
        if (m_regions.at(i).toMap().value("name").toString() == name) {
            m_regions.removeAt(i);
            removed = true;
        }
    }
    if (removed) persist();
}

void OfflineMapsController::clearCache() {
    QDir d(m_cacheDir);
    if (d.exists()) {
        d.removeRecursively();
        QDir().mkpath(m_cacheDir);
    }
    emit cacheChanged();
}

void OfflineMapsController::refresh() { emit cacheChanged(); }
