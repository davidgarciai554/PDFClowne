#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>
#include <QFile>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (app.arguments().size() < 2)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Usage: PdfTextEditSaveSingleLineTest <pdf>"));

    QString targetPath;
    QString originalText;
    const QString replacement = QStringLiteral("DAVID EDITADO");
    const int saved = PdfTextEditSaveTestUtils::saveOneEdit(app.arguments().at(1),
                                                            QStringLiteral("DAVID GARCIA MARTIN"),
                                                            replacement,
                                                            QStringLiteral("PdfTextEditSaveSingleLine.out.pdf"),
                                                            &targetPath,
                                                            &originalText);
    if (saved != 0)
        return saved;

    const int saveAsCheck = PdfTextEditSaveTestUtils::assertSavedText(targetPath, replacement, originalText);
    if (saveAsCheck != 0)
        return saveAsCheck;

    const QString overwritePath =
        PdfTextEditSaveTestUtils::outputPath(QStringLiteral("PdfTextEditSaveSingleLine.overwrite.pdf"));
    QFile::remove(overwritePath);
    if (!QFile::copy(app.arguments().at(1), overwritePath))
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Could not prepare overwrite-save fixture."));

    QString overwriteTarget;
    QString overwriteOriginalText;
    const int overwriteSaved = PdfTextEditSaveTestUtils::saveOneEdit(overwritePath,
                                                                     QStringLiteral("DAVID GARCIA MARTIN"),
                                                                     QStringLiteral("GUARDAR NORMAL"),
                                                                     QStringLiteral("PdfTextEditSaveSingleLine.unused.pdf"),
                                                                     &overwriteTarget,
                                                                     &overwriteOriginalText,
                                                                     true);
    if (overwriteSaved != 0)
        return overwriteSaved;
    if (overwriteTarget != overwritePath)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Normal overwrite save must return the current file path."));

    const int overwriteCheck = PdfTextEditSaveTestUtils::assertSavedText(overwritePath,
                                                                         QStringLiteral("GUARDAR NORMAL"),
                                                                         overwriteOriginalText);
    if (overwriteCheck != 0)
        return overwriteCheck;

    QString shortTargetPath;
    QString shortOriginalText;
    const QString shortReplacement = QStringLiteral("Backend");
    const int shortSaved = PdfTextEditSaveTestUtils::saveOneEdit(app.arguments().at(1),
                                                                 QStringLiteral("Backend Engineer"),
                                                                 shortReplacement,
                                                                 QStringLiteral("PdfTextEditSaveSingleLine.short.pdf"),
                                                                 &shortTargetPath,
                                                                 &shortOriginalText);
    if (shortSaved != 0)
        return shortSaved;
    const int shortTextCheck =
        PdfTextEditSaveTestUtils::assertSavedText(shortTargetPath, shortReplacement, shortOriginalText);
    if (shortTextCheck != 0)
        return shortTextCheck;
    const int staleTailCheck = PdfTextEditSaveTestUtils::assertOriginalTailRemovedInEditedRegion(
        app.arguments().at(1),
        shortTargetPath,
        QStringLiteral("Backend Engineer"),
        QStringLiteral("Engineer"));
    if (staleTailCheck != 0)
        return staleTailCheck;

    return PdfTextEditSaveTestUtils::assertSavedReplacementGeometry(app.arguments().at(1),
                                                                    shortTargetPath,
                                                                    QStringLiteral("Backend Engineer"),
                                                                    shortReplacement);
}
