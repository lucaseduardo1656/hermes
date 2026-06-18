#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCursor>
#include <QStyleHints>

#include "core/SystemController.h"
#include "core/PlayerController.h"
#include "core/NavigationController.h"
#include "core/settings/SettingsController.h"
#include "core/settings/AudioController.h"
#include "core/GpsController.h"
#include "core/RoadInfoController.h"
#include "core/WeatherController.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOverrideCursor(Qt::BlankCursor);

    // The resistive WaveShare panel jitters several pixels the instant a finger
    // lands, which made the map's pan DragHandler grab the touch immediately and
    // starve the long-press detection. Raise the drag threshold so a small
    // jitter no longer counts as a drag — pan still feels responsive.
    app.styleHints()->setStartDragDistance(28);

    SystemController    system;
    PlayerController    player;
    NavigationController nav;
    SettingsController   settings;
    GpsController        gps;
    RoadInfoController   roadInfo;
    roadInfo.attachGps(&gps);
    WeatherController    weather;
    weather.bindGps(&gps);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("System",   &system);
    engine.rootContext()->setContextProperty("Player",   &player);
    engine.rootContext()->setContextProperty("Nav",      &nav);
    engine.rootContext()->setContextProperty("Settings", &settings);
    engine.rootContext()->setContextProperty("GPS",      &gps);
    engine.rootContext()->setContextProperty("RoadInfo", &roadInfo);
    engine.rootContext()->setContextProperty("Weather",  &weather);

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
