#pragma once

#include "../text/PdfGlyphRunModel.h"

#include <QByteArray>
#include <QString>
#include <QVector>

namespace PDFClowne::Editing {

class PdfContentWriter {
public:
    // Owns the generated PDF operators for destructive text replacement:
    // BT, Tf, Tm, Tj, and TJ.
    struct StreamBuildResult {
        QByteArray contentStream;
        QVector<int> glyphIds;
        QString fontResourceKey;
        bool usesTJ = false;
    };

    StreamBuildResult buildReplacementTextStream(const PdfRun &run,
                                                 const QString &newText,
                                                 const QString &writerFontResourceName) const;

private:
    static QByteArray escapedPdfString(const QString &text);
};

} // namespace PDFClowne::Editing
