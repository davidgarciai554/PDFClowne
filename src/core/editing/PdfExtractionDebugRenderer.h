#pragma once

#include "PdfTextBlock.h"
#include "PdfTextLine.h"
#include "PdfTextRun.h"

#include <QImage>
#include <QList>
#include <QSizeF>

namespace PDFClowne::Editing {

class PdfExtractionDebugRenderer {
public:
    // Red boxes — individual text runs
    static QImage drawTextRunBoxes(const QImage& pageImage,
                                   const QList<PdfTextRun>& runs,
                                   const QSizeF& pageSizePt);

    // Green boxes — grouped text lines
    static QImage drawLineBoxes(const QImage& pageImage,
                                const QList<PdfTextLine>& lines,
                                const QSizeF& pageSizePt);

    // Blue boxes — text blocks (paragraphs)
    static QImage drawBlockBoxes(const QImage& pageImage,
                                 const QList<PdfTextBlock>& blocks,
                                 const QSizeF& pageSizePt);
};

} // namespace PDFClowne::Editing
