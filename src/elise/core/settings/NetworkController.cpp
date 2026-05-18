#include "NetworkController.h"

#include <sdbus-c++/sdbus-c++.h>

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QVariantMap>

#include <cstring>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

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

// wpa_supplicant returns the saved-network `ssid` property in whatever
// type it was stored as: byte array (`ay`) if we added it that way, or
// a quoted string (`"foo"`) for legacy entries. Normalize both.
QString ssidFromVariant(const sdbus::Variant &v) {
    try {
        auto bytes = v.get<std::vector<uint8_t>>();
        return ssidFromBytes(bytes);
    } catch (...) {}
    try {
        QString s = QString::fromStdString(v.get<std::string>());
        if (s.startsWith('"') && s.endsWith('"'))
            s = s.mid(1, s.size() - 2);
        return s;
    } catch (...) {}
    return {};
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

// Locate the rfkill switch for the wireless radio under /sys/class/rfkill.
// Returns the sysfs directory (e.g. /sys/class/rfkill/rfkill1) whose
// `type` reads "wlan", or an empty QString if absent.
QString findWlanRfkill() {
    QDir base("/sys/class/rfkill");
    const QStringList entries = base.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const auto &e : entries) {
        const QString dir = base.filePath(e);
        QFile typeFile(dir + "/type");
        if (!typeFile.open(QIODevice::ReadOnly)) continue;
        const QByteArray type = typeFile.readAll().trimmed();
        if (type == "wlan") return dir;
    }
    return {};
}

bool readRfkillSoft(const QString &dir) {
    QFile f(dir + "/soft");
    if (!f.open(QIODevice::ReadOnly)) return true;   // assume blocked if unreadable
    return f.readAll().trimmed() == "0";             // soft=0 = unblocked = powered
}

bool writeRfkillSoft(const QString &dir, bool unblocked) {
    QFile f(dir + "/soft");
    if (!f.open(QIODevice::WriteOnly)) return false;
    return f.write(unblocked ? "0\n" : "1\n") > 0;
}

// Bring/take down wlan0 via SIOCGIFFLAGS+SIOCSIFFLAGS. Unblocking rfkill
// alone does not raise IFF_UP — kernel leaves the link in the state it was
// before the rfkill block. wpa_supplicant then reports State = "interface
// _disabled" until the link is up.
bool setIfaceUp(const char *name, bool up) {
    int sock = ::socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) return false;
    struct ifreq ifr{};
    std::strncpy(ifr.ifr_name, name, IFNAMSIZ - 1);
    if (::ioctl(sock, SIOCGIFFLAGS, &ifr) < 0) { ::close(sock); return false; }
    if (up) ifr.ifr_flags |=  IFF_UP;
    else    ifr.ifr_flags &= ~IFF_UP;
    const bool ok = ::ioctl(sock, SIOCSIFFLAGS, &ifr) == 0;
    ::close(sock);
    return ok;
}
}

NetworkController::NetworkController(QObject *parent)
    : QObject(parent)
{
    m_retryTimer.setSingleShot(true);
    m_retryTimer.setInterval(3'000);
    QObject::connect(&m_retryTimer, &QTimer::timeout, this,
                     &NetworkController::connect);

    // Seed wifiPowered from rfkill so the toggle reflects the radio state
    // even before wpa_supplicant tells us anything.
    const QString rk = findWlanRfkill();
    if (!rk.isEmpty()) m_wifiPowered = readRfkillSoft(rk);

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

        // Clear connecting marker once we either finish, fail, or are clearly idle.
        if (!m_connectingSsid.isEmpty()) {
            if (s == QLatin1String("completed")) {
                m_connectingSsid.clear();
                m_lastError.clear();
                // Persist the just-connected network to /etc/wpa_supplicant/
                // so the SSID + psk survive reboots. Requires update_config=1
                // in the config file (set by our overlay) and a writable
                // location for the file.
                try {
                    m_iface->callMethod("SaveConfig").onInterface(kIfaceIf)
                           .dontExpectReply();
                } catch (...) {}
            } else if (s == QLatin1String("disconnected") ||
                       s == QLatin1String("inactive") ||
                       s == QLatin1String("interface_disabled")) {
                // 4-way handshake failure = wrong PSK. Auto-forget the
                // saved entry so the next tap re-prompts the user.
                const bool wrongKey =
                    m_state == QLatin1String("4way_handshake") ||
                    m_state == QLatin1String("group_handshake");
                if (wrongKey) {
                    m_lastError = QStringLiteral("Senha incorreta em %1").arg(m_connectingSsid);
                    const QString badSsid = m_connectingSsid;
                    m_connectingSsid.clear();
                    QMetaObject::invokeMethod(this, [this, badSsid]{
                        forgetSsid(badSsid);
                    }, Qt::QueuedConnection);
                } else {
                    m_lastError = QStringLiteral("Falha ao conectar em %1").arg(m_connectingSsid);
                    m_connectingSsid.clear();
                }
            }
        }
        if (s != m_state || ssid != m_currentSsid || m_wifiPowered != prevPowered) {
            m_state       = s;
            m_currentSsid = ssid;
            emit changed();
        } else {
            emit changed();   // connectingSsid may have changed
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
                        QString s = ssidFromVariant(it->second);
                        if (!s.isEmpty()) saved.insert(s);
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
                    if (ssidFromVariant(it->second) == ssid)
                        return QString::fromStdString(np);
                }
            } catch (...) {}
        }
    } catch (...) {}
    return {};
}

