#pragma once

#include "PdfTextLine.h"

#include <QColor>
#include <QList>
#include <QMetaType>
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
    QString sourceKind = QStringLiteral("directPageText");
    QString editability = QStringLiteral("nativeEditable");
    QString editStrategy = QStringLiteral("nativeStreamRewrite");
    double unicodeQuality = 1.0;
    bool isEditable = true;
    QString nonEditableReason;
};

} // namespace PDFClowne::Editing

Q_DECLARE_METATYPE(PDFClowne::Editing::PdfTextBlock)
Q_DECLARE_METATYPE(QList<PDFClowne::Editing::PdfTextBlock>)
