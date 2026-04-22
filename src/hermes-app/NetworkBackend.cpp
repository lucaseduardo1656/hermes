#include "NetworkBackend.h"
#include <QProcess>
#include <QFile>
#include <QTextStream>
#include <QTimer>

NetworkBackend::NetworkBackend(QObject *parent) : QObject(parent)
{
    connect(&m_wifiTimer, &QTimer::timeout, this, &NetworkBackend::pollWifi);
    m_wifiTimer.start(5000);
    pollWifi();

    connect(&m_btTimer, &QTimer::timeout, this, &NetworkBackend::pollBt);
    m_btTimer.start(8000);
    pollBt();
}

QString NetworkBackend::run(const QString &cmd, int timeoutMs) const
{
    QProcess p;
    p.start(QStringLiteral("sh"), {QStringLiteral("-c"), cmd});
    p.waitForFinished(timeoutMs);
    return QString::fromLocal8Bit(p.readAllStandardOutput()).trimmed();
}

// ── WiFi ──────────────────────────────────────────────────────────────────────

void NetworkBackend::pollWifi()
{
    // Check IFF_UP flag — operstate="down" for WiFi just means not associated, not radio off
    QFile flagsFile(QStringLiteral("/sys/class/net/") + m_iface + QStringLiteral("/flags"));
    if (!flagsFile.open(QIODevice::ReadOnly)) {
        bool changed = m_wifiEnabled || m_wifiConnected;
        m_wifiEnabled = m_wifiConnected = false;
        m_wifiSsid.clear(); m_wifiIp.clear(); m_wifiSignal = 0;
        if (changed) emit wifiChanged();
        return;
    }
    const uint flagVal = QTextStream(&flagsFile).readAll().trimmed().toUInt(nullptr, 16);
    flagsFile.close();

    const bool enabled = (flagVal & 0x1U) != 0; // IFF_UP

    QString ssid, ip;
    bool connected = false;
    int signal = 0;

    if (enabled) {
        // wpa_cli status
        const QString status = run(
            QStringLiteral("wpa_cli -i ") + m_iface + QStringLiteral(" status 2>/dev/null"));

        if (status.contains(QLatin1String("wpa_state=COMPLETED"))) {
            connected = true;
            for (const QString &line : status.split(QLatin1Char('\n'))) {
                if (line.startsWith(QLatin1String("ssid=")))
                    ssid = line.mid(5);
                else if (line.startsWith(QLatin1String("ip_address=")))
                    ip = line.mid(11);
            }

            // Signal via wpa_cli signal_poll
            const QString sp = run(
                QStringLiteral("wpa_cli -i ") + m_iface + QStringLiteral(" signal_poll 2>/dev/null"));
            for (const QString &line : sp.split(QLatin1Char('\n'))) {
                if (line.startsWith(QLatin1String("RSSI="))) {
                    const int rssi = line.mid(5).toInt();
                    signal = qBound(0, (rssi + 90) * 100 / 60, 100);
                }
            }
        }

        // Fallback IP from dhcpcd / ip addr
        if (ip.isEmpty() && connected) {
            ip = run(QStringLiteral("ip -4 addr show ") + m_iface +
                     QStringLiteral(" 2>/dev/null | grep -oP '(?<=inet )[^/]+'"));
        }
    }

    const bool anyChange = (m_wifiEnabled   != enabled)   ||
                           (m_wifiConnected != connected)  ||
                           (m_wifiSsid      != ssid)       ||
                           (m_wifiIp        != ip)         ||
                           (m_wifiSignal    != signal);

    m_wifiEnabled   = enabled;
    m_wifiConnected = connected;
    m_wifiSsid      = ssid;
    m_wifiIp        = ip.isEmpty() ? QStringLiteral("—") : ip;
    m_wifiSignal    = signal;

    if (anyChange) emit wifiChanged();
}

void NetworkBackend::setWifiEnabled(bool enabled)
{
    if (enabled)
        run(QStringLiteral("ip link set ") + m_iface + QStringLiteral(" up"));
    else
        run(QStringLiteral("ip link set ") + m_iface + QStringLiteral(" down"));

    QTimer::singleShot(1200, this, &NetworkBackend::pollWifi);
}

