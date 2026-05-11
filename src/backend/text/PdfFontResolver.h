#pragma once

#include <QByteArray>
#include <QString>

namespace PDFClowne::Editing {

class PdfFontResolver {
public:
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

    static QString debugFamilyName(const QString &pdfFontName);
};

} // namespace PDFClowne::Editing
