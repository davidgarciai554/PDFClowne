#pragma once

#include "FontFallbackManager.h"
#include "PdfTextBlock.h"

#include <QString>

#include <fpdfview.h>

namespace PDFClowne::Editing {

// Removes original text objects for an edited block and inserts new ones,
// then saves the modified document to disk using PDFium.
class PdfWriteBackEngine {
public:
    enum class SaveMode { Incremental, FullRewrite };

    // Rewrites the text for `block` on `pageIndex` in `doc`.
    // `newText` is split on '\n' into per-line strings.
    // `font` selects which font family/size to use for the replacement text.
    // Returns true on success.
    bool writeBackBlock(FPDF_DOCUMENT       doc,
                        int                 pageIndex,
                        const PdfTextBlock& block,
                        const QString&      newText,
                        const FontFallbackResult& font);

    // Saves the document to `outputPath`. Returns true on success.
    bool saveTo(FPDF_DOCUMENT doc, const QString& outputPath,
                SaveMode mode = SaveMode::FullRewrite);

private:
    // Collect and remove all page objects belonging to `block` from `page`.
    // Removal is done in reverse-index order to preserve validity.
    static void removeBlockObjects(FPDF_PAGE page, const PdfTextBlock& block);

    // Build a null-terminated UTF-16LE buffer from `s`.
    static std::vector<unsigned short> toUtf16(const QString& s);

    // Map a font family name to the closest PDFium standard font name.
    static const char* toStandardFontName(const QString& family);
};

} // namespace PDFClowne::Editing
