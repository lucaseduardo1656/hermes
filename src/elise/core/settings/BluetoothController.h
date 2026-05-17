#pragma once
#include <QObject>
#include <QHash>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <memory>

namespace sdbus {
class IConnection;
class IProxy;
class IObject;
}

// Client wrapper around org.bluez (system bus). Phase 1 scope: Pi acts
// as a Bluetooth source, pairs with speakers/headphones, exposes
// pair/connect/disconnect/forget to QML, registers a NoInputNoOutput
// agent so just-works pairing succeeds without user prompts.
//
// QML surface:
//   * powered         — adapter rfkill state
//   * discovering     — scan in progress
//   * connectedAlias  — alias of the device currently audio-connected
//   * devices         — list of {address, alias, paired, trusted,
//                                connected, rssi, icon}
class BluetoothController : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool         powered          READ powered          NOTIFY changed)
    Q_PROPERTY(bool         discovering      READ discovering      NOTIFY changed)
    Q_PROPERTY(bool         discoverable     READ discoverable     NOTIFY changed)
    Q_PROPERTY(QString      adapterAlias     READ adapterAlias     NOTIFY changed)
    Q_PROPERTY(QString      connectedAlias   READ connectedAlias   NOTIFY changed)
    Q_PROPERTY(QString      connectingAddr   READ connectingAddr   NOTIFY changed)
    Q_PROPERTY(QString      lastError        READ lastError        NOTIFY changed)
    Q_PROPERTY(QVariantList devices          READ devices          NOTIFY devicesChanged)

public:
    explicit BluetoothController(QObject *parent = nullptr);
    ~BluetoothController() override;

    bool         powered()        const { return m_powered; }
    bool         discovering()    const { return m_discovering; }
    bool         discoverable()   const { return m_discoverable; }
    QString      adapterAlias()   const { return m_adapterAlias; }
    QString      connectedAlias() const { return m_connectedAlias; }
    QString      connectingAddr() const { return m_connectingAddr; }
    QString      lastError()      const { return m_lastError; }
    QVariantList devices()        const { return m_devices; }

    Q_INVOKABLE void setPowered(bool on);
    Q_INVOKABLE void setDiscoverable(bool on);
    Q_INVOKABLE void setAdapterAlias(const QString &alias);
    Q_INVOKABLE void startScan();
    Q_INVOKABLE void stopScan();
    Q_INVOKABLE void pair(const QString &address);
    Q_INVOKABLE void connectDevice(const QString &address);
    Q_INVOKABLE void disconnectDevice(const QString &address);
    Q_INVOKABLE void forget(const QString &address);

signals:
    void changed();
    void devicesChanged();
    void errorOccurred(const QString &message);

private:
    void connect();
    void registerAgent();
    void onInterfacesAdded(const QString &path);
    void onInterfacesRemoved(const QString &path);
    void onDevicePropertiesChanged(const QString &path);
    void rebuildDevices();
    void refreshAdapterState();
    void autoReconnectTrusted();
    QString devicePathFor(const QString &address) const;

    std::unique_ptr<sdbus::IConnection> m_conn;
    std::unique_ptr<sdbus::IProxy>      m_root;     // ObjectManager at /
    std::unique_ptr<sdbus::IProxy>      m_adapter;  // /org/bluez/hci0
    std::unique_ptr<sdbus::IObject>     m_agent;    // our /com/hermes/btagent

    // Per-device proxy cache — we hold one to listen for PropertiesChanged.
    QHash<QString, std::shared_ptr<sdbus::IProxy>> m_devProxies;

    QTimer       m_retryTimer;
    bool         m_powered        = false;
    bool         m_discovering    = false;
    bool         m_discoverable   = false;
    QString      m_adapterAlias;
    QString      m_connectedAlias;
    QString      m_connectingAddr;
    QString      m_lastError;
    QVariantList m_devices;
    bool         m_autoReconnected = false;
};
