#include "AppearanceController.h"

#include <QVariantMap>

namespace {
// Two local Tesla-style vector styles (3D buildings, no basemap POIs — only
// ours show). Light is the default; dark mirrors the Model 3/Y night map.
// Built by tools/roaddata/make_map_styles.py and shipped in the board overlay.
constexpr const char *kLocalDir = "file:///usr/share/hermes/styles/";
constexpr const char *kDefault  = "map-light";

struct StyleDef { const char *key; const char *label; };
static const StyleDef kStyles[] = {
    { "map-light", "Claro (3D)" },
    { "map-dark",  "Escuro (3D)" },
};
}

AppearanceController::AppearanceController(QObject *parent)
    : QObject(parent)
    , m_settings(QStringLiteral("hermes"), QStringLiteral("elise"))
{
    m_mapStyle = m_settings.value(QStringLiteral("mapStyle"),
                                  QString::fromLatin1(kDefault)).toString();
    // Sanitise: if the persisted value isn't a known key, fall back.
    bool valid = false;
    for (const auto &s : kStyles)
        if (m_mapStyle == QLatin1String(s.key)) { valid = true; break; }
    if (!valid) m_mapStyle = QString::fromLatin1(kDefault);

    m_units      = m_settings.value(QStringLiteral("units"), m_units).toString();
    if (m_units != QStringLiteral("metric") && m_units != QStringLiteral("imperial"))
        m_units = QStringLiteral("metric");
    m_timeFormat = m_settings.value(QStringLiteral("timeFormat"), m_timeFormat).toString();
    if (m_timeFormat != QStringLiteral("24h") && m_timeFormat != QStringLiteral("12h"))
        m_timeFormat = QStringLiteral("24h");
    m_animationsEnabled = m_settings.value(QStringLiteral("animations"), true).toBool();
}

void AppearanceController::setUnits(const QString &u) {
    if (u == m_units) return;
    if (u != QStringLiteral("metric") && u != QStringLiteral("imperial")) return;
    m_units = u;
    m_settings.setValue(QStringLiteral("units"), u);
    m_settings.sync();
    emit unitsChanged();
}

void AppearanceController::setTimeFormat(const QString &f) {
    if (f == m_timeFormat) return;
    if (f != QStringLiteral("24h") && f != QStringLiteral("12h")) return;
    m_timeFormat = f;
    m_settings.setValue(QStringLiteral("timeFormat"), f);
    m_settings.sync();
    emit timeFormatChanged();
}

void AppearanceController::setAnimationsEnabled(bool on) {
    if (on == m_animationsEnabled) return;
    m_animationsEnabled = on;
    m_settings.setValue(QStringLiteral("animations"), on);
    m_settings.sync();
    emit animationsEnabledChanged();
}

QString AppearanceController::mapStyleUrl() const {
    return QString::fromLatin1(kLocalDir) + m_mapStyle + QStringLiteral(".json");
}

QVariantList AppearanceController::mapStyleOptions() const {
    QVariantList out;
    for (const auto &s : kStyles) {
        QVariantMap m;
        m.insert(QStringLiteral("key"),   QString::fromLatin1(s.key));
        m.insert(QStringLiteral("label"), QString::fromLatin1(s.label));
        out.append(m);
    }
    return out;
}

void AppearanceController::setMapStyle(const QString &key) {
    if (key == m_mapStyle) return;
    bool valid = false;
    for (const auto &s : kStyles)
        if (key == QLatin1String(s.key)) { valid = true; break; }
    if (!valid) return;
    m_mapStyle = key;
    m_settings.setValue(QStringLiteral("mapStyle"), key);
    m_settings.sync();
    emit mapStyleChanged();
}
