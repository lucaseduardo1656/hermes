#include "NetworkController.h"

#include <sdbus-c++/sdbus-c++.h>

#include <QDebug>
#include <QMetaObject>
#include <QVariantMap>

namespace {
constexpr const char *kService    = "fi.w1.wpa_supplicant1";
constexpr const char *kRoot       = "/fi/w1/wpa_supplicant1";
constexpr const char *kRootIf     = "fi.w1.wpa_supplicant1";
constexpr const char *kIfaceIf    = "fi.w1.wpa_supplicant1.Interface";
constexpr const char *kBssIf      = "fi.w1.wpa_supplicant1.BSS";
constexpr const char *kNetworkIf  = "fi.w1.wpa_supplicant1.Network";
constexpr const char *kPropsIf    = "org.freedesktop.DBus.Properties";

QString ssidFromBytes(const std::vector<uint8_t> &bytes) {
    return QString::fromUtf8(reinterpret_cast<const char*>(bytes.data()),
                             static_cast<int>(bytes.size()));
}

// `Variant.get<T>()` throws on type mismatch; these helpers just swallow it
// and fall back to a default to keep refresh paths from blowing up when
// wpa_supplicant returns an unexpected type.
QString variantStr(const sdbus::Variant &v) {
    try { return QString::fromStdString(v.get<std::string>()); } catch (...) { return {}; }
}
int variantInt(const sdbus::Variant &v) {
    try { return v.get<int32_t>(); } catch (...) {
        try { return int(v.get<uint16_t>()); } catch (...) { return 0; }
    }
}
}

NetworkController::NetworkController(QObject *parent)
    : QObject(parent)
{
    m_retryTimer.setSingleShot(true);
    m_retryTimer.setInterval(3'000);
    QObject::connect(&m_retryTimer, &QTimer::timeout, this,
                     &NetworkController::connect);
    connect();
}

NetworkController::~NetworkController() {
    if (m_conn) {
        try { m_conn->leaveEventLoop(); } catch (...) {}
    }
}

void NetworkController::connect() {
    try {
        m_conn = sdbus::createSystemBusConnection();

        // Resolve (or create) the wlan0 interface object.
        auto root = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{kRoot});

        sdbus::ObjectPath ifacePath;
        try {
            root->callMethod("GetInterface").onInterface(kRootIf)
                .withArguments(std::string{"wlan0"})
                .storeResultsTo(ifacePath);
        } catch (const sdbus::Error &) {
            // Not yet registered — create.
            std::map<std::string, sdbus::Variant> args;
            args["Ifname"] = sdbus::Variant{std::string{"wlan0"}};
            root->callMethod("CreateInterface").onInterface(kRootIf)
                .withArguments(args).storeResultsTo(ifacePath);
        }
        m_ifacePath = QString::fromStdString(ifacePath);

        m_iface = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{ifacePath});

        // Watch State / CurrentBSS / BSSs / Networks via PropertiesChanged.
        m_iface->uponSignal("PropertiesChanged")
            .onInterface(kIfaceIf)
            .call([this](const std::map<std::string, sdbus::Variant> &/*changed*/) {
                QMetaObject::invokeMethod(this, [this]{
                    refreshState();
                    rebuildNetworks();
                }, Qt::QueuedConnection);
            });

        m_iface->uponSignal("BSSAdded").onInterface(kIfaceIf)
            .call([this](const sdbus::ObjectPath &/*p*/,
                         const std::map<std::string, sdbus::Variant> &/*props*/) {
                QMetaObject::invokeMethod(this, [this]{ rebuildNetworks(); }, Qt::QueuedConnection);
            });
        m_iface->uponSignal("BSSRemoved").onInterface(kIfaceIf)
            .call([this](const sdbus::ObjectPath &/*p*/) {
                QMetaObject::invokeMethod(this, [this]{ rebuildNetworks(); }, Qt::QueuedConnection);
            });
        m_iface->uponSignal("ScanDone").onInterface(kIfaceIf)
            .call([this](bool /*success*/) {
                QMetaObject::invokeMethod(this, [this]{ rebuildNetworks(); }, Qt::QueuedConnection);
            });

        m_conn->enterEventLoopAsync();

        refreshState();
        rebuildNetworks();
        scanWifi();   // kick a first scan
    } catch (const sdbus::Error &e) {
        qWarning() << "NetworkController: connect failed:"
                   << e.getName().c_str() << "—" << e.getMessage().c_str();
        m_retryTimer.start();
    }
}

