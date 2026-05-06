#pragma once

#include "PdfTextRun.h"

#include <QImage>
#include <QList>
#include <QSizeF>

namespace PDFClowne::Editing {

class PdfExtractionDebugRenderer {
public:
    static QImage drawTextRunBoxes(const QImage& pageImage,
                                   const QList<PdfTextRun>& runs,
                                   const QSizeF& pageSizePt);
};

} // namespace PDFClowne::Editing
