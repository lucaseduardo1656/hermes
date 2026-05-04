#include "SettingsController.h"
#include "SystemInfoController.h"

SettingsController::SettingsController(QObject *parent)
    : QObject(parent)
    , m_sys(new SystemInfoController(this))
{
}
