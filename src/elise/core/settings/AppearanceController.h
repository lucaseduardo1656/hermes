#pragma once
#include <QObject>
#include <QString>
#include <QSettings>

// Persisted UI/UX preferences. Currently only `mapStyle` — the key
// of the OpenFreeMap style the CarMap renders with. Persisted via
// QSettings under org.hermes/elise.
class AppearanceController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString mapStyle    READ mapStyle    WRITE setMapStyle    NOTIFY mapStyleChanged)
    Q_PROPERTY(QString mapStyleUrl READ mapStyleUrl                       NOTIFY mapStyleChanged)
    Q_PROPERTY(QVariantList mapStyleOptions READ mapStyleOptions          CONSTANT)

    // metric (km/m) or imperial (mi/ft). Drives the route summary
    // formatting in CarMap.
    Q_PROPERTY(QString units       READ units       WRITE setUnits       NOTIFY unitsChanged)
    // "24h" or "12h" — used by any future clock surface.
    Q_PROPERTY(QString timeFormat  READ timeFormat  WRITE setTimeFormat  NOTIFY timeFormatChanged)
    // Disables Theme.dur* animations app-wide when false.
    Q_PROPERTY(bool animationsEnabled READ animationsEnabled
                                      WRITE setAnimationsEnabled
                                      NOTIFY animationsEnabledChanged)

public:
    explicit AppearanceController(QObject *parent = nullptr);

    QString mapStyle()    const { return m_mapStyle; }
    QString mapStyleUrl() const;
    QVariantList mapStyleOptions() const;
    QString units()       const { return m_units; }
    QString timeFormat()  const { return m_timeFormat; }
    bool    animationsEnabled() const { return m_animationsEnabled; }

public slots:
    void setMapStyle(const QString &key);
    void setUnits(const QString &u);
    void setTimeFormat(const QString &f);
    void setAnimationsEnabled(bool on);

signals:
    void mapStyleChanged();
    void unitsChanged();
    void timeFormatChanged();
    void animationsEnabledChanged();

private:
    QSettings m_settings;
    QString   m_mapStyle;
    QString   m_units      = QStringLiteral("metric");
    QString   m_timeFormat = QStringLiteral("24h");
    bool      m_animationsEnabled = true;
};