void NetworkBackend::wifiScan()
{
    if (m_wifiScanning) return;
    m_wifiScanning = true;
    emit wifiScanningChanged();

    run(QStringLiteral("wpa_cli -i ") + m_iface + QStringLiteral(" scan 2>/dev/null"));

    QTimer::singleShot(3500, this, [this]() {
        const QString raw = run(
            QStringLiteral("wpa_cli -i ") + m_iface + QStringLiteral(" scan_results 2>/dev/null"),
            6000);

        m_wifiNetworks.clear();

        bool firstLine = true;
        for (const QString &line : raw.split(QLatin1Char('\n'))) {
            if (firstLine) { firstLine = false; continue; } // skip header
            const QStringList parts = line.split(QLatin1Char('\t'));
            if (parts.size() < 5) continue;

            const QString ssid = parts.at(4).trimmed();
            if (ssid.isEmpty()) continue;

            const int rssi    = parts.at(2).toInt();
            const QString flags = parts.at(3);

            QVariantMap net;
            net[QStringLiteral("ssid")]    = ssid;
            net[QStringLiteral("signal")]  = qBound(0, (rssi + 90) * 100 / 60, 100);
            net[QStringLiteral("secured")] = flags.contains(QLatin1String("WPA")) ||
                                             flags.contains(QLatin1String("WEP"));
            m_wifiNetworks.append(net);
        }

        m_wifiScanning = false;
        emit wifiScanningChanged();
        emit wifiNetworksChanged();
    });
}

void NetworkBackend::wifiConnect(const QString &ssid, const QString &password)
{
    // Remove any existing saved network for this SSID
    const QString list = run(QStringLiteral("wpa_cli -i ") + m_iface +
                             QStringLiteral(" list_networks 2>/dev/null"));
    for (const QString &line : list.split(QLatin1Char('\n'))) {
        const QStringList cols = line.split(QLatin1Char('\t'));
        if (cols.size() > 1 && cols.at(1).trimmed() == ssid)
            run(QStringLiteral("wpa_cli -i ") + m_iface +
                QStringLiteral(" remove_network ") + cols.at(0).trimmed());
    }

    // Add network
    const QString netId = run(QStringLiteral("wpa_cli -i ") + m_iface +
                               QStringLiteral(" add_network 2>/dev/null"));
    if (netId.isEmpty() || netId == QLatin1String("FAIL")) {
        emit wifiConnectError(QStringLiteral("Falha ao criar perfil de rede"));
        return;
    }

    auto wcli = [&](const QString &args) {
        return run(QStringLiteral("wpa_cli -i ") + m_iface + QLatin1Char(' ') + args);
    };

    wcli(QStringLiteral("set_network ") + netId + QStringLiteral(" ssid '\"") + ssid + QStringLiteral("\"'"));

    if (password.isEmpty()) {
        wcli(QStringLiteral("set_network ") + netId + QStringLiteral(" key_mgmt NONE"));
    } else {
        wcli(QStringLiteral("set_network ") + netId + QStringLiteral(" psk '\"") + password + QStringLiteral("\"'"));
    }

    wcli(QStringLiteral("enable_network ") + netId);
    wcli(QStringLiteral("select_network ") + netId);
    wcli(QStringLiteral("save_config"));

    // dhcpcd will pick up the new association automatically; give it time
    QTimer::singleShot(5000, this, &NetworkBackend::pollWifi);
}

void NetworkBackend::wifiDisconnect()
{
    run(QStringLiteral("wpa_cli -i ") + m_iface + QStringLiteral(" disconnect 2>/dev/null"));
    QTimer::singleShot(1000, this, &NetworkBackend::pollWifi);
}

// ── Bluetooth ─────────────────────────────────────────────────────────────────

void NetworkBackend::pollBt()
{
    // bluetoothctl show gives adapter info
    const QString show = run(QStringLiteral("bluetoothctl show 2>/dev/null"));

    const bool powered = show.contains(QLatin1String("Powered: yes"));

    QString name;
    for (const QString &line : show.split(QLatin1Char('\n'))) {
        if (line.trimmed().startsWith(QLatin1String("Name:"))) {
            name = line.section(QLatin1Char(':'), 1).trimmed();
            break;
        }
    }

    QVariantList paired;
    if (powered) {
        const QString devs = run(
            QStringLiteral("bluetoothctl paired-devices 2>/dev/null"));
        for (const QString &line : devs.split(QLatin1Char('\n'))) {
            // Format: "Device AA:BB:CC:DD:EE:FF Name"
            if (!line.startsWith(QLatin1String("Device "))) continue;
            const QStringList parts = line.split(QLatin1Char(' '));
            if (parts.size() < 3) continue;
            QVariantMap dev;
            dev[QStringLiteral("address")] = parts.at(1);
            dev[QStringLiteral("name")]    = parts.mid(2).join(QLatin1Char(' '));
            paired.append(dev);
        }
    }

    const bool changed = (m_btEnabled != powered) ||
                         (m_btName    != name)     ||
                         (m_btPaired  != paired);
    m_btEnabled = powered;
    m_btName    = name;
    m_btPaired  = paired;

    if (changed) emit btChanged();
}

void NetworkBackend::setBtEnabled(bool enabled)
{
    run(QStringLiteral("bluetoothctl power ") +
        (enabled ? QStringLiteral("on") : QStringLiteral("off")));
    QTimer::singleShot(1500, this, &NetworkBackend::pollBt);
}

void NetworkBackend::btRefreshPaired()
{
    pollBt();
}
