#pragma once

#include <QPointF>
#include <QRectF>
#include <QSizeF>

namespace PDFClowne::Editing {

// Bidirectional coordinate conversion between PDF space and image/screen space.
//
// PDF coordinates: Y-up, origin at page bottom-left, units = points.
// Image coordinates: Y-down, origin at top-left, units = pixels.
//
// bboxPdf storage convention (from PdfPageObjectExtractor):
//   bboxPdf.top()    = QRectF::y()          = lower PDF Y (near descent / baseline)
//   bboxPdf.bottom() = QRectF::y()+height() = higher PDF Y (near ascent / top of glyphs)
class PdfCoordTransform {
public:
    PdfCoordTransform(const QSizeF& pageSizePt, const QSizeF& imageSize)
        : m_pageH(pageSizePt.height())
        , m_sx(pageSizePt.width() > 0.0 ? imageSize.width() / pageSizePt.width() : 1.0)
        , m_sy(pageSizePt.height() > 0.0 ? imageSize.height() / pageSizePt.height() : 1.0)
    {
    }

    // PDF point → image pixel
    QPointF pdfToImage(const QPointF& p) const
    {
        return { p.x() * m_sx, (m_pageH - p.y()) * m_sy };
    }

    // PDF rect → image rect (accounts for Y-axis flip)
    QRectF pdfToImage(const QRectF& r) const
    {
        // r.bottom() = higher PDF Y = top of glyphs → smaller image Y
        return { r.left() * m_sx,
                 (m_pageH - r.bottom()) * m_sy,
                 r.width() * m_sx,
                 r.height() * m_sy };
    }

    // Image pixel → PDF point
    QPointF imageToPdf(const QPointF& p) const
    {
        return { p.x() / m_sx, m_pageH - p.y() / m_sy };
    }

    // Image rect → PDF rect
    QRectF imageToPdf(const QRectF& r) const
    {
        const double pdfBottom = m_pageH - (r.y() + r.height()) / m_sy;
        return QRectF(r.x() / m_sx, pdfBottom, r.width() / m_sx, r.height() / m_sy).normalized();
    }

    double xScale() const { return m_sx; }
    double yScale() const { return m_sy; }
    double pageHeightPt() const { return m_pageH; }

private:
    double m_pageH;
    double m_sx;
    double m_sy;
};

} // namespace PDFClowne::Editing
