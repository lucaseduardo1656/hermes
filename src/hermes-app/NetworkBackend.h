#pragma once
#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>

class NetworkBackend : public QObject {
    Q_OBJECT

    // ── WiFi ──────────────────────────────────────────────────
    Q_PROPERTY(bool   wifiEnabled   READ wifiEnabled   NOTIFY wifiChanged)
    Q_PROPERTY(bool   wifiConnected READ wifiConnected NOTIFY wifiChanged)
    Q_PROPERTY(QString wifiSsid     READ wifiSsid      NOTIFY wifiChanged)
    Q_PROPERTY(QString wifiIp       READ wifiIp        NOTIFY wifiChanged)
    Q_PROPERTY(int    wifiSignal    READ wifiSignal    NOTIFY wifiChanged)
    Q_PROPERTY(bool   wifiScanning  READ wifiScanning  NOTIFY wifiScanningChanged)
    Q_PROPERTY(QVariantList wifiNetworks READ wifiNetworks NOTIFY wifiNetworksChanged)

    // ── Bluetooth ─────────────────────────────────────────────
    Q_PROPERTY(bool   btEnabled   READ btEnabled   NOTIFY btChanged)
    Q_PROPERTY(QString btName     READ btName      NOTIFY btChanged)
    Q_PROPERTY(QVariantList btPaired READ btPaired NOTIFY btChanged)

public:
    explicit NetworkBackend(QObject *parent = nullptr);

    bool        wifiEnabled()   const { return m_wifiEnabled; }
    bool        wifiConnected() const { return m_wifiConnected; }
    QString     wifiSsid()      const { return m_wifiSsid; }
    QString     wifiIp()        const { return m_wifiIp; }
    int         wifiSignal()    const { return m_wifiSignal; }
    bool        wifiScanning()  const { return m_wifiScanning; }
    QVariantList wifiNetworks() const { return m_wifiNetworks; }

    bool        btEnabled()     const { return m_btEnabled; }
    QString     btName()        const { return m_btName; }
    QVariantList btPaired()     const { return m_btPaired; }

public slots:
    // WiFi
    void setWifiEnabled(bool enabled);
    void wifiScan();
    void wifiConnect(const QString &ssid, const QString &password);
    void wifiDisconnect();

    // Bluetooth
    void setBtEnabled(bool enabled);
    void btRefreshPaired();

signals:
    void wifiChanged();
    void wifiScanningChanged();
    void wifiNetworksChanged();
    void wifiConnectError(const QString &reason);

    void btChanged();

private slots:
    void pollWifi();
    void pollBt();

private:
    QString run(const QString &cmd, int timeoutMs = 4000) const;

    QTimer m_wifiTimer;
    QTimer m_btTimer;

    // WiFi state
    bool         m_wifiEnabled   = false;
    bool         m_wifiConnected = false;
    QString      m_wifiSsid;
    QString      m_wifiIp;
    int          m_wifiSignal    = 0;
    bool         m_wifiScanning  = false;
    QVariantList m_wifiNetworks;

    // Bluetooth state
    bool         m_btEnabled = false;
    QString      m_btName;
    QVariantList m_btPaired;

    const QString m_iface = QStringLiteral("wlan0");
};
