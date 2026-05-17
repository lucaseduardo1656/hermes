#include "BluetoothController.h"

#include <sdbus-c++/sdbus-c++.h>

#include <QDebug>
#include <QMetaObject>
#include <QVariantMap>

#include <map>
#include <string>
#include <vector>

namespace {
constexpr const char *kService      = "org.bluez";
constexpr const char *kRoot         = "/";
constexpr const char *kBluezPath    = "/org/bluez";
constexpr const char *kAdapterPath  = "/org/bluez/hci0";
constexpr const char *kAdapterIf    = "org.bluez.Adapter1";
constexpr const char *kDeviceIf     = "org.bluez.Device1";
constexpr const char *kAgentMgrIf   = "org.bluez.AgentManager1";
constexpr const char *kAgentIf      = "org.bluez.Agent1";
constexpr const char *kPropsIf      = "org.freedesktop.DBus.Properties";
constexpr const char *kObjMgrIf     = "org.freedesktop.DBus.ObjectManager";
constexpr const char *kAgentObject  = "/com/hermes/btagent";
constexpr const char *kAgentCaps    = "NoInputNoOutput";

// Pull a typed value out of a Variant without throwing across boundaries.
QString variantStr(const sdbus::Variant &v) {
    try { return QString::fromStdString(v.get<std::string>()); } catch (...) { return {}; }
}
bool variantBool(const sdbus::Variant &v) {
    try { return v.get<bool>(); } catch (...) { return false; }
}
int variantInt16(const sdbus::Variant &v) {
    try { return int(v.get<int16_t>()); } catch (...) { return 0; }
}

QString addressFromPath(const QString &path) {
    // /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF  →  AA:BB:CC:DD:EE:FF
    const int idx = path.lastIndexOf("/dev_");
    if (idx < 0) return {};
    QString rest = path.mid(idx + 5);
    return rest.replace('_', ':');
}

bool isDevicePath(const std::string &p) {
    return p.rfind("/org/bluez/hci0/dev_", 0) == 0;
}
}

BluetoothController::BluetoothController(QObject *parent)
    : QObject(parent)
{
    m_retryTimer.setSingleShot(true);
    m_retryTimer.setInterval(3'000);
    QObject::connect(&m_retryTimer, &QTimer::timeout, this,
                     &BluetoothController::connect);
    connect();
}

BluetoothController::~BluetoothController() {
    if (m_conn) {
        try { m_conn->leaveEventLoop(); } catch (...) {}
    }
}

void BluetoothController::connect() {
    try {
        m_conn = sdbus::createSystemBusConnection();

        m_root = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{kRoot});

        m_adapter = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{kAdapterPath});

        // ObjectManager fires these as devices appear (scan results) /
        // disappear (forget). Drives rebuildDevices.
        m_root->uponSignal("InterfacesAdded").onInterface(kObjMgrIf)
            .call([this](const sdbus::ObjectPath &p,
                         const std::map<std::string,
                              std::map<std::string, sdbus::Variant>> &/*ifaces*/) {
                const QString path = QString::fromStdString(p);
                QMetaObject::invokeMethod(this, [this, path]{
                    onInterfacesAdded(path);
                }, Qt::QueuedConnection);
            });
        m_root->uponSignal("InterfacesRemoved").onInterface(kObjMgrIf)
            .call([this](const sdbus::ObjectPath &p,
                         const std::vector<std::string> &/*ifaces*/) {
                const QString path = QString::fromStdString(p);
                QMetaObject::invokeMethod(this, [this, path]{
                    onInterfacesRemoved(path);
                }, Qt::QueuedConnection);
            });

        // Adapter PropertiesChanged covers Powered / Discovering toggles.
        m_adapter->uponSignal("PropertiesChanged").onInterface(kPropsIf)
            .call([this](const std::string &/*iface*/,
                         const std::map<std::string, sdbus::Variant> &/*changed*/,
                         const std::vector<std::string> &/*invalidated*/) {
                QMetaObject::invokeMethod(this, [this]{
                    refreshAdapterState();
                }, Qt::QueuedConnection);
            });

        m_conn->enterEventLoopAsync();

        registerAgent();
        refreshAdapterState();
        rebuildDevices();
    } catch (const sdbus::Error &e) {
        qWarning() << "BluetoothController: connect failed:"
                   << e.getName().c_str() << "—" << e.getMessage().c_str();
        m_retryTimer.start();
    }
}

