#pragma once

// Architecture contract for PDF annotation operations.
// Current implementation: PdfAnnotationController (src/backend/).
// Annotations are managed in-memory and flushed via PdfDocument::saveEditedCopy.

#include <QString>
#include <QRectF>

namespace PDFClowne {

class PdfAnnotationService {
public:
    virtual ~PdfAnnotationService() = default;

    // Returns JSON array of all annotations.
    virtual QString annotationsJson() const = 0;
    virtual void setAnnotationsJson(const QString &json) = 0;

    // type: "highlight" | "underline" | "strikeout" | "rect" | "circle" | "line"
    //     | "arrow" | "ink" | "freeText" | "stickyNote"
    // rectJson: { x, y, width, height } in PDF points
    // styleJson: { color, opacity, lineWidth, ... }
    virtual QString createAnnotation(const QString &type,
                                     int pageIndex,
                                     const QString &rectJson,
                                     const QString &styleJson = {}) = 0;

    virtual bool updateAnnotation(const QString &id, const QString &patchJson) = 0;
    virtual bool removeAnnotation(const QString &id) = 0;
    virtual void clear() = 0;
};

} // namespace PDFClowne
