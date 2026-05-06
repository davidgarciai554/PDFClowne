#pragma once

#include "PdfTextLine.h"

#include <QColor>
#include <QList>
#include <QRectF>
#include <QString>
#include <Qt>

namespace PDFClowne::Editing {

struct PdfTextBlock {
    QString blockId;
    int pageNumber = -1;
    QList<PdfTextLine> lines;
    QRectF bboxPdf;
    QString dominantFontName;
    double dominantFontSize = 0.0;
    QColor dominantColor = Qt::black;
    double lineSpacing = 0.0;
    Qt::Alignment alignment = Qt::AlignLeft;
    bool isEditable = true;
    QString nonEditableReason;
};

} // namespace PDFClowne::Editing