void BluetoothController::registerAgent() {
    // Expose org.bluez.Agent1 at /com/hermes/btagent with NoInputNoOutput
    // capability. With no IO, bluetoothd handles passkeys internally for
    // speakers/headphones (just-works). The callbacks we still get
    // (RequestAuthorization, AuthorizeService) we approve unconditionally
    // — the user explicitly tapped "Conectar", which is the consent.
    try {
        m_agent = sdbus::createObject(*m_conn,
            sdbus::ObjectPath{kAgentObject});

        sdbus::InterfaceName agentIf{kAgentIf};
        m_agent->addVTable(
            sdbus::registerMethod("Release").implementedAs([](){}),
            sdbus::registerMethod("Cancel").implementedAs([](){}),
            sdbus::registerMethod("RequestAuthorization")
                .implementedAs([](const sdbus::ObjectPath &){ /* auto-approve */ }),
            sdbus::registerMethod("AuthorizeService")
                .implementedAs([](const sdbus::ObjectPath &,
                                  const std::string &){ /* auto-approve */ })
        ).forInterface(agentIf);

        // Register with bluetoothd.
        auto mgr = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{kBluezPath});
        try {
            mgr->callMethod("RegisterAgent").onInterface(kAgentMgrIf)
               .withArguments(sdbus::ObjectPath{kAgentObject},
                              std::string{kAgentCaps})
               .dontExpectReply();
        } catch (const sdbus::Error &e) {
            // AlreadyExists is fine — we keep the same object name.
            if (std::string(e.getName()).find("AlreadyExists") == std::string::npos)
                qWarning() << "BluetoothController: RegisterAgent:" << e.getMessage().c_str();
        }
        try {
            mgr->callMethod("RequestDefaultAgent").onInterface(kAgentMgrIf)
               .withArguments(sdbus::ObjectPath{kAgentObject})
               .dontExpectReply();
        } catch (...) {}
    } catch (const sdbus::Error &e) {
        qWarning() << "BluetoothController: agent setup:" << e.getMessage().c_str();
    }
}

void BluetoothController::refreshAdapterState() {
    if (!m_adapter) return;
    try {
        const bool powered = m_adapter->getProperty("Powered")
                                .onInterface(kAdapterIf).get<bool>();
        const bool discovering = m_adapter->getProperty("Discovering")
                                    .onInterface(kAdapterIf).get<bool>();
        const bool discoverable = m_adapter->getProperty("Discoverable")
                                    .onInterface(kAdapterIf).get<bool>();
        QString alias;
        try {
            alias = QString::fromStdString(
                m_adapter->getProperty("Alias").onInterface(kAdapterIf)
                         .get<std::string>());
        } catch (...) {}

        bool changed = (powered != m_powered)
                    || (discovering != m_discovering)
                    || (discoverable != m_discoverable)
                    || (alias != m_adapterAlias);
        const bool wasPowered = m_powered;
        m_powered = powered;
        m_discovering = discovering;
        m_discoverable = discoverable;
        m_adapterAlias = alias;

        // On adapter coming up for the first time this session, kick a
        // best-effort reconnect to every trusted device. The bus call is
        // non-blocking — devices we can't reach will just timeout in
        // bluetoothd and stay disconnected, no UI impact.
        if (powered && !wasPowered && !m_autoReconnected) {
            m_autoReconnected = true;
            QMetaObject::invokeMethod(this, [this]{ autoReconnectTrusted(); },
                                      Qt::QueuedConnection);
        }
        if (changed) emit this->changed();
    } catch (const sdbus::Error &e) {
        qWarning() << "BluetoothController: refreshAdapterState:" << e.getMessage().c_str();
    }
}

void BluetoothController::onInterfacesAdded(const QString &path) {
    if (path.startsWith("/org/bluez/hci0/dev_"))
        rebuildDevices();
}

void BluetoothController::onInterfacesRemoved(const QString &path) {
    if (path.startsWith("/org/bluez/hci0/dev_")) {
        m_devProxies.remove(path);
        rebuildDevices();
    }
}

void BluetoothController::onDevicePropertiesChanged(const QString &/*path*/) {
    rebuildDevices();
}

