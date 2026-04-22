#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "NetworkBackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    NetworkBackend network;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Network"), &network);
    engine.loadFromModule("Hermes", "Main");

    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
