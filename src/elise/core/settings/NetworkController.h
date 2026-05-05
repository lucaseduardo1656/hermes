#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QTimer>
#include <memory>

namespace sdbus { class IConnection; class IProxy; }

// Client wrapper around net.connman.Manager (system bus, "/").
//
// ConnMan is the GENIVI/automotive-flavoured connectivity daemon. It owns
// wpa_supplicant under the hood, manages DHCP and IP config, exposes a
// uniform model for Wi-Fi, Ethernet, Bluetooth tethering and (via oFono)
// cellular. We expose a small slice tailored to the Conectividade page:
//
//   * `online`            — Manager.State == "online"
//   * `wifiPowered`       — Technology(wifi).Powered
//   * `wifiConnected`     — Technology(wifi).Connected
//   * `bluetoothPowered`  — Technology(bluetooth).Powered
//   * `networks`          — list of dicts (path, name, signal, state,
//                           security, favorite) sourced from Services
//                           filtered to type=="wifi"
//
// Mutators are async best-effort: failures land in `errorOccurred`.
//
// Signal subscriptions:
//   * Manager.PropertyChanged       → update online/state
//   * Manager.ServicesChanged       → rebuild networks list
//   * Manager.TechnologyAdded/Rem   → rebuild technology cache
class NetworkController : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool         online           READ online           NOTIFY changed)
    Q_PROPERTY(QString      state            READ state            NOTIFY changed)
    Q_PROPERTY(bool         wifiPowered      READ wifiPowered      NOTIFY changed)
    Q_PROPERTY(bool         wifiConnected    READ wifiConnected    NOTIFY changed)
    Q_PROPERTY(bool         bluetoothPowered READ bluetoothPowered NOTIFY changed)
    Q_PROPERTY(QVariantList networks         READ networks         NOTIFY networksChanged)

public:
    explicit NetworkController(QObject *parent = nullptr);
    ~NetworkController() override;

    bool         online()           const { return m_state == QLatin1String("online")
                                                || m_state == QLatin1String("ready"); }
    QString      state()            const { return m_state; }
    bool         wifiPowered()      const { return m_wifiPowered; }
    bool         wifiConnected()    const { return m_wifiConnected; }
    bool         bluetoothPowered() const { return m_btPowered; }
    QVariantList networks()         const { return m_networks; }

    Q_INVOKABLE void setWifiPowered(bool on);
    Q_INVOKABLE void setBluetoothPowered(bool on);
    Q_INVOKABLE void scanWifi();
    Q_INVOKABLE void connectService(const QString &path);
    Q_INVOKABLE void disconnectService(const QString &path);
    Q_INVOKABLE void forgetService(const QString &path);

signals:
    void changed();
    void networksChanged();
    void errorOccurred(const QString &message);

private:
    void connect();
    void refreshAll();
    void refreshManagerProps();
    void refreshTechnologies();
    void refreshServices();
    void setTechnologyPowered(const char *type, bool on);

    std::unique_ptr<sdbus::IConnection> m_conn;
    std::unique_ptr<sdbus::IProxy>      m_managerProxy;

    QTimer  m_retryTimer;
    QString m_state;
    bool    m_wifiPowered    = false;
    bool    m_wifiConnected  = false;
    bool    m_btPowered      = false;
    QString m_wifiTechPath;
    QString m_btTechPath;
    QVariantList m_networks;
};
