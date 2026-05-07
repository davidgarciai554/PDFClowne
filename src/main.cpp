#include <QCoreApplication>
#include <QCommandLineParser>
#include <QDebug>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QIcon>
#include <QTimer>
#include <QVariant>

#include "DesktopIntegration.h"
#include "DocumentRenderController.h"
#include "DocumentSearchController.h"
#include "Logger.h"
#include "PdfDocument.h"
#include "PdfRenderImageProvider.h"
#include "TextBlockModel.h"

#ifdef PDFCLOWNE_ENABLE_PDFIUM_EDITING
#include "EditingController.h"
#endif

namespace {
QString normalizeStartupSource(const QString &argument)
{
    const QUrl url(argument);
    if (url.isLocalFile())
        return url.toString();

    const QFileInfo fileInfo(argument);
    if (fileInfo.exists())
        return QUrl::fromLocalFile(fileInfo.absoluteFilePath()).toString();

    return argument;
}
}

int main(int argc, char *argv[])
{
    Logger::install();

    QGuiApplication app(argc, argv);
    app.setApplicationName("PDFClowne");
    app.setApplicationVersion("2.0.0");
    app.setOrganizationName("PDFClowne");
    app.setOrganizationDomain("pdfclowne.app");
    app.setWindowIcon(QIcon(":/PdfClowne.ico"));

    QCommandLineParser parser;
    parser.setApplicationDescription("PDFClowne PDF viewer");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument("files", "PDF files to open.");
    parser.process(app);

    const QStringList startupFiles = parser.positionalArguments();

    qmlRegisterType<PdfDocument>("PDFClowne.Backend", 1, 0, "PdfDocument");
    qmlRegisterType<PDFClowne::Editing::TextBlockModel>("PDFClowne.Editing", 1, 0, "TextBlockModel");
#ifdef PDFCLOWNE_ENABLE_PDFIUM_EDITING
    qmlRegisterType<PDFClowne::Editing::EditingController>("PDFClowne.Editing", 1, 0, "EditingController");
#endif

    QQmlApplicationEngine engine;
    auto *pdfRenderImageProvider = new PdfRenderImageProvider;
    engine.addImageProvider(QStringLiteral("pdf-render"), pdfRenderImageProvider);
    DesktopIntegration desktopIntegration;
    DocumentRenderController documentRenderController(pdfRenderImageProvider);
    DocumentSearchController documentSearchController;
    engine.rootContext()->setContextProperty("desktopIntegration", &desktopIntegration);
    engine.rootContext()->setContextProperty("documentRenderController", &documentRenderController);
    engine.rootContext()->setContextProperty("documentSearchController", &documentSearchController);

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

    if (!startupFiles.isEmpty() && !engine.rootObjects().isEmpty()) {
        QObject *rootObject = engine.rootObjects().constFirst();
        QTimer::singleShot(0, &app, [rootObject, startupFiles]() {
            for (const QString &file : startupFiles) {
                QMetaObject::invokeMethod(
                    rootObject,
                    "openPdf",
                    Q_ARG(QVariant, QVariant(normalizeStartupSource(file))));
            }
        });
    }

    return app.exec();
}
