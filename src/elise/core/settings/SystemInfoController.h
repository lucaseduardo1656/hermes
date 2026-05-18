#pragma once
#include <QObject>
#include <QString>
#include <QTimer>
#include <memory>

namespace sdbus { class IConnection; class IProxy; }

// Client wrapper around org.hermes.System1 (served by hermes-systemd).
//
// Exposes the daemon's read-only properties as Qt properties so QML can
// bind via `Settings.sys.hostname` / `Settings.sys.uptimeSeconds` / etc.
// Privileged methods (reboot, powerOff, setHostname) are surfaced as
// invokables.
//
// Threading: sdbus-c++ runs an internal event-loop thread (started via
// `enterEventLoopAsync`). Inbound D-Bus signals are marshalled back to the
// Qt thread with QMetaObject::invokeMethod.
class SystemInfoController : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString hostname           READ hostname           NOTIFY changed)
    Q_PROPERTY(QString kernelVersion      READ kernelVersion      NOTIFY changed)
    Q_PROPERTY(QString osVersion          READ osVersion          NOTIFY changed)
    Q_PROPERTY(QString appVersion         READ appVersion         NOTIFY changed)
    Q_PROPERTY(quint64 uptimeSeconds      READ uptimeSeconds      NOTIFY changed)
    Q_PROPERTY(quint64 storageUsedBytes   READ storageUsedBytes   NOTIFY changed)
    Q_PROPERTY(quint64 storageTotalBytes  READ storageTotalBytes  NOTIFY changed)
    Q_PROPERTY(bool    online             READ online             NOTIFY onlineChanged)

public:
    explicit SystemInfoController(QObject *parent = nullptr);
    ~SystemInfoController() override;

    QString hostname()          const { return m_hostname; }
    QString kernelVersion()     const { return m_kernelVersion; }
    QString osVersion()         const { return m_osVersion; }
    QString appVersion()        const { return m_appVersion; }
    quint64 uptimeSeconds()     const { return m_uptime; }
    quint64 storageUsedBytes()  const { return m_storageUsed; }
    quint64 storageTotalBytes() const { return m_storageTotal; }
    bool    online()            const { return m_online; }

    // Privileged operations on the daemon. Each runs via the existing async
    // sdbus-c++ event loop; failures land in `errorOccurred(QString)`.
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void powerOff();
    Q_INVOKABLE void setHostname(const QString &name);

signals:
    void changed();
    void onlineChanged();
    void errorOccurred(const QString &message);

private:
    void connect();
    void refresh();           // pulls all properties from the daemon
    void setOnline(bool v);

    std::unique_ptr<sdbus::IConnection> m_conn;
    std::unique_ptr<sdbus::IProxy>      m_proxy;

    QTimer  m_pollTimer;      // periodic refresh for uptime/storage
    QString m_hostname;
    QString m_kernelVersion;
    QString m_osVersion;
    QString m_appVersion;
    quint64 m_uptime       = 0;
    quint64 m_storageUsed  = 0;
    quint64 m_storageTotal = 0;
    bool    m_online       = false;
};
