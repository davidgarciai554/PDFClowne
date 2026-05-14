#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryDir>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (app.arguments().size() < 2)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Usage: PdfTextEditSaveInPlaceTest <pdf>"));

    QTemporaryDir tempDir;
    if (!tempDir.isValid())
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not create temporary test directory."));

    const QString inputPath = tempDir.filePath(QStringLiteral("ctrl-s-in-place.pdf"));
    if (!QFile::copy(app.arguments().at(1), inputPath))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not copy fixture for in-place save test."));

    const qint64 originalSize = QFileInfo(inputPath).size();
    const QString originalNeedle = QStringLiteral("DAVID GARCIA MARTIN");
    const QString replacement = QStringLiteral("CTRL S EDITADO");

    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText page =
        extractor.extractPage(inputPath, QString(), 0);
    if (!page.error.isEmpty())
        return PdfTextEditSaveTestUtils::fail(page.error);

    const int regionIndex = PdfTextEditSaveTestUtils::findRegion(page, originalNeedle);
    if (regionIndex < 0)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Fixture did not contain Ctrl+S target text."));

    PDFClowne::Editing::PdfEditSessionController controller;
    if (!controller.loadDocument(inputPath))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not load temporary PDF."));
    if (!PdfTextEditSaveTestUtils::beginRegionEdit(controller, page, regionIndex))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not begin in-place edit."));

    const QString originalText = controller.activeText();
    controller.updateActiveText(replacement);
    if (!controller.saveDocument(inputPath, true))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("saveDocument in-place failed."));
    if (controller.hasPendingEdits())
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("In-place save left pending edits dirty."));

    controller.closeDocument();

    const int textCheck = PdfTextEditSaveTestUtils::assertSavedText(inputPath, replacement, originalText);
    if (textCheck != 0)
        return textCheck;

    const qint64 savedSize = QFileInfo(inputPath).size();
    if (savedSize <= 0 || savedSize == originalSize)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("In-place save did not change the PDF file size."));

    return 0;
}
