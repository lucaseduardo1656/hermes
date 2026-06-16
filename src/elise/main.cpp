#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCursor>

#include "core/SystemController.h"
#include "core/PlayerController.h"
#include "core/NavigationController.h"
#include "core/settings/SettingsController.h"
#include "core/settings/AudioController.h"
#include "core/GpsController.h"
#include "core/RoadInfoController.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOverrideCursor(Qt::BlankCursor);

    SystemController    system;
    PlayerController    player;
    NavigationController nav;
    SettingsController   settings;
    GpsController        gps;
    RoadInfoController   roadInfo;
    roadInfo.attachGps(&gps);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("System",   &system);
    engine.rootContext()->setContextProperty("Player",   &player);
    engine.rootContext()->setContextProperty("Nav",      &nav);
    engine.rootContext()->setContextProperty("Settings", &settings);
    engine.rootContext()->setContextProperty("GPS",      &gps);
    engine.rootContext()->setContextProperty("RoadInfo", &roadInfo);

    // Live EQ: when user changes preset, apply the af filter to mpv immediately.
    QObject::connect(settings.audio(), &AudioController::eqPresetChanged,
                     [&player, &settings]() {
                         player.setAudioFilter(settings.audio()->eqFilterString());
                     });

    engine.loadFromModule("Elise", "Main");

    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
