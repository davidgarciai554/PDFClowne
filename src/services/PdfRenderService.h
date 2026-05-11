#pragma once

// Architecture contract for PDF rendering.
// Current implementation: PdfDocument (src/backend/) + DocumentRenderController.
// Engine: MuPDF. This interface documents the render layer used by QML.

#include <QString>
#include <QSizeF>

namespace PDFClowne {

class PdfRenderService {
public:
    virtual ~PdfRenderService() = default;

    virtual bool loadDocument(const QString &path, const QString &password = {}) = 0;
    virtual void closeDocument() = 0;

    virtual int pageCount() const = 0;
    virtual QSizeF pageSize(int pageIndex) const = 0;

    // Returns image provider URL ("image://pdf-render/...") for the requested page.
    virtual QString renderPage(int pageIndex, qreal scale) = 0;
    virtual QString renderThumbnail(int pageIndex) = 0;

    // Coordinate conversion: PDF points <-> screen pixels at given scale + rotation.
    virtual QSizeF pdfToScreen(const QSizeF &pdfPt, qreal scale, int rotation) const = 0;
    virtual QSizeF screenToPdf(const QSizeF &screenPx, qreal scale, int rotation) const = 0;
};

} // namespace PDFClowne
