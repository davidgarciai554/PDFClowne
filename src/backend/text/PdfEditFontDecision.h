#pragma once

#include "PdfFontResolver.h"

#include <QByteArray>
#include <QString>

namespace PDFClowne::Editing {

struct PdfEditFontDecision {
    QString fontName;
    QString fontFileName;
    QByteArray fontProgram;
    bool useEmbeddedOriginal = false;
    bool useBundledFallback = false;
    bool subsetOriginalRejected = false;
    QString reason;
};

class PdfEditFontDecisionService {
public:
    PdfEditFontDecision decideFontForEditedText(const PdfFontResolver::ResolvedFont &resolved,
                                                const QString &replacementText,
                                                bool bold,
                                                bool italic) const;
};

} // namespace PDFClowne::Editing
