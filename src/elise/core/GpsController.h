#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QTimer>
#include <QGeoCoordinate>

class GpsController : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool valid              READ valid              NOTIFY positionChanged)
    Q_PROPERTY(QGeoCoordinate coordinate READ coordinate       NOTIFY positionChanged)
    Q_PROPERTY(double speed            READ speed              NOTIFY positionChanged)
    Q_PROPERTY(bool directionValid     READ directionValid     NOTIFY positionChanged)
    Q_PROPERTY(double direction        READ direction          NOTIFY positionChanged)
    Q_PROPERTY(bool accuracyValid      READ accuracyValid      NOTIFY positionChanged)
    Q_PROPERTY(double horizontalAccuracy READ horizontalAccuracy NOTIFY positionChanged)

public:
    explicit GpsController(QObject *parent = nullptr);

    bool          valid()              const { return m_valid; }
    QGeoCoordinate coordinate()        const { return m_coord; }
    double        speed()              const { return m_speed; }
    bool          directionValid()     const { return m_dirValid; }
    double        direction()          const { return m_dir; }
    bool          accuracyValid()      const { return m_accValid; }
    double        horizontalAccuracy() const { return m_acc; }

signals:
    void positionChanged();

private slots:
    void onConnected();
    void onReadyRead();
    void onDisconnected();

private:
    void parseTpv(const QByteArray &line);
    void reconnect();
    void startGraceTimer();

    QTcpSocket *m_sock;
    QTimer     *m_graceTimer;   // keeps valid=true for 6 s after last good fix
    QByteArray  m_buf;

    bool           m_valid    = false;
    QGeoCoordinate m_coord;
    double         m_speed    = 0;
    bool           m_dirValid = false;
    double         m_dir      = 0;
    bool           m_accValid = false;
    double         m_acc      = 0;
};
