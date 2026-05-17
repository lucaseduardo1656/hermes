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

void NavigationController::update(bool active,
                                  const QString &instruction,
                                  const QString &distance,
                                  const QString &direction,
                                  double bearing)
{
    const bool activeChanged_ = (active != m_active);
    const bool dataChanged_ =
        instruction != m_instruction
     || distance    != m_distance
     || direction   != m_direction
     || bearing     != m_bearing;
    m_active      = active;
    m_instruction = instruction;
    m_distance    = distance;
    m_direction   = direction;
    m_bearing     = bearing;
    if (activeChanged_) emit activeChanged();
    if (dataChanged_)   emit navChanged();
}
