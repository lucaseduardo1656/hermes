#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCursor>

#include "core/SystemController.h"
#include "core/PlayerController.h"
#include "core/NavigationController.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOverrideCursor(Qt::BlankCursor);

    SystemController    system;
    PlayerController    player;
    NavigationController nav;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("System", &system);
    engine.rootContext()->setContextProperty("Player", &player);
    engine.rootContext()->setContextProperty("Nav",    &nav);

    engine.loadFromModule("Elise", "Main");

    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
