#include "NetworkController.h"

#include <sdbus-c++/sdbus-c++.h>

#include <QDebug>
#include <QMetaObject>
#include <QVariantMap>

namespace {
constexpr const char *kService    = "net.connman";
constexpr const char *kManagerIf  = "net.connman.Manager";
constexpr const char *kTechIf     = "net.connman.Technology";
constexpr const char *kServiceIf  = "net.connman.Service";
constexpr const char *kRoot       = "/";

// ConnMan returns sd-bus dict<string,variant> as
// `std::map<std::string, sdbus::Variant>` in sdbus-c++ 2.x. Helpers below
// strip the boilerplate of pulling typed values out.
QString variantStr(const sdbus::Variant &v) {
    try { return QString::fromStdString(v.get<std::string>()); } catch (...) { return {}; }
}
bool variantBool(const sdbus::Variant &v) {
    try { return v.get<bool>(); } catch (...) { return false; }
}
quint8 variantU8(const sdbus::Variant &v) {
    try { return v.get<uint8_t>(); } catch (...) { return 0; }
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
        m_managerProxy = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{kRoot});

        m_managerProxy->uponSignal("PropertyChanged")
            .onInterface(kManagerIf)
            .call([this](const std::string &name, const sdbus::Variant &value) {
                if (name != "State") return;
                QString s = QString::fromStdString(value.get<std::string>());
                QMetaObject::invokeMethod(this, [this, s]{
                    if (m_state == s) return;
                    m_state = s;
                    emit changed();
                }, Qt::QueuedConnection);
            });

        m_managerProxy->uponSignal("ServicesChanged")
            .onInterface(kManagerIf)
            .call([this](const std::vector<sdbus::Struct<sdbus::ObjectPath,
                                            std::map<std::string, sdbus::Variant>>> &/*changed*/,
                         const std::vector<sdbus::ObjectPath> &/*removed*/) {
                QMetaObject::invokeMethod(this, [this]{
                    refreshServices();
                }, Qt::QueuedConnection);
            });

        m_managerProxy->uponSignal("TechnologyAdded")
            .onInterface(kManagerIf)
            .call([this](const sdbus::ObjectPath &/*p*/,
                         const std::map<std::string, sdbus::Variant> &/*props*/) {
                QMetaObject::invokeMethod(this, [this]{
                    refreshTechnologies();
                }, Qt::QueuedConnection);
            });

        m_managerProxy->uponSignal("TechnologyRemoved")
            .onInterface(kManagerIf)
            .call([this](const sdbus::ObjectPath &/*p*/) {
                QMetaObject::invokeMethod(this, [this]{
                    refreshTechnologies();
                }, Qt::QueuedConnection);
            });

        m_conn->enterEventLoopAsync();

        refreshAll();
    } catch (const sdbus::Error &e) {
        qWarning() << "NetworkController: connect failed:"
                   << e.getName().c_str() << "—" << e.getMessage().c_str();
        m_retryTimer.start();
    }
}

void NetworkController::refreshAll() {
    refreshManagerProps();
    refreshTechnologies();
    refreshServices();
}

void NetworkController::refreshManagerProps() {
    if (!m_managerProxy) return;
    try {
        std::map<std::string, sdbus::Variant> props;
        m_managerProxy->callMethod("GetProperties")
            .onInterface(kManagerIf).storeResultsTo(props);
        if (auto it = props.find("State"); it != props.end()) {
            QString s = variantStr(it->second);
            if (s != m_state) { m_state = s; emit changed(); }
        }
    } catch (const sdbus::Error &e) {
        qWarning() << "NetworkController: GetProperties failed:" << e.getMessage().c_str();
    }
}

