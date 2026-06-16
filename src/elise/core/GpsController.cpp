#include "GpsController.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

GpsController::GpsController(QObject *parent) : QObject(parent) {
    m_sock = new QTcpSocket(this);
    connect(m_sock, &QTcpSocket::connected,    this, &GpsController::onConnected);
    connect(m_sock, &QTcpSocket::readyRead,    this, &GpsController::onReadyRead);
    connect(m_sock, &QTcpSocket::disconnected, this, &GpsController::onDisconnected);

    // Grace timer: only mark invalid after 6 s without a good fix.
    m_graceTimer = new QTimer(this);
    m_graceTimer->setSingleShot(true);
    m_graceTimer->setInterval(6000);
    connect(m_graceTimer, &QTimer::timeout, this, [this]() {
        if (m_valid) { m_valid = false; emit positionChanged(); }
    });

    reconnect();
}

void GpsController::reconnect() {
    m_sock->connectToHost(QStringLiteral("127.0.0.1"), 2947);
}

void GpsController::onConnected() {
    m_sock->write("?WATCH={\"enable\":true,\"json\":true}\n");
}

void GpsController::onReadyRead() {
    m_buf += m_sock->readAll();
    int idx;
    while ((idx = m_buf.indexOf('\n')) >= 0) {
        const QByteArray line = m_buf.left(idx);
        m_buf = m_buf.mid(idx + 1);
        parseTpv(line);
    }
}

void GpsController::parseTpv(const QByteArray &line) {
    const QJsonObject obj = QJsonDocument::fromJson(line).object();
    if (obj.value(QStringLiteral("class")).toString() != QLatin1String("TPV"))
        return;

    const int mode = obj.value(QStringLiteral("mode")).toInt();
    if (mode < 2) {
        if (m_valid) { m_valid = false; emit positionChanged(); }
        return;
    }

    m_coord = QGeoCoordinate(
        obj.value(QStringLiteral("lat")).toDouble(),
        obj.value(QStringLiteral("lon")).toDouble(),
        obj.value(QStringLiteral("altHAE")).toDouble());

    m_speed = obj.value(QStringLiteral("speed")).toDouble();

    const QJsonValue track = obj.value(QStringLiteral("track"));
    m_dirValid = !track.isUndefined() && !track.isNull();
    m_dir = m_dirValid ? track.toDouble() : 0.0;

    const QJsonValue epx = obj.value(QStringLiteral("epx"));
    const QJsonValue epy = obj.value(QStringLiteral("epy"));
    m_accValid = !epx.isUndefined() && !epy.isUndefined();
    m_acc = m_accValid ? (epx.toDouble() + epy.toDouble()) / 2.0 : 0.0;

    m_valid = true;
    m_graceTimer->start();   // reset 6 s countdown on every good fix
    emit positionChanged();
}

void GpsController::onDisconnected() {
    // Don't invalidate immediately — let the grace timer do it.
    // This hides brief UDP gaps and TCP reconnects.
    m_graceTimer->start();
    QTimer::singleShot(3000, this, &GpsController::reconnect);
}
