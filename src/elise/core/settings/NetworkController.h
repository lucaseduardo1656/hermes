#pragma once
#include <QObject>
#include <QHash>
#include <QSet>
#include <QString>
#include <QVariantList>
#include <QTimer>
#include <memory>

namespace sdbus { class IConnection; class IProxy; }

// Client wrapper around fi.w1.wpa_supplicant1 (system bus).
//
// We talk to wpa_supplicant directly — no ConnMan in the loop. wpa_supplicant
// associates and authenticates; dhcpcd grabs the IP once the link comes up.
//
// Surface exposed to QML:
//   * `online`           — wpa_supplicant Interface.State == "completed"
//   * `state`            — Interface.State (raw string)
//   * `wifiPowered`      — interface link up
//   * `currentSsid`      — SSID of the active network, if any
//   * `networks`         — list of dicts {bssid, ssid, signal, security,
//                          frequency, saved} from BSSs + Networks
//   * `bluetoothPowered` — placeholder false (BlueZ wiring later)
//
// Mutators:
//   * scanWifi()                                 — Interface.Scan
//   * connectWithPassphrase(ssid, psk)           — AddNetwork + SelectNetwork
//   * connectOpen(ssid)                          — AddNetwork (key_mgmt=NONE)
//   * disconnectCurrent()                        — Interface.Disconnect
//   * forgetSsid(ssid)                           — RemoveNetwork
class NetworkController : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool         online           READ online           NOTIFY changed)
    Q_PROPERTY(QString      state            READ state            NOTIFY changed)
    Q_PROPERTY(bool         wifiPowered      READ wifiPowered      NOTIFY changed)
    Q_PROPERTY(QString      currentSsid      READ currentSsid      NOTIFY changed)
    Q_PROPERTY(QString      connectingSsid   READ connectingSsid   NOTIFY changed)
    Q_PROPERTY(QString      lastError        READ lastError        NOTIFY changed)
    Q_PROPERTY(QVariantList networks         READ networks         NOTIFY networksChanged)
    Q_PROPERTY(bool         bluetoothPowered READ bluetoothPowered NOTIFY changed)

public:
    explicit NetworkController(QObject *parent = nullptr);
    ~NetworkController() override;

    bool         online()           const { return m_state == QLatin1String("completed"); }
    QString      state()            const { return m_state; }
    // True when the wlan rfkill switch is unblocked. This is what the UI
    // toggle binds to, not the wpa_supplicant Interface state (which can
    // momentarily go "disconnected" mid-roam without the radio being off).
    bool         wifiPowered()      const { return m_wifiPowered; }
    QString      currentSsid()      const { return m_currentSsid; }
    QString      connectingSsid()   const { return m_connectingSsid; }
    QString      lastError()        const { return m_lastError; }
    QVariantList networks()         const { return m_networks; }
    bool         bluetoothPowered() const { return false; }

    Q_INVOKABLE void setWifiPowered(bool on);
    Q_INVOKABLE void setBluetoothPowered(bool /*on*/) {}
    Q_INVOKABLE void scanWifi();
    Q_INVOKABLE void connectOpen(const QString &ssid);
    Q_INVOKABLE void connectWithPassphrase(const QString &ssid, const QString &psk);
    Q_INVOKABLE void reconnectSaved(const QString &ssid);
    Q_INVOKABLE void disconnectCurrent();
    Q_INVOKABLE void forgetSsid(const QString &ssid);

signals:
    void changed();
    void networksChanged();
    void errorOccurred(const QString &message);

private:
    void connect();
    void rebuildNetworks();
    void refreshState();
    QString findSavedNetworkPath(const QString &ssid) const;
    QString addNetwork(const QString &ssid, const QString &psk);   // returns network path
    void selectNetworkPath(const QString &path);

    std::unique_ptr<sdbus::IConnection> m_conn;
    std::unique_ptr<sdbus::IProxy>      m_iface;        // wpa_supplicant1.Interface

    QTimer  m_retryTimer;
    QString m_ifacePath;
    QString m_state;             // "disconnected", "scanning", "associating", "completed"...
    QString m_currentSsid;
    QString m_connectingSsid;    // SSID currently being attempted; "" when idle
    QString m_lastError;
    bool    m_wifiPowered = false;
    QVariantList m_networks;
};
