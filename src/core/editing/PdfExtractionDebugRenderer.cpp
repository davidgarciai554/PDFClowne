#include "PdfExtractionDebugRenderer.h"

#include <QColor>
#include <QPainter>
#include <QPen>
#include <QRectF>

namespace PDFClowne::Editing {

namespace {

// Correct conversion: PDF Y-up → image Y-down.
// r.bottom() = higher PDF Y (ascent/top of glyphs) → smaller image Y (closer to image top).
QRectF pdfRectToImageRect(const QRectF& pdfRect, double pageHeightPt, double xScale, double yScale)
{
    return QRectF(
        pdfRect.left() * xScale,
        (pageHeightPt - pdfRect.bottom()) * yScale,
        pdfRect.width() * xScale,
        pdfRect.height() * yScale);
}

QImage prepareCanvas(const QImage& src)
{
    return src.convertToFormat(QImage::Format_ARGB32_Premultiplied);
}

} // namespace

QImage PdfExtractionDebugRenderer::drawTextRunBoxes(const QImage& pageImage,
                                                    const QList<PdfTextRun>& runs,
                                                    const QSizeF& pageSizePt)
{
    if (pageImage.isNull() || pageSizePt.width() <= 0.0 || pageSizePt.height() <= 0.0)
        return pageImage;

    QImage result = prepareCanvas(pageImage);
    QPainter painter(&result);
    painter.setRenderHint(QPainter::Antialiasing, false);

    QPen pen(QColor(220, 30, 30, 200), 1.0);
    pen.setCosmetic(true);
    painter.setPen(pen);
    painter.setBrush(Qt::NoBrush);

    const double xs = static_cast<double>(result.width()) / pageSizePt.width();
    const double ys = static_cast<double>(result.height()) / pageSizePt.height();
    const double ph = pageSizePt.height();

    for (const PdfTextRun& run : runs) {
        if (!run.bboxPdf.isEmpty())
            painter.drawRect(pdfRectToImageRect(run.bboxPdf, ph, xs, ys));
    }

    return result;
}

QImage PdfExtractionDebugRenderer::drawLineBoxes(const QImage& pageImage,
                                                 const QList<PdfTextLine>& lines,
                                                 const QSizeF& pageSizePt)
{
    if (pageImage.isNull() || pageSizePt.width() <= 0.0 || pageSizePt.height() <= 0.0)
        return pageImage;

    QImage result = prepareCanvas(pageImage);
    QPainter painter(&result);
    painter.setRenderHint(QPainter::Antialiasing, false);

    QPen pen(QColor(30, 160, 30, 200), 1.0);
    pen.setCosmetic(true);
    painter.setPen(pen);
    painter.setBrush(Qt::NoBrush);

    const double xs = static_cast<double>(result.width()) / pageSizePt.width();
    const double ys = static_cast<double>(result.height()) / pageSizePt.height();
    const double ph = pageSizePt.height();

    for (const PdfTextLine& line : lines) {
        if (!line.bboxPdf.isEmpty())
            painter.drawRect(pdfRectToImageRect(line.bboxPdf, ph, xs, ys));
    }

    return result;
}

QImage PdfExtractionDebugRenderer::drawBlockBoxes(const QImage& pageImage,
                                                  const QList<PdfTextBlock>& blocks,
                                                  const QSizeF& pageSizePt)
{
    if (pageImage.isNull() || pageSizePt.width() <= 0.0 || pageSizePt.height() <= 0.0)
        return pageImage;

    QImage result = prepareCanvas(pageImage);
    QPainter painter(&result);
    painter.setRenderHint(QPainter::Antialiasing, false);

    QPen pen(QColor(30, 80, 220, 200), 2.0);
    pen.setCosmetic(true);
    painter.setPen(pen);
    painter.setBrush(Qt::NoBrush);

    const double xs = static_cast<double>(result.width()) / pageSizePt.width();
    const double ys = static_cast<double>(result.height()) / pageSizePt.height();
    const double ph = pageSizePt.height();

    for (const PdfTextBlock& block : blocks) {
        if (!block.bboxPdf.isEmpty())
            painter.drawRect(pdfRectToImageRect(block.bboxPdf, ph, xs, ys));
    }

    return result;
}

} // namespace PDFClowne::Editing
