#pragma once

#include "PdfFontWritePlan.h"
#include "../text/PdfGlyphRunModel.h"

#include <QString>

#include <mupdf/fitz.h>
#include <mupdf/pdf.h>

namespace PDFClowne::Editing {

class PdfFontResourceWriter {
public:
    PdfFontWritePlan ensureFontForText(fz_context *ctx,
                                       pdf_document *doc,
                                       pdf_page *page,
                                       const PdfRun &run,
                                       const QString &newText,
                                       QString *error) const;

    PdfFontWritePlan ensureFontForTextWithOriginalProgram(fz_context *ctx,
                                                          pdf_document *doc,
                                                          pdf_page *page,
                                                          const PdfRun &run,
                                                          const QString &newText,
                                                          const QByteArray &originalFontProgram,
                                                          const QString &originalFontName,
                                                          QString *error) const;

private:
    static bool canUseWinAnsi(const QString &text);
    static QByteArray encodeWinAnsi(const QString &text);
    static QByteArray encodeUtf16Be(const QString &text);
};

} // namespace PDFClowne::Editing
