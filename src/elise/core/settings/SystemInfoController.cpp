#include "SystemInfoController.h"

#include <sdbus-c++/sdbus-c++.h>

#include <QDebug>
#include <QMetaObject>

namespace {
constexpr const char *kService = "org.hermes.System1";
constexpr const char *kPath    = "/org/hermes/System1";
constexpr const char *kIface   = "org.hermes.System1";
}

SystemInfoController::SystemInfoController(QObject *parent)
    : QObject(parent)
{
    // Periodic refresh keeps uptime + storage live without a dedicated
    // signal subscription. Properties expected to change rarely (hostname)
    // come through D-Bus signals and skip the timer.
    m_pollTimer.setInterval(5'000);
    QObject::connect(&m_pollTimer, &QTimer::timeout, this,
                     &SystemInfoController::refresh);

    connect();
}

SystemInfoController::~SystemInfoController() {
    if (m_conn) {
        try { m_conn->leaveEventLoop(); } catch (...) {}
    }
}

void SystemInfoController::connect() {
    try {
        m_conn  = sdbus::createSystemBusConnection();
        m_proxy = sdbus::createProxy(*m_conn,
                    sdbus::ServiceName{kService},
                    sdbus::ObjectPath{kPath});

        // Subscribe to the typed signal; the generated proxy isn't used here
        // because we keep this controller decoupled from codegen for now —
        // we use the raw IProxy interface and string-based dispatch. When
        // the API stabilises we'll switch to ProxyInterfaces<…> for type
        // safety.
        m_proxy->uponSignal("HostnameChanged")
               .onInterface(kIface)
               .call([this](const std::string &h) {
                   QMetaObject::invokeMethod(this, [this, h]{
                       if (m_hostname != QString::fromStdString(h)) {
                           m_hostname = QString::fromStdString(h);
                           emit changed();
                       }
                   }, Qt::QueuedConnection);
               });

        m_proxy->finishRegistration();
        m_conn->enterEventLoopAsync();

        setOnline(true);
        refresh();
        m_pollTimer.start();
    } catch (const sdbus::Error &e) {
        qWarning() << "SystemInfoController: D-Bus connect failed:"
                   << e.getName().c_str() << "—" << e.getMessage().c_str();
        setOnline(false);
        // Retry in 3 s — the daemon may still be coming up at boot.
        QTimer::singleShot(3'000, this, [this]{ connect(); });
    }
}

void SystemInfoController::refresh() {
    if (!m_proxy) return;
    try {
        const auto str = [&](const char *name) {
            return QString::fromStdString(
                m_proxy->getProperty(name).onInterface(kIface).get<std::string>());
        };
        const auto u64 = [&](const char *name) {
            return static_cast<quint64>(
                m_proxy->getProperty(name).onInterface(kIface).get<uint64_t>());
        };

        const auto host = str("Hostname");
        const auto kver = str("KernelVersion");
        const auto os   = str("OsVersion");
        const auto app  = str("AppVersion");
        const auto up   = u64("UptimeSeconds");
        const auto used = u64("StorageUsedBytes");
        const auto tot  = u64("StorageTotalBytes");

        const bool dirty =
            host != m_hostname  || kver != m_kernelVersion ||
            os   != m_osVersion || app  != m_appVersion    ||
            up   != m_uptime    || used != m_storageUsed   ||
            tot  != m_storageTotal;

        m_hostname      = host;
        m_kernelVersion = kver;
        m_osVersion     = os;
        m_appVersion    = app;
        m_uptime        = up;
        m_storageUsed   = used;
        m_storageTotal  = tot;

        if (dirty) emit changed();
        setOnline(true);
    } catch (const sdbus::Error &e) {
        qWarning() << "SystemInfoController: refresh failed:"
                   << e.getName().c_str() << "—" << e.getMessage().c_str();
        setOnline(false);
    }
}

void SystemInfoController::setOnline(bool v) {
    if (m_online == v) return;
    m_online = v;
    emit onlineChanged();
}

// ── Privileged methods ──────────────────────────────────────────────────────

void SystemInfoController::reboot() {
    if (!m_proxy) return;
    try {
        m_proxy->callMethod("Reboot").onInterface(kIface).dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void SystemInfoController::powerOff() {
    if (!m_proxy) return;
    try {
        m_proxy->callMethod("PowerOff").onInterface(kIface).dontExpectReply();
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}

void SystemInfoController::setHostname(const QString &name) {
    if (!m_proxy) return;
    try {
        m_proxy->callMethod("SetHostname")
               .onInterface(kIface)
               .withArguments(name.toStdString());
    } catch (const sdbus::Error &e) {
        emit errorOccurred(QString::fromStdString(e.getMessage()));
    }
}
