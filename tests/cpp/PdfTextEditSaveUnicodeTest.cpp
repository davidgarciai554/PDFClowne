#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (app.arguments().size() < 2)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Usage: PdfTextEditSaveUnicodeTest <pdf>"));

    QString targetPath;
    QString originalText;
    const QString replacement = QStringLiteral("Edición niño café");
    const int saved = PdfTextEditSaveTestUtils::saveOneEdit(app.arguments().at(1),
                                                            QString(),
                                                            replacement,
                                                            QStringLiteral("PdfTextEditSaveUnicode.out.pdf"),
                                                            &targetPath,
                                                            &originalText);
    if (saved != 0)
        return saved;

    return PdfTextEditSaveTestUtils::assertSavedText(targetPath, replacement, originalText);
}
