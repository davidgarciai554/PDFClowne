#pragma once

#include <QByteArray>
#include <QString>

namespace PDFClowne::Editing {

class PdfFontResolver {
public:
    struct FontValidationResult {
        bool usableForEditedText = false;
        bool subsetFont = false;
        bool canEncodeAllCharacters = false;
        QString reason;
    };

    struct ResolvedFont {
        QString fontResourceKey;
        QString originalSubsetName;
        QString debugFamilyName;
        QByteArray fontProgram;
        bool requiresSubstitute = true;
        QString error;
    };

    ResolvedFont resolveEmbeddedFont(const QString &filePath,
                                     const QString &password,
                                     const QString &fontResourceKey) const;

    FontValidationResult validateFontProgramForText(const QByteArray &fontProgram,
                                                    const QString &fontName,
                                                    const QString &text) const;

    static QString debugFamilyName(const QString &pdfFontName);
};

} // namespace PDFClowne::Editing
