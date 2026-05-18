#include "SystemController.h"

SystemController::SystemController(QObject *parent) : QObject(parent) {}

void SystemController::setDark(bool dark)
{
    if (m_dark == dark) return;
    m_dark = dark;
    emit themeChanged();
}
