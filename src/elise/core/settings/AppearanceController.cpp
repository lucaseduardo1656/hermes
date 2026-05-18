#include "AppearanceController.h"

#include <QVariantMap>

namespace {
constexpr const char *kBaseUrl = "https://tiles.openfreemap.org/styles/";
constexpr const char *kDefault = "dark";

// (key, label) pairs surfaced to QML for the picker. Order matters —
// "Dark" stays first because it's the Tesla-most look.
struct StyleDef { const char *key; const char *label; };
static const StyleDef kStyles[] = {
    { "dark",     "Dark (Tesla-like)" },
    { "positron", "Positron (claro)"  },
    { "liberty",  "Liberty (mapa de rua)" },
    { "bright",   "Bright (vívido)"   },
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
}

QString AppearanceController::mapStyleUrl() const {
    return QString::fromLatin1(kBaseUrl) + m_mapStyle;
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
