#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCursor>
#include "NetworkBackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOverrideCursor(Qt::BlankCursor);

    NetworkBackend network;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Network"), &network);
    engine.loadFromModule("Hermes", "Main");

    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
