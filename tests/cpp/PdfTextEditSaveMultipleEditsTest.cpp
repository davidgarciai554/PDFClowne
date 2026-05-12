#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>
#include <QFile>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (app.arguments().size() < 2)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Usage: PdfTextEditSaveMultipleEditsTest <pdf>"));

    const QString sourcePath = app.arguments().at(1);
    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText page =
        extractor.extractPage(sourcePath, QString(), 0);
    if (!page.error.isEmpty())
        return PdfTextEditSaveTestUtils::fail(page.error);
    if (page.regions.size() < 2)
        return 0;

    PDFClowne::Editing::PdfEditSessionController controller;
    if (!controller.loadDocument(sourcePath))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not load fixture into edit controller."));

    QVector<QString> originals;
    const QVector<QString> replacements{
        QStringLiteral("PRIMER CAMBIO"),
        QStringLiteral("SEGUNDO CAMBIO")
    };

    for (int i = 0; i < 2; ++i) {
        if (!PdfTextEditSaveTestUtils::beginRegionEdit(controller, page, i))
            return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not begin edit session %1.").arg(i));
        originals.append(controller.activeText());
        controller.updateActiveText(replacements.at(i));
        if (!controller.commitActiveText())
            return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not commit text edit %1.").arg(i));
    }

    const QString targetPath = PdfTextEditSaveTestUtils::outputPath(QStringLiteral("PdfTextEditSaveMultipleEdits.out.pdf"));
    QFile::remove(targetPath);
    if (!controller.saveDocument(targetPath, false))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not save multiple text edits."));

    for (int i = 0; i < replacements.size(); ++i) {
        const int checked = PdfTextEditSaveTestUtils::assertSavedText(targetPath,
                                                                      replacements.at(i),
                                                                      originals.value(i),
                                                                      false);
        if (checked != 0)
            return checked;
    }

    return 0;
}
