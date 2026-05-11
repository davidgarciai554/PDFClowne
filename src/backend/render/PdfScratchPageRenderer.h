#pragma once

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

    static QImage pixmapToImage(fz_pixmap *pixmap);

private:
    static QVector<PDFClowne::Editing::PdfShapedGlyph> shapeRun(
        const PDFClowne::Editing::PdfRun &run,
        const QByteArray &fontProgram);
};

} // namespace PDFClowne::Render
