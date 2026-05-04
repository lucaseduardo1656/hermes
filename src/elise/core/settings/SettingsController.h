#pragma once
#include <QObject>

#include "SystemInfoController.h"

// Root facade for system-wide settings. Owns and exposes one sub-controller
// per concern (system, network, audio, …) so QML can bind via:
//
//     Settings.sys.hostname
//     Settings.sys.reboot()
//
// Sub-controllers are created lazily as they're implemented; each one
// encapsulates its own transport (D-Bus client, JSON file, hardware ioctl).
class SettingsController : public QObject {
    Q_OBJECT
    Q_PROPERTY(SystemInfoController *sys READ sys CONSTANT)

public:
    explicit SettingsController(QObject *parent = nullptr);

    SystemInfoController *sys() const { return m_sys; }

private:
    SystemInfoController *m_sys;
};
