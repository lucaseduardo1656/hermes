#include "WeatherController.h"
#include "GpsController.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QGeoCoordinate>
#include <cmath>

WeatherController::WeatherController(QObject *parent)
    : QObject(parent)
    , m_net(new QNetworkAccessManager(this))
    , m_settings(QStringLiteral("hermes"), QStringLiteral("elise"))
{
    // Restore the last known location so a cold bench start shows weather
    // before any GPS/IP lookup completes.
    const double lat = m_settings.value(QStringLiteral("weather/lat")).toDouble();
    const double lon = m_settings.value(QStringLiteral("weather/lon")).toDouble();
    m_place = m_settings.value(QStringLiteral("weather/place")).toString();
    if (lat != 0.0 || lon != 0.0) {
        m_lat = lat; m_lon = lon; m_haveLoc = true;
    }

    // Refresh every 15 minutes; conditions don't change faster than that and it
    // keeps the API courteous.
    m_poll.setInterval(15 * 60 * 1000);
    QObject::connect(&m_poll, &QTimer::timeout, this, &WeatherController::refresh);
    m_poll.start();

    // Kick off shortly after construction: use the persisted location if we have
    // one, otherwise resolve via IP. GPS, once it gets a fix, takes over.
    QTimer::singleShot(1500, this, [this] {
        if (m_haveLoc) fetchWeather(m_lat, m_lon);
        else           fetchIpLocation();
    });
}

void WeatherController::bindGps(GpsController *gps) {
    m_gps = gps;
    if (m_gps)
        QObject::connect(m_gps, &GpsController::positionChanged,
                         this, &WeatherController::onGpsPosition);
}

void WeatherController::onGpsPosition() {
    if (!m_gps || !m_gps->valid()) return;
    const QGeoCoordinate c = m_gps->coordinate();
    if (!c.isValid()) return;
    // Only refetch when we've moved enough to matter (~5 km) or have no data yet.
    const double dLat = c.latitude()  - m_lat;
    const double dLon = c.longitude() - m_lon;
    const bool moved = std::sqrt(dLat * dLat + dLon * dLon) > 0.05;  // ~5 km
    setLocation(c.latitude(), c.longitude(), m_place);
    if (moved || !m_valid)
        fetchWeather(m_lat, m_lon);
}

void WeatherController::setLocation(double lat, double lon, const QString &place) {
    m_lat = lat; m_lon = lon; m_haveLoc = true;
    if (!place.isEmpty()) m_place = place;
    m_settings.setValue(QStringLiteral("weather/lat"), lat);
    m_settings.setValue(QStringLiteral("weather/lon"), lon);
    if (!m_place.isEmpty())
        m_settings.setValue(QStringLiteral("weather/place"), m_place);
}

void WeatherController::refresh() {
    if (m_haveLoc) fetchWeather(m_lat, m_lon);
    else           fetchIpLocation();
}

void WeatherController::fetchIpLocation() {
    QNetworkRequest req(QUrl(QStringLiteral("http://ip-api.com/json?fields=status,lat,lon,city")));
    QNetworkReply *reply = m_net->get(req);
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) return;
        const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
        if (o.value(QStringLiteral("status")).toString() != QLatin1String("success")) return;
        setLocation(o.value(QStringLiteral("lat")).toDouble(),
                    o.value(QStringLiteral("lon")).toDouble(),
                    o.value(QStringLiteral("city")).toString());
        emit changed();   // surface the place name early
        fetchWeather(m_lat, m_lon);
    });
}

void WeatherController::fetchWeather(double lat, double lon) {
    QUrl url(QStringLiteral("https://api.open-meteo.com/v1/forecast"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("latitude"),  QString::number(lat, 'f', 4));
    q.addQueryItem(QStringLiteral("longitude"), QString::number(lon, 'f', 4));
    q.addQueryItem(QStringLiteral("current"),
                   QStringLiteral("temperature_2m,relative_humidity_2m,apparent_temperature,"
                                  "is_day,weather_code,wind_speed_10m"));
    q.addQueryItem(QStringLiteral("timezone"), QStringLiteral("auto"));
    url.setQuery(q);

    QNetworkReply *reply = m_net->get(QNetworkRequest(url));
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) return;
        const QJsonObject root = QJsonDocument::fromJson(reply->readAll()).object();
        const QJsonObject cur  = root.value(QStringLiteral("current")).toObject();
        if (cur.isEmpty()) return;

        m_temp     = cur.value(QStringLiteral("temperature_2m")).toDouble();
        m_feels    = cur.value(QStringLiteral("apparent_temperature")).toDouble();
        m_humidity = cur.value(QStringLiteral("relative_humidity_2m")).toInt();
        m_wind     = cur.value(QStringLiteral("wind_speed_10m")).toDouble();
        m_code     = cur.value(QStringLiteral("weather_code")).toInt();
        m_day      = cur.value(QStringLiteral("is_day")).toInt() == 1;
        m_valid    = true;
        emit changed();
    });
}

// WMO weather interpretation codes -> human label (pt-BR).
QString WeatherController::condition() const {
    switch (m_code) {
    case 0:  return QStringLiteral("Céu limpo");
    case 1:  return QStringLiteral("Predomínio de sol");
    case 2:  return QStringLiteral("Parcialmente nublado");
    case 3:  return QStringLiteral("Nublado");
    case 45: case 48: return QStringLiteral("Névoa");
    case 51: case 53: case 55: return QStringLiteral("Garoa");
    case 56: case 57: return QStringLiteral("Garoa congelante");
    case 61: case 63: case 65: return QStringLiteral("Chuva");
    case 66: case 67: return QStringLiteral("Chuva congelante");
    case 71: case 73: case 75: return QStringLiteral("Neve");
    case 77: return QStringLiteral("Grãos de neve");
    case 80: case 81: case 82: return QStringLiteral("Pancadas de chuva");
    case 85: case 86: return QStringLiteral("Pancadas de neve");
    case 95: return QStringLiteral("Tempestade");
    case 96: case 99: return QStringLiteral("Tempestade com granizo");
    default: return QStringLiteral("—");
    }
}

// WMO code -> Material Symbols glyph name (day/night aware where it matters).
QString WeatherController::icon() const {
    switch (m_code) {
    case 0:  return m_day ? QStringLiteral("clear_day") : QStringLiteral("clear_night");
    case 1:  return m_day ? QStringLiteral("clear_day") : QStringLiteral("clear_night");
    case 2:  return m_day ? QStringLiteral("partly_cloudy_day") : QStringLiteral("partly_cloudy_night");
    case 3:  return QStringLiteral("cloud");
    case 45: case 48: return QStringLiteral("foggy");
    case 51: case 53: case 55:
    case 56: case 57: return QStringLiteral("rainy_light");
    case 61: case 63: case 65:
    case 66: case 67: return QStringLiteral("rainy");
    case 80: case 81: case 82: return QStringLiteral("rainy");
    case 71: case 73: case 75:
    case 77: case 85: case 86: return QStringLiteral("weather_snowy");
    case 95: case 96: case 99: return QStringLiteral("thunderstorm");
    default: return QStringLiteral("cloud");
    }
}
