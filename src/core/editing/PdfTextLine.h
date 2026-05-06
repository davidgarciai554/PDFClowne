#pragma once

#include "PdfTextRun.h"

#include <QList>
#include <QRectF>

namespace PDFClowne::Editing {

struct PdfTextLine {
    QList<PdfTextRun> runs;
    QRectF bboxPdf;
    double baseline = 0.0;
};

} // namespace PDFClowne::Editing
