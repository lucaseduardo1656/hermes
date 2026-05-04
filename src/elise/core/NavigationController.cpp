#include "NavigationController.h"

NavigationController::NavigationController(QObject *parent) : QObject(parent) {}

void NavigationController::startDemo()
{
    m_active      = true;
    m_instruction = "Turn right on Av. Paulista";
    m_distance    = "300 m";
    m_direction   = "right";
    m_bearing     = 90.0;
    emit activeChanged();
    emit navChanged();
}

void NavigationController::stop()
{
    m_active = false;
    emit activeChanged();
}
