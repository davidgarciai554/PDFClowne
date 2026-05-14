#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>
#include <QFile>
#include <QTemporaryDir>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (app.arguments().size() < 2)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Usage: PdfTextEditSaveNoWhiteCoverTest <pdf>"));

    QTemporaryDir tempDir;
    if (!tempDir.isValid())
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not create temporary test directory."));

    const QString inputPath = tempDir.filePath(QStringLiteral("no-white-cover.pdf"));
    if (!QFile::copy(app.arguments().at(1), inputPath))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not copy fixture for white cover test."));

    const QString originalNeedle = QStringLiteral("DAVID GARCIA MARTIN");
    const QString replacement = QStringLiteral("Texto editado sin caja blanca");

    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText page =
        extractor.extractPage(inputPath, QString(), 0);
    if (!page.error.isEmpty())
        return PdfTextEditSaveTestUtils::fail(page.error);

    const int regionIndex = PdfTextEditSaveTestUtils::findRegion(page, originalNeedle);
    if (regionIndex < 0)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Fixture did not contain white cover target text."));

    PDFClowne::Editing::PdfEditSessionController controller;
    if (!controller.loadDocument(inputPath))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not load temporary PDF."));
    if (!PdfTextEditSaveTestUtils::beginRegionEdit(controller, page, regionIndex))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not begin white cover edit."));

    controller.updateActiveText(replacement);
    if (!controller.commitActiveText(QStringLiteral("NoWhiteCoverTest")))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not commit white cover edit."));
    if (!controller.saveDocument(inputPath, true))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not save white cover edit."));

    controller.closeDocument();

    QFile file(inputPath);
    if (!file.open(QIODevice::ReadOnly))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not read saved PDF."));

    const QByteArray bytes = file.readAll();
    if (bytes.contains("1 1 1 rg"))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Saved PDF contains a white cover rectangle operator."));

    return 0;
}