QString NetworkController::addNetwork(const QString &ssid, const QString &psk) {
    if (!m_iface) return {};
    std::map<std::string, sdbus::Variant> args;
    // Pass SSID as a byte array (`ay`). If we pass it as a string variant
    // wpa_supplicant re-quotes it on store, ending up with `""SSID""` and
    // no matching AP. The byte-array form is stored verbatim.
    const QByteArray ssidUtf8 = ssid.toUtf8();
    std::vector<uint8_t> ssidBytes(ssidUtf8.begin(), ssidUtf8.end());
    args["ssid"] = sdbus::Variant{ssidBytes};
    if (psk.isEmpty()) {
        args["key_mgmt"] = sdbus::Variant{std::string{"NONE"}};
    } else {
        // psk is passed UNQUOTED via D-Bus. Quotes around the passphrase
        // are only the wpa_supplicant.conf-file syntax. wpa_supplicant's
        // D-Bus AddNetwork treats <=63-char value as passphrase, exactly
        // 64-hex as raw PSK. Quoting it yields a wrong passphrase that
        // fails the 4-way handshake.
        args["psk"]      = sdbus::Variant{psk.toStdString()};
        args["key_mgmt"] = sdbus::Variant{std::string{"WPA-PSK"}};
        args["ieee80211w"] = sdbus::Variant{uint32_t{0}};   // PMF off
        // Narrow profile validated against mixed WPA/WPA2 APs with TKIP
        // group cipher. brcmfmac on Pi 5 fails some 5 GHz channels at
        // scan time (cfg80211 BR regdom) which corrupts driver state
        // mid-attempt; restrict to 2.4 GHz so scan + assoc stay clean.
        args["proto"]      = sdbus::Variant{std::string{"RSN"}};
        args["pairwise"]   = sdbus::Variant{std::string{"CCMP"}};
        args["group"]      = sdbus::Variant{std::string{"CCMP TKIP"}};
        args["freq_list"]  = sdbus::Variant{std::string{
            "2412 2417 2422 2427 2432 2437 2442 2447 2452 2457 2462"}};
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

void NetworkController::setWifiPowered(bool on) {
    const QString rk = findWlanRfkill();
    if (rk.isEmpty()) {
        emit errorOccurred(QStringLiteral("rfkill: no wlan switch found"));
        return;
    }
    if (!writeRfkillSoft(rk, on)) {
        emit errorOccurred(QStringLiteral("rfkill: write failed (run as root)"));
        return;
    }

    // Unblocking rfkill leaves wlan0 in the link-down state it was forced
    // into; bring it back up so wpa_supplicant can leave "interface_disabled".
    // On power-off we drop the link first, then block rfkill.
    if (on) {
        setIfaceUp("wlan0", true);
    } else {
        setIfaceUp("wlan0", false);
    }

    m_wifiPowered = on;
    emit changed();
    if (on) {
        // Give the radio a moment to come up before kicking a scan.
        QTimer::singleShot(800, this, &NetworkController::scanWifi);
    }
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
    if (!m_iface) return;
    m_connectingSsid = ssid;
    m_lastError.clear();
    emit changed();
    // Reuse a previously saved entry for this SSID when present — avoids
    // accumulating duplicates and lets wpa_supplicant pick a faster path.
    QString path = findSavedNetworkPath(ssid);
    if (path.isEmpty()) path = addNetwork(ssid, {});
    selectNetworkPath(path);
}

void NetworkController::connectWithPassphrase(const QString &ssid, const QString &psk) {
    if (!m_iface) return;
    m_connectingSsid = ssid;
    m_lastError.clear();
    emit changed();
    // User just typed a (possibly new) password — replace any prior entry
    // for this SSID so the fresh psk wins, then SelectNetwork.
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

void NetworkController::reconnectSaved(const QString &ssid) {
    if (!m_iface) return;
    QString path = findSavedNetworkPath(ssid);
    if (path.isEmpty()) {
        emit errorOccurred(QStringLiteral("Rede %1 não está salva").arg(ssid));
        return;
    }
    m_connectingSsid = ssid;
    m_lastError.clear();
    emit changed();
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
