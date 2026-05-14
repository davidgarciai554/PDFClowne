#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>

#include <cmath>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (argc < 2)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Usage: PdfEditCaretMetricsTest <fixture.pdf>"));

    const QString sourcePath = QString::fromLocal8Bit(argv[1]);
    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText page =
        extractor.extractPage(sourcePath, QString(), 0);
    if (!page.error.isEmpty())
        return PdfTextEditSaveTestUtils::fail(page.error);

    const int regionIndex = PdfTextEditSaveTestUtils::findRegion(page, QStringLiteral("DAVID"));
    if (regionIndex < 0)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Fixture did not expose the expected editable region."));

    PDFClowne::Editing::PdfEditSessionController controller;
    if (!controller.loadDocument(sourcePath))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not load fixture into edit controller."));
    if (!PdfTextEditSaveTestUtils::beginRegionEdit(controller, page, regionIndex))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not begin edit session."));

    const QString edited = QStringLiteral("DAVID GARCIA MARTIN");
    controller.updateActiveText(edited);
    controller.moveCursorHome();
    for (int i = 0; i < 7; ++i)
        controller.moveCursorRight();

    const QJsonDocument doc = QJsonDocument::fromJson(controller.activeEditGeometryJson().toUtf8());
    const QJsonObject root = doc.object();
    const QJsonObject box = root.value(QStringLiteral("box")).toObject();
    const QJsonObject caret = root.value(QStringLiteral("caret")).toObject();
    const qreal boxX = box.value(QStringLiteral("x")).toDouble();
    const qreal boxWidth = box.value(QStringLiteral("width")).toDouble();
    const qreal caretX = caret.value(QStringLiteral("x")).toDouble();
    const int cursor = root.value(QStringLiteral("cursor")).toInt();
    const qreal linear = boxX + boxWidth * (qreal(cursor) / qreal(edited.size()));

    if (std::abs(caretX - linear) <= 0.1) {
        return PdfTextEditSaveTestUtils::fail(
            QStringLiteral("Caret geometry still matches linear box-width division. caret=%1 linear=%2")
                .arg(caretX)
                .arg(linear));
    }

    return 0;
}