void BluetoothController::rebuildDevices() {
    if (!m_root) return;
    try {
        // GetManagedObjects → walk for org.bluez.Device1 entries.
        std::map<sdbus::ObjectPath,
                 std::map<std::string,
                          std::map<std::string, sdbus::Variant>>> objects;
        m_root->callMethod("GetManagedObjects").onInterface(kObjMgrIf)
              .storeResultsTo(objects);

        QVariantList out;
        QString prevConnected = m_connectedAlias;
        QString newConnected;

        for (const auto &[opath, ifaces] : objects) {
            const std::string p = opath;
            if (!isDevicePath(p)) continue;
            auto it = ifaces.find(kDeviceIf);
            if (it == ifaces.end()) continue;
            const auto &props = it->second;

            auto pget = [&](const char *k) -> sdbus::Variant {
                auto f = props.find(k);
                return f == props.end() ? sdbus::Variant{} : f->second;
            };

            const QString qpath = QString::fromStdString(p);
            const QString addr  = variantStr(pget("Address"));
            const QString alias = variantStr(pget("Alias"));
            const bool paired   = variantBool(pget("Paired"));
            const bool trusted  = variantBool(pget("Trusted"));
            const bool connected= variantBool(pget("Connected"));
            const int  rssi     = variantInt16(pget("RSSI"));
            const QString icon  = variantStr(pget("Icon"));

            QVariantMap d;
            d["path"]      = qpath;
            d["address"]   = addr;
            d["alias"]     = alias.isEmpty() ? addr : alias;
            d["paired"]    = paired;
            d["trusted"]   = trusted;
            d["connected"] = connected;
            d["rssi"]      = rssi;
            d["icon"]      = icon;
            out.append(d);

            if (connected && newConnected.isEmpty())
                newConnected = d["alias"].toString();

            // Watch device PropertiesChanged so Connecting → Connected
            // transitions surface without a fresh GetManagedObjects.
            if (!m_devProxies.contains(qpath)) {
                auto proxy = std::shared_ptr<sdbus::IProxy>(sdbus::createProxy(
                    *m_conn,
                    sdbus::ServiceName{kService},
                    sdbus::ObjectPath{p}).release());
                proxy->uponSignal("PropertiesChanged").onInterface(kPropsIf)
                    .call([this, qpath](const std::string &,
                                        const std::map<std::string, sdbus::Variant> &,
                                        const std::vector<std::string> &) {
                        QMetaObject::invokeMethod(this, [this, qpath]{
                            onDevicePropertiesChanged(qpath);
                        }, Qt::QueuedConnection);
                    });
                m_devProxies.insert(qpath, std::move(proxy));
            }

            // Stop showing connectingAddr once the operation resolves.
            if (!m_connectingAddr.isEmpty() && addr == m_connectingAddr) {
                if (connected) {
                    m_connectingAddr.clear();
                    m_lastError.clear();
                }
            }
        }

        // Sort: connected first, then paired, then by RSSI desc.
        std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b) {
            QVariantMap ma = a.toMap(), mb = b.toMap();
            int ka = ma["connected"].toBool() ? 2 : (ma["paired"].toBool() ? 1 : 0);
            int kb = mb["connected"].toBool() ? 2 : (mb["paired"].toBool() ? 1 : 0);
            if (ka != kb) return ka > kb;
            return ma["rssi"].toInt() > mb["rssi"].toInt();
        });

        m_devices = std::move(out);
        emit devicesChanged();
        if (newConnected != prevConnected) {
            m_connectedAlias = newConnected;
            emit changed();
        } else if (!m_connectingAddr.isEmpty()) {
            emit changed();
        }
    } catch (const sdbus::Error &e) {
        qWarning() << "BluetoothController: rebuildDevices:" << e.getMessage().c_str();
    }
}

QString BluetoothController::devicePathFor(const QString &address) const {
    // Cheap: format same path bluez uses, then verify in the cache.
    QString suffix = address;
    suffix.replace(':', '_');
    const QString candidate =
        QStringLiteral("/org/bluez/hci0/dev_") + suffix;
    return candidate;
}

void BluetoothController::autoReconnectTrusted() {
    // Pick every device flagged Trusted and call Connect. Bluetoothd
    // serializes attempts; failed ones don't block the next.
    for (const QVariant &v : std::as_const(m_devices)) {
        QVariantMap m = v.toMap();
        if (!m.value("trusted").toBool()) continue;
        if (m.value("connected").toBool()) continue;
        connectDevice(m.value("address").toString());
    }
}

// ── Mutators ────────────────────────────────────────────────────────────

