#include "PdfExtractionDebugRenderer.h"

#include <QColor>
#include <QPainter>
#include <QPen>
#include <QRectF>

namespace PDFClowne::Editing {

QImage PdfExtractionDebugRenderer::drawTextRunBoxes(const QImage& pageImage,
                                                    const QList<PdfTextRun>& runs,
                                                    const QSizeF& pageSizePt)
{
    if (pageImage.isNull() || pageSizePt.width() <= 0.0 || pageSizePt.height() <= 0.0) {
        return pageImage;
    }

    QImage result = pageImage.convertToFormat(QImage::Format_ARGB32_Premultiplied);
    QPainter painter(&result);
    painter.setRenderHint(QPainter::Antialiasing, false);

    QPen pen(QColor(255, 0, 0, 190), 1.0);
    pen.setCosmetic(true);
    painter.setPen(pen);
    painter.setBrush(Qt::NoBrush);

    const double xScale = static_cast<double>(result.width()) / pageSizePt.width();
    const double yScale = static_cast<double>(result.height()) / pageSizePt.height();
    const double pageHeightPt = pageSizePt.height();

    for (const PdfTextRun& run : runs) {
        if (run.bboxPdf.isEmpty()) {
            continue;
        }

        const QRectF imageRect(run.bboxPdf.left() * xScale,
                               (pageHeightPt - run.bboxPdf.top()) * yScale,
                               run.bboxPdf.width() * xScale,
                               run.bboxPdf.height() * yScale);
        painter.drawRect(imageRect);
    }

    return result;
}

} // namespace PDFClowne::Editing
