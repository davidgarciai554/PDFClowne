#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>

namespace {

int assertNoTypicalGarbledText(const QString &targetPath)
{
    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText saved =
        extractor.extractPage(targetPath, QString(), 0);
    if (!saved.error.isEmpty())
        return PdfTextEditSaveTestUtils::fail(saved.error);

    const QString text = PdfTextEditSaveTestUtils::pagePlainText(saved);
    const QStringList garbledNeedles = {
        QStringLiteral("ƒ"),
        QStringLiteral("Ç"),
        QStringLiteral("¼"),
        QStringLiteral("¤")
    };
    for (const QString &needle : garbledNeedles) {
        if (text.contains(needle)) {
            return PdfTextEditSaveTestUtils::fail(
                QStringLiteral("Saved PDF text contains typical garbled character '%1'.").arg(needle));
        }
    }
    return 0;
}

} // namespace

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (app.arguments().size() < 2)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Usage: PdfEditSavedTextIsReadableTest <pdf>"));

    QString targetPath;
    QString originalText;
    const QString replacement = QStringLiteral("Backend y Arquitectura");
    const int saved = PdfTextEditSaveTestUtils::saveOneEdit(app.arguments().at(1),
                                                            QStringLiteral("Backend Engineer"),
                                                            replacement,
                                                            QStringLiteral("PdfEditSavedTextIsReadable.out.pdf"),
                                                            &targetPath,
                                                            &originalText);
    if (saved != 0)
        return saved;

    const int textCheck = PdfTextEditSaveTestUtils::assertSavedText(targetPath, replacement, originalText);
    if (textCheck != 0)
        return textCheck;

    return assertNoTypicalGarbledText(targetPath);
}
