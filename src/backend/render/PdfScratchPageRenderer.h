#pragma once

#include "../text/PdfEditTextLayout.h"
#include "../text/PdfFontResolver.h"
#include "../text/PdfGlyphRunModel.h"

#include <QImage>
#include <QPolygonF>
#include <QString>
#include <QVector>

#include <mupdf/fitz.h>

namespace PDFClowne::Render {

class PdfScratchPageRenderer {
public:
    QImage renderRedactedBase(const QString &filePath,
                              const QString &password,
                              int pageIndex,
                              const QVector<QPolygonF> &redactionQuads,
                              qreal scale,
                              QString *error = nullptr) const;

    QImage renderGlyphOverlay(const QVector<PDFClowne::Editing::PdfRun> &runs,
                              const PDFClowne::Editing::PdfFontResolver &fontResolver,
                              const QString &filePath,
                              const QString &password,
                              const QSize &pixelSize,
                              qreal scale,
                              QString *error = nullptr) const;

    QImage renderGlyphOverlayFromLayouts(const QVector<PDFClowne::Editing::PdfEditTextLayoutResult> &layouts,
                                         const QSize &pixelSize,
                                         qreal scale,
                                         QString *error = nullptr) const;

    static QImage pixmapToImage(fz_pixmap *pixmap);

private:
    static QTransform textMatrixFromLayoutGlyph(const PDFClowne::Editing::PdfEditTextLayoutResult &layout,
                                                const PDFClowne::Editing::PdfEditLaidOutGlyph &glyph,
                                                qreal pageHeight);
};

} // namespace PDFClowne::Render
