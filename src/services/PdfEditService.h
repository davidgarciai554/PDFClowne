#pragma once

// Architecture contract for inline PDF text editing.
// Current implementation: EditingController (src/core/editing/, PDFCLOWNE_ENABLE_PDFIUM_EDITING).
// Engine: PDFium for extraction, PdfWriteBackEngine for save.
// Known limits: subset fonts, glyph coverage gaps, complex layouts.

#include <QString>
#include <QRectF>

namespace PDFClowne {

class PdfEditService {
public:
    virtual ~PdfEditService() = default;

    // Extracts text blocks from a page. Returns JSON array of PdfTextBlock.
    virtual QString extractTextBlocks(int pageIndex) = 0;

    // Updates the text of a block (identified by blockId from extraction).
    virtual bool updateBlockText(const QString &blockId, const QString &newText) = 0;

    // Applies all pending edits and writes output PDF.
    // Uses atomic write: temp → validate → rename. Returns false if validation fails.
    virtual bool saveEdited(const QString &inputPath, const QString &outputPath) = 0;

    // Font fallback: returns fallback font name if requested font lacks glyph coverage.
    virtual QString resolveFontFallback(const QString &fontName, const QString &text) const = 0;

    virtual bool isAvailable() const = 0;
};

} // namespace PDFClowne
