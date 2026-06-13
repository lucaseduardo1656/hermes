#pragma once
#include <QObject>

#include "SystemInfoController.h"
#include "NetworkController.h"
#include "BluetoothController.h"
#include "AppearanceController.h"
#include "AudioController.h"
#include "OfflineMapsController.h"

// Root facade for system-wide settings. Owns and exposes one sub-controller
// per concern (system, network, audio, …) so QML can bind via:
//
//     Settings.sys.hostname
//     Settings.network.online
//
// Sub-controllers are created lazily as they're implemented; each one
// encapsulates its own transport (D-Bus client, JSON file, hardware ioctl).
class SettingsController : public QObject {
    Q_OBJECT
    Q_PROPERTY(SystemInfoController *sys        READ sys        CONSTANT)
    Q_PROPERTY(NetworkController    *network    READ network    CONSTANT)
    Q_PROPERTY(BluetoothController  *bluetooth  READ bluetooth  CONSTANT)
    Q_PROPERTY(AppearanceController  *appearance  READ appearance  CONSTANT)
    Q_PROPERTY(AudioController       *audio       READ audio       CONSTANT)
    Q_PROPERTY(OfflineMapsController *offlineMaps READ offlineMaps CONSTANT)

public:
    explicit SettingsController(QObject *parent = nullptr);

    SystemInfoController  *sys()         const { return m_sys; }
    NetworkController     *network()     const { return m_network; }
    BluetoothController   *bluetooth()   const { return m_bluetooth; }
    AppearanceController  *appearance()  const { return m_appearance; }
    AudioController       *audio()       const { return m_audio; }
    OfflineMapsController *offlineMaps() const { return m_offlineMaps; }

private:
    SystemInfoController  *m_sys;
    NetworkController     *m_network;
    BluetoothController   *m_bluetooth;
    AppearanceController  *m_appearance;
    AudioController       *m_audio;
    OfflineMapsController *m_offlineMaps;
};