void NetworkController::refreshState() {
    if (!m_iface) return;
    try {
        auto state = m_iface->getProperty("State")
                            .onInterface(kIfaceIf).get<std::string>();
        QString s = QString::fromStdString(state);
        const bool prevPowered = m_wifiPowered;
        m_wifiPowered = (s != QLatin1String("interface_disabled"));

        QString ssid;
        try {
            auto cur = m_iface->getProperty("CurrentBSS")
                              .onInterface(kIfaceIf).get<sdbus::ObjectPath>();
            if (!std::string(cur).empty() && std::string(cur) != "/") {
                auto bss = sdbus::createProxy(*m_conn,
                    sdbus::ServiceName{kService},
                    sdbus::ObjectPath{cur});
                auto bytes = bss->getProperty("SSID")
                                .onInterface(kBssIf).get<std::vector<uint8_t>>();
                ssid = ssidFromBytes(bytes);
            }
        } catch (...) { /* no current bss */ }

        if (s != m_state || ssid != m_currentSsid || m_wifiPowered != prevPowered) {
            m_state       = s;
            m_currentSsid = ssid;
            emit changed();
        }
    } catch (const sdbus::Error &e) {
        qWarning() << "NetworkController: refreshState:" << e.getMessage().c_str();
    }
}

void NetworkController::rebuildNetworks() {
    if (!m_iface) return;
    try {
        auto bsss = m_iface->getProperty("BSSs")
                          .onInterface(kIfaceIf).get<std::vector<sdbus::ObjectPath>>();

        // Build a set of saved SSIDs by walking Networks.
        QSet<QString> saved;
        try {
            auto nets = m_iface->getProperty("Networks")
                              .onInterface(kIfaceIf).get<std::vector<sdbus::ObjectPath>>();
            for (const auto &np : nets) {
                auto n = sdbus::createProxy(*m_conn,
                    sdbus::ServiceName{kService}, sdbus::ObjectPath{np});
                try {
                    auto props = n->getProperty("Properties")
                                  .onInterface(kNetworkIf)
                                  .get<std::map<std::string, sdbus::Variant>>();
                    auto it = props.find("ssid");
                    if (it != props.end()) {
                        QString s = variantStr(it->second);
                        // wpa_supplicant returns ssid wrapped in quotes
                        if (s.startsWith('"') && s.endsWith('"'))
                            s = s.mid(1, s.size() - 2);
                        saved.insert(s);
                    }
                } catch (...) {}
            }
        } catch (...) {}

        QVariantList out;
        QHash<QString, int> bestBySsid;   // dedup, keep strongest signal per SSID
        out.reserve(static_cast<int>(bsss.size()));
        for (const auto &p : bsss) {
            try {
                auto bss = sdbus::createProxy(*m_conn,
                    sdbus::ServiceName{kService}, sdbus::ObjectPath{p});
                auto ssidBytes = bss->getProperty("SSID")
                                    .onInterface(kBssIf).get<std::vector<uint8_t>>();
                if (ssidBytes.empty()) continue;
                QString ssid = ssidFromBytes(ssidBytes);
                int signalDbm = bss->getProperty("Signal")
                                   .onInterface(kBssIf).get<int16_t>();
                int freq      = int(bss->getProperty("Frequency")
                                       .onInterface(kBssIf).get<uint16_t>());

                // Detect security: WPA / RSN dicts non-empty -> secured.
                QString security = "none";
                try {
                    auto rsn = bss->getProperty("RSN")
                                  .onInterface(kBssIf)
                                  .get<std::map<std::string, sdbus::Variant>>();
                    if (!rsn.empty() && rsn.count("KeyMgmt"))
                        security = "wpa2";
                } catch (...) {}
                if (security == "none") {
                    try {
                        auto wpa = bss->getProperty("WPA")
                                      .onInterface(kBssIf)
                                      .get<std::map<std::string, sdbus::Variant>>();
                        if (!wpa.empty() && wpa.count("KeyMgmt"))
                            security = "wpa";
                    } catch (...) {}
                }

                // dBm → percent: -50 = 100%, -100 = 0%
                int strength = qBound(0, 2 * (signalDbm + 100), 100);

                auto idxIt = bestBySsid.find(ssid);
                if (idxIt != bestBySsid.end()) {
                    QVariantMap existing = out[idxIt.value()].toMap();
                    if (existing["strength"].toInt() >= strength) continue;
                    out.removeAt(idxIt.value());
                }

                QVariantMap n;
                n["ssid"]      = ssid;
                n["strength"]  = strength;
                n["frequency"] = freq;
                n["security"]  = security;
                n["saved"]     = saved.contains(ssid);
                bestBySsid[ssid] = out.size();
                out.append(n);
            } catch (...) { /* skip this BSS */ }
        }

        // Sort by signal strength desc.
        std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b){
            return a.toMap()["strength"].toInt() > b.toMap()["strength"].toInt();
        });

        m_networks = std::move(out);
        emit networksChanged();
    } catch (const sdbus::Error &e) {
        qWarning() << "NetworkController: rebuildNetworks:" << e.getMessage().c_str();
    }
}

