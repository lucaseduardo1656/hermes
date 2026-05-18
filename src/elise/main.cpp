#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCursor>

#include "core/SystemController.h"
#include "core/PlayerController.h"
#include "core/NavigationController.h"
#include "core/settings/SettingsController.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOverrideCursor(Qt::BlankCursor);

    SystemController    system;
    PlayerController    player;
    NavigationController nav;
    SettingsController   settings;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("System",   &system);
    engine.rootContext()->setContextProperty("Player",   &player);
    engine.rootContext()->setContextProperty("Nav",      &nav);
    engine.rootContext()->setContextProperty("Settings", &settings);

    engine.loadFromModule("Elise", "Main");

    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
