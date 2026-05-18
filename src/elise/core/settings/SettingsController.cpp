#include "SettingsController.h"

SettingsController::SettingsController(QObject *parent)
    : QObject(parent)
    , m_sys(new SystemInfoController(this))
    , m_network(new NetworkController(this))
    , m_bluetooth(new BluetoothController(this))
{
}