QString NetworkController::findSavedNetworkPath(const QString &ssid) const {
    if (!m_iface) return {};
    try {
        auto nets = m_iface->getProperty("Networks")
                          .onInterface(kIfaceIf).get<std::vector<sdbus::ObjectPath>>();
        for (const auto &np : nets) {
            auto n = sdbus::createProxy(*m_conn,
                sdbus::ServiceName{kService}, sdbus::ObjectPath{np});
            try {
                auto props = n->getProperty("Properties")
                              .onInterface(kNetworkIf)
                              .get<std::map<std::string, sdbus::Variant>>();
                auto it = props.find("ssid");
                if (it != props.end()) {
                    QString s = variantStr(it->second);
                    if (s.startsWith('"') && s.endsWith('"'))
                        s = s.mid(1, s.size() - 2);
                    if (s == ssid) return QString::fromStdString(np);
                }
            } catch (...) {}
        }
    } catch (...) {}
    return {};
}

QString NetworkController::addNetwork(const QString &ssid, const QString &psk) {
    if (!m_iface) return {};
    std::map<std::string, sdbus::Variant> args;
    // wpa_supplicant expects ssid quoted, raw inside Variant string.
    args["ssid"] = sdbus::Variant{std::string{"\""} + ssid.toStdString() + "\""};
    if (psk.isEmpty()) {
        args["key_mgmt"] = sdbus::Variant{std::string{"NONE"}};
    } else {
        args["psk"]      = sdbus::Variant{std::string{"\""} + psk.toStdString() + "\""};
        args["key_mgmt"] = sdbus::Variant{std::string{"WPA-PSK"}};
    }

    sdbus::ObjectPath path;
    try {
        m_iface->callMethod("AddNetwork").onInterface(kIfaceIf)
               .withArguments(args).storeResultsTo(path);
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
        return {};
    }
    return QString::fromStdString(path);
}

void NetworkController::selectNetworkPath(const QString &path) {
    if (!m_iface || path.isEmpty()) return;
    try {
        m_iface->callMethod("SelectNetwork").onInterface(kIfaceIf)
               .withArguments(sdbus::ObjectPath{path.toStdString()})
               .dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

// ── Mutators ────────────────────────────────────────────────────────────────

void NetworkController::setWifiPowered(bool /*on*/) {
    // wpa_supplicant has no direct "power" toggle. The interface stays
    // active once registered; toggling it cleanly would mean removing the
    // interface object, which also drops scan results. We treat the flag
    // as read-only for now and surface true while the iface object exists.
    // TODO: rfkill block/unblock for a real off-switch.
}

void NetworkController::scanWifi() {
    if (!m_iface) return;
    std::map<std::string, sdbus::Variant> args;
    args["Type"] = sdbus::Variant{std::string{"active"}};
    try {
        m_iface->callMethod("Scan").onInterface(kIfaceIf)
               .withArguments(args).dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void NetworkController::connectOpen(const QString &ssid) {
    QString path = findSavedNetworkPath(ssid);
    if (path.isEmpty()) path = addNetwork(ssid, {});
    selectNetworkPath(path);
}

void NetworkController::connectWithPassphrase(const QString &ssid, const QString &psk) {
    // If we already saved this SSID, drop it so the new PSK takes effect.
    QString existing = findSavedNetworkPath(ssid);
    if (!existing.isEmpty()) {
        try {
            m_iface->callMethod("RemoveNetwork").onInterface(kIfaceIf)
                   .withArguments(sdbus::ObjectPath{existing.toStdString()})
                   .dontExpectReply();
        } catch (...) {}
    }
    QString path = addNetwork(ssid, psk);
    selectNetworkPath(path);
}

void NetworkController::disconnectCurrent() {
    if (!m_iface) return;
    try {
        m_iface->callMethod("Disconnect").onInterface(kIfaceIf).dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void NetworkController::forgetSsid(const QString &ssid) {
    QString path = findSavedNetworkPath(ssid);
    if (path.isEmpty() || !m_iface) return;
    try {
        m_iface->callMethod("RemoveNetwork").onInterface(kIfaceIf)
               .withArguments(sdbus::ObjectPath{path.toStdString()})
               .dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}