void NetworkController::refreshTechnologies() {
    if (!m_managerProxy) return;
    try {
        using TechEntry = sdbus::Struct<sdbus::ObjectPath,
                                        std::map<std::string, sdbus::Variant>>;
        std::vector<TechEntry> techs;
        m_managerProxy->callMethod("GetTechnologies")
            .onInterface(kManagerIf).storeResultsTo(techs);

        QString wifiPath, btPath;
        bool wifiPowered = false, wifiConnected = false, btPowered = false;
        for (const auto &t : techs) {
            const auto &path  = t.get<0>();
            const auto &props = t.get<1>();
            QString type;
            if (auto it = props.find("Type"); it != props.end())
                type = variantStr(it->second);
            const bool powered = props.count("Powered") ? variantBool(props.at("Powered")) : false;
            const bool connected = props.count("Connected") ? variantBool(props.at("Connected")) : false;
            if (type == QLatin1String("wifi")) {
                wifiPath = QString::fromStdString(path);
                wifiPowered = powered;
                wifiConnected = connected;
            } else if (type == QLatin1String("bluetooth")) {
                btPath = QString::fromStdString(path);
                btPowered = powered;
            }
        }

        bool dirty = (wifiPath != m_wifiTechPath) || (btPath != m_btTechPath)
                  || (wifiPowered != m_wifiPowered) || (wifiConnected != m_wifiConnected)
                  || (btPowered != m_btPowered);
        m_wifiTechPath  = wifiPath;
        m_btTechPath    = btPath;
        m_wifiPowered   = wifiPowered;
        m_wifiConnected = wifiConnected;
        m_btPowered     = btPowered;
        if (dirty) emit changed();
    } catch (const sdbus::Error &e) {
        qWarning() << "NetworkController: GetTechnologies failed:" << e.getMessage().c_str();
    }
}

void NetworkController::refreshServices() {
    if (!m_managerProxy) return;
    try {
        using SvcEntry = sdbus::Struct<sdbus::ObjectPath,
                                       std::map<std::string, sdbus::Variant>>;
        std::vector<SvcEntry> svcs;
        m_managerProxy->callMethod("GetServices")
            .onInterface(kManagerIf).storeResultsTo(svcs);

        QVariantList out;
        out.reserve(static_cast<int>(svcs.size()));
        for (const auto &s : svcs) {
            const auto &path  = s.get<0>();
            const auto &props = s.get<1>();
            QString type;
            if (auto it = props.find("Type"); it != props.end())
                type = variantStr(it->second);
            if (type != QLatin1String("wifi")) continue;

            QVariantMap n;
            n["path"]     = QString::fromStdString(path);
            n["name"]     = props.count("Name")     ? variantStr(props.at("Name"))     : QStringLiteral("(oculta)");
            n["state"]    = props.count("State")    ? variantStr(props.at("State"))    : QString();
            n["strength"] = props.count("Strength") ? int(variantU8(props.at("Strength"))) : 0;
            n["favorite"] = props.count("Favorite") ? variantBool(props.at("Favorite")) : false;

            QString security;
            if (auto it = props.find("Security"); it != props.end()) {
                try {
                    auto v = it->second.get<std::vector<std::string>>();
                    if (!v.empty()) security = QString::fromStdString(v.front());
                } catch (...) {}
            }
            n["security"] = security.isEmpty() ? QStringLiteral("none") : security;
            out.push_back(n);
        }
        m_networks = std::move(out);
        emit networksChanged();
    } catch (const sdbus::Error &e) {
        qWarning() << "NetworkController: GetServices failed:" << e.getMessage().c_str();
    }
}

void NetworkController::setTechnologyPowered(const char *type, bool on) {
    if (!m_conn) return;
    QString path = (QString::fromLatin1("wifi") == QString::fromLatin1(type))
                     ? m_wifiTechPath : m_btTechPath;
    if (path.isEmpty()) {
        emit errorOccurred(QStringLiteral("technology not present: ") + QString::fromLatin1(type));
        return;
    }
    try {
        auto p = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{path.toStdString()});
        p->callMethod("SetProperty").onInterface(kTechIf)
            .withArguments(std::string{"Powered"}, sdbus::Variant{on});
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void NetworkController::setWifiPowered(bool on)      { setTechnologyPowered("wifi", on); }
void NetworkController::setBluetoothPowered(bool on) { setTechnologyPowered("bluetooth", on); }

void NetworkController::scanWifi() {
    if (m_wifiTechPath.isEmpty() || !m_conn) return;
    try {
        auto p = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{m_wifiTechPath.toStdString()});
        p->callMethod("Scan").onInterface(kTechIf).dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void NetworkController::connectService(const QString &path) {
    if (!m_conn) return;
    try {
        auto p = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{path.toStdString()});
        p->callMethod("Connect").onInterface(kServiceIf).dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void NetworkController::disconnectService(const QString &path) {
    if (!m_conn) return;
    try {
        auto p = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{path.toStdString()});
        p->callMethod("Disconnect").onInterface(kServiceIf).dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void NetworkController::forgetService(const QString &path) {
    if (!m_conn) return;
    try {
        auto p = sdbus::createProxy(*m_conn,
            sdbus::ServiceName{kService},
            sdbus::ObjectPath{path.toStdString()});
        p->callMethod("Remove").onInterface(kServiceIf).dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}
