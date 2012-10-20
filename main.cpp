#include <QApplication>
#include <QDeclarativeContext>
#include <QFile>
#include <QTextStream>

#include "qmlapplicationviewer.h"
#include "returnclass.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QmlApplicationViewer viewer;
    QString title;
    QString message;
    ReturnClass returnClass;

    if (argc == 2) {
        title = "User agreement";
    } else if (argc == 3) {
        title = argv[1];
    } else {
        qCritical("usage: meego-confirm-text [title] file\n");
        return 2;
    }

    QFile file(argv[argc-1]);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCritical("meego-confirm-text: %s", qPrintable(file.errorString()));
        return 1;
    }

    QTextStream stream(&file);
    message = stream.readAll();
    file.close();

    viewer.rootContext()->setContextProperty("title", title);
    viewer.rootContext()->setContextProperty("message", message);
    viewer.rootContext()->setContextProperty("returnClass", &returnClass);
    viewer.setOrientation(QmlApplicationViewer::ScreenOrientationAuto);
    viewer.setMainQmlFile(QLatin1String("qml/meego-confirm-text/main.qml"));
    viewer.showExpanded();

    app.exec();
    return retval; //set in returnclass.cpp
}

