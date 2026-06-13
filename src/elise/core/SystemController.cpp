#include "SystemController.h"

#include <QVariantMap>

namespace {
struct Accent { const char *key; const char *label; const char *base; const char *dim; };

// Four accent presets. "gold" is the Elise default.
static const Accent kAccents[] = {
    { "gold",  "Dourado Elise", "#C6A75E", "#9A7F44" },
    { "teal",  "Teal",          "#3DB0A8", "#2C7E78" },
    { "blue",  "Azul cobalto",  "#3E7BFA", "#2A55B0" },
    { "red",   "Vermelho",      "#E5484D", "#A53236" },
};
constexpr const char *kDefaultAccent = "gold";
}

SystemController::SystemController(QObject *parent)
    : QObject(parent)
    , m_settings(QStringLiteral("hermes"), QStringLiteral("elise"))
{
    m_dark = m_settings.value(QStringLiteral("darkTheme"), true).toBool();
    m_accentKey = m_settings.value(QStringLiteral("accent"),
                                   QString::fromLatin1(kDefaultAccent)).toString();
    bool ok = false;
    for (const auto &a : kAccents)
        if (m_accentKey == QLatin1String(a.key)) { ok = true; break; }
    if (!ok) m_accentKey = QString::fromLatin1(kDefaultAccent);
}

void SystemController::setDark(bool dark)
{
    if (m_dark == dark) return;
    m_dark = dark;
    m_settings.setValue(QStringLiteral("darkTheme"), dark);
    m_settings.sync();
    emit themeChanged();
}

void SystemController::setAccentKey(const QString &k)
{
    if (k == m_accentKey) return;
    for (const auto &a : kAccents) {
        if (k == QLatin1String(a.key)) {
            m_accentKey = k;
            m_settings.setValue(QStringLiteral("accent"), k);
            m_settings.sync();
            emit themeChanged();
            return;
        }
    }
}

QColor SystemController::accent() const
{
    for (const auto &a : kAccents)
        if (m_accentKey == QLatin1String(a.key))
            return QColor(QString::fromLatin1(a.base));
    return QColor(QString::fromLatin1(kAccents[0].base));
}

QColor SystemController::accentDim() const
{
    for (const auto &a : kAccents)
        if (m_accentKey == QLatin1String(a.key))
            return QColor(QString::fromLatin1(a.dim));
    return QColor(QString::fromLatin1(kAccents[0].dim));
}

QVariantList SystemController::accentOptions() const
{
    QVariantList out;
    for (const auto &a : kAccents) {
        QVariantMap m;
        m.insert(QStringLiteral("key"),   QString::fromLatin1(a.key));
        m.insert(QStringLiteral("label"), QString::fromLatin1(a.label));
        m.insert(QStringLiteral("color"), QString::fromLatin1(a.base));
        out.append(m);
    }
    return out;
}
