#pragma once
#include <QObject>
#include <QString>
#include <QTimer>
#include <QSettings>

class QNetworkAccessManager;
class QNetworkReply;
class GpsController;

// Regional weather for the home-screen card. Pulls current conditions from
// Open-Meteo (no API key) for the device's location. Location comes from the
// GPS fix when available; otherwise it falls back to a coarse IP geolocation
// (ip-api.com) so the card still works on the bench. The last good location is
// persisted so a cold start without GPS still shows local weather quickly.
class WeatherController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool    valid       READ valid        NOTIFY changed)
    Q_PROPERTY(double  temperature READ temperature  NOTIFY changed)   // °C
    Q_PROPERTY(double  feelsLike   READ feelsLike    NOTIFY changed)   // °C
    Q_PROPERTY(int     humidity    READ humidity     NOTIFY changed)   // %
    Q_PROPERTY(double  wind        READ wind         NOTIFY changed)   // km/h
    Q_PROPERTY(int     code        READ code         NOTIFY changed)   // WMO code
    Q_PROPERTY(bool    isDay       READ isDay        NOTIFY changed)
    Q_PROPERTY(QString condition   READ condition    NOTIFY changed)
    Q_PROPERTY(QString icon        READ icon         NOTIFY changed)   // Material symbol
    Q_PROPERTY(QString place       READ place        NOTIFY changed)

public:
    explicit WeatherController(QObject *parent = nullptr);

    // Wire GPS position updates as the preferred location source.
    void bindGps(GpsController *gps);

    bool    valid()       const { return m_valid; }
    double  temperature() const { return m_temp; }
    double  feelsLike()   const { return m_feels; }
    int     humidity()    const { return m_humidity; }
    double  wind()        const { return m_wind; }
    int     code()        const { return m_code; }
    bool    isDay()       const { return m_day; }
    QString condition()   const;
    QString icon()        const;
    QString place()       const { return m_place; }

public slots:
    void refresh();

signals:
    void changed();

private slots:
    void onGpsPosition();

private:
    void fetchWeather(double lat, double lon);
    void fetchIpLocation();
    void setLocation(double lat, double lon, const QString &place);

    QNetworkAccessManager *m_net;
    GpsController *m_gps = nullptr;
    QSettings m_settings;
    QTimer    m_poll;

    double m_lat = 0.0, m_lon = 0.0;
    bool   m_haveLoc = false;

    bool    m_valid    = false;
    double  m_temp     = 0.0;
    double  m_feels    = 0.0;
    int     m_humidity = 0;
    double  m_wind     = 0.0;
    int     m_code     = 0;
    bool    m_day      = true;
    QString m_place;
};
