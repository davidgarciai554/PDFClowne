#include <QCoreApplication>
#include <QDebug>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QUrl>
#include <QIcon>

#include "Logger.h"
#include "PdfDocument.h"

int main(int argc, char *argv[])
{
    Logger::install();

    QGuiApplication app(argc, argv);
    app.setApplicationName("PDFClowne");
    app.setApplicationVersion("2.0.0");
    app.setOrganizationName("PDFClowne");
    app.setOrganizationDomain("pdfclowne.app");
    app.setWindowIcon(QIcon(":/PdfClowne.ico"));

    qmlRegisterType<PdfDocument>("PDFClowne.Backend", 1, 0, "PdfDocument");

    QQmlApplicationEngine engine;

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [](const QUrl &url) {
            qCritical() << "QML object creation failed:" << url;
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    engine.load(QUrl(u"qrc:/qt/qml/PDFClowne/src/qml/main.qml"_qs));

    return app.exec();
}
