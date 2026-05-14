#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (argc < 2)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Usage: PdfEditEmbeddedFontPreviewTest <fixture.pdf>"));

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

    controller.updateActiveText(QStringLiteral("DAVID GARCIA MARTIN X"));
    const QString debug = controller.lastResolvedEditFontDebug();
    if (debug.contains(QStringLiteral("+")) && !debug.contains(QStringLiteral("fallback:true")))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Subset font preview must fall back: %1").arg(debug));
    if (debug.contains(QStringLiteral("embedded:true")) && debug.contains(QStringLiteral("fallback:true")))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Preview reported both embedded and fallback: %1").arg(debug));

    return 0;
}
