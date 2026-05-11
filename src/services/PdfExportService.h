#pragma once

// Architecture contract for PDF export to other formats.
// Implementation: LibreOffice headless/UNO (requires ENABLE_LIBREOFFICE_EXPORT=ON, LO installed).
// WARNING: PDF → ODT/DOCX conversion is lossy. Complex layouts, subset fonts,
// embedded images, and form fields may not survive. Use HTML as intermediate step.

#include <QString>

namespace PDFClowne {

enum class ExportFormat {
    HtmlStructured,   // Intermediate step — more reliable than direct PDF→ODT
    Odt,
    Docx,
    PlainText,
};

class PdfExportService {
public:
    virtual ~PdfExportService() = default;

    virtual bool isAvailable() const = 0;
    virtual QString libreofficePath() const = 0;

    // Export PDF to the target format via LibreOffice headless.
    // For Odt/Docx: first exports to HtmlStructured, then converts with LO UNO.
    virtual bool exportDocument(const QString &pdfPath, const QString &outputPath,
                                ExportFormat format) = 0;

    // Returns warnings about conversion quality (subset fonts, images, etc.).
    virtual QString exportWarningsJson(const QString &pdfPath) const = 0;
};

} // namespace PDFClowne
