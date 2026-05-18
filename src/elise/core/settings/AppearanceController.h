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

public:
    explicit AppearanceController(QObject *parent = nullptr);

    QString mapStyle()    const { return m_mapStyle; }
    QString mapStyleUrl() const;
    QVariantList mapStyleOptions() const;

public slots:
    void setMapStyle(const QString &key);

signals:
    void mapStyleChanged();

private:
    QSettings m_settings;
    QString   m_mapStyle;
};
