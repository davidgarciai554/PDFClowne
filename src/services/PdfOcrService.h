#pragma once

// Architecture contract for OCR operations.
// Current implementation: OcrService stub (src/backend/).
// Full implementation requires Tesseract + Leptonica (ENABLE_OCR=ON).

#include <QString>

namespace PDFClowne {

class PdfOcrService {
public:
    virtual ~PdfOcrService() = default;

    virtual bool isAvailable() const = 0;
    virtual QString engineName() const = 0;

    // Returns true if the page appears to be a scan (no extractable text layer).
    virtual bool isScannedPage(int pageIndex, const QString &editableLayoutJson) const = 0;

    // Runs OCR on a page image. Returns hOCR or JSON with word bounding boxes.
    virtual QString ocrPage(const QString &pdfPath, int pageIndex,
                            const QString &language = "eng") = 0;

    // Embeds OCR text layer into PDF. Output path may equal input for in-place update.
    // Uses atomic write internally.
    virtual bool embedTextLayer(const QString &inputPath, const QString &outputPath,
                                const QString &language = "eng") = 0;
};

} // namespace PDFClowne
