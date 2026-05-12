#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (app.arguments().size() < 2)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Usage: PdfTextEditSaveReopenExtractionTest <pdf>"));

    QString targetPath;
    QString originalText;
    const QString replacement = QStringLiteral("TEXTO REABIERTO");
    const int saved = PdfTextEditSaveTestUtils::saveOneEdit(app.arguments().at(1),
                                                            QString(),
                                                            replacement,
                                                            QStringLiteral("PdfTextEditSaveReopenExtraction.out.pdf"),
                                                            &targetPath,
                                                            &originalText);
    if (saved != 0)
        return saved;

    PDFClowne::Editing::PdfEditSessionController reopened;
    if (!reopened.loadDocument(targetPath) || !reopened.extractPage(0))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not reopen saved PDF through edit controller."));

    return PdfTextEditSaveTestUtils::assertSavedText(targetPath, replacement, originalText);
}