void BluetoothController::setPowered(bool on) {
    if (!m_adapter) return;
    try {
        m_adapter->setProperty("Powered").onInterface(kAdapterIf)
                 .toValue(on);
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void BluetoothController::setDiscoverable(bool on) {
    if (!m_adapter) return;
    try {
        // Persistent visibility — DiscoverableTimeout=0 keeps the
        // adapter discoverable until explicitly turned off. The car
        // is a stationary endpoint; leaving it visible while parked is
        // the expected UX for "pair my phone".
        m_adapter->setProperty("DiscoverableTimeout").onInterface(kAdapterIf)
                 .toValue(uint32_t{0});
        m_adapter->setProperty("Discoverable").onInterface(kAdapterIf)
                 .toValue(on);
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void BluetoothController::setAdapterAlias(const QString &alias) {
    if (!m_adapter || alias.isEmpty()) return;
    try {
        m_adapter->setProperty("Alias").onInterface(kAdapterIf)
                 .toValue(alias.toStdString());
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void BluetoothController::startScan() {
    if (!m_adapter) return;
    try {
        // BR/EDR + LE, no UUID filter — we want speakers (A2DP) plus
        // anything else the user might want to pair.
        std::map<std::string, sdbus::Variant> filt;
        filt["Transport"] = sdbus::Variant{std::string{"auto"}};
        m_adapter->callMethod("SetDiscoveryFilter").onInterface(kAdapterIf)
                 .withArguments(filt).dontExpectReply();
        m_adapter->callMethod("StartDiscovery").onInterface(kAdapterIf)
                 .dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void BluetoothController::stopScan() {
    if (!m_adapter) return;
    try {
        m_adapter->callMethod("StopDiscovery").onInterface(kAdapterIf)
                 .dontExpectReply();
    } catch (...) { /* not discovering is fine */ }
}

void BluetoothController::pair(const QString &address) {
    if (!m_conn) return;
    QString path = devicePathFor(address);
    m_connectingAddr = address;
    m_lastError.clear();
    emit changed();
    try {
        auto dev = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{path.toStdString()});
        // Pair is async on bluetoothd's side; we don't block. Once it
        // succeeds, PropertiesChanged(Paired=true, Connected=true) will
        // fire and we surface that via rebuildDevices.
        dev->callMethodAsync("Pair").onInterface(kDeviceIf)
           .uponReplyInvoke([this, address](std::optional<sdbus::Error> err) {
               QMetaObject::invokeMethod(this, [this, address, err]{
                   if (err) {
                       m_lastError = QStringLiteral("Falha ao parear %1: %2")
                                       .arg(address)
                                       .arg(QString::fromStdString(err->getMessage()));
                       m_connectingAddr.clear();
                       emit changed();
                       return;
                   }
                   // Mark trusted so future boots auto-reconnect, then
                   // kick a connect for the actual audio link.
                   QString path = devicePathFor(address);
                   try {
                       auto d = sdbus::createProxy(*m_conn,
                           sdbus::ServiceName{kService},
                           sdbus::ObjectPath{path.toStdString()});
                       d->setProperty("Trusted").onInterface(kDeviceIf)
                          .toValue(true);
                   } catch (...) {}
                   connectDevice(address);
               }, Qt::QueuedConnection);
           });
    } catch (const sdbus::Error &e) {
        m_lastError = QString::fromStdString(e.getMessage());
        m_connectingAddr.clear();
        emit changed();
    }
}

void BluetoothController::connectDevice(const QString &address) {
    if (!m_conn) return;
    QString path = devicePathFor(address);
    m_connectingAddr = address;
    m_lastError.clear();
    emit changed();
    try {
        auto dev = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{path.toStdString()});
        dev->callMethodAsync("Connect").onInterface(kDeviceIf)
           .uponReplyInvoke([this, address](std::optional<sdbus::Error> err) {
               if (!err) return;
               QString msg = QString::fromStdString(err->getMessage());
               QMetaObject::invokeMethod(this, [this, address, msg]{
                   m_lastError = QStringLiteral("Falha ao conectar %1: %2")
                                   .arg(address).arg(msg);
                   m_connectingAddr.clear();
                   emit changed();
               }, Qt::QueuedConnection);
           });
    } catch (const sdbus::Error &e) {
        m_lastError = QString::fromStdString(e.getMessage());
        m_connectingAddr.clear();
        emit changed();
    }
}

void BluetoothController::disconnectDevice(const QString &address) {
    if (!m_conn) return;
    QString path = devicePathFor(address);
    try {
        auto dev = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{path.toStdString()});
        dev->callMethod("Disconnect").onInterface(kDeviceIf).dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void BluetoothController::forget(const QString &address) {
    if (!m_adapter) return;
    QString path = devicePathFor(address);
    try {
        m_adapter->callMethod("RemoveDevice").onInterface(kAdapterIf)
                 .withArguments(sdbus::ObjectPath{path.toStdString()})
                 .dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}
