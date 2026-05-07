#include "PdfWriteBackEngine.h"

#include "FileWriter.h"
#include "PdfiumInitializer.h"

#include <QColor>
#include <QStringList>

#include <fpdf_edit.h>
#include <fpdf_save.h>
#include <spdlog/spdlog.h>

#include <algorithm>
#include <vector>

namespace PDFClowne::Editing {

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// static
std::vector<unsigned short> PdfWriteBackEngine::toUtf16(const QString& s)
{
    std::vector<unsigned short> buf;
    buf.reserve(static_cast<size_t>(s.size()) + 1);
    for (const QChar ch : s)
        buf.push_back(ch.unicode());
    buf.push_back(0);
    return buf;
}

// static
const char* PdfWriteBackEngine::toStandardFontName(const QString& family)
{
    const QString lower = family.toLower();
    if (lower.contains("times") || lower.contains("serif"))
        return "Times-Roman";
    if (lower.contains("courier") || lower.contains("mono"))
        return "Courier";
    if (lower.contains("symbol"))
        return "Symbol";
    if (lower.contains("zapf"))
        return "ZapfDingbats";
    // Default: Helvetica covers most sans-serif fonts
    return "Helvetica";
}

// static
void PdfWriteBackEngine::removeBlockObjects(FPDF_PAGE page,
                                             const PdfTextBlock& block)
{
    // Collect all page object indices belonging to this block
    std::vector<int> indices;
    for (const PdfTextLine& line : block.lines)
        for (const PdfTextRun& run : line.runs)
            if (run.pageObjectIndex >= 0)
                indices.push_back(run.pageObjectIndex);

    // Remove in descending order so lower indices remain valid
    std::sort(indices.begin(), indices.end(), std::greater<int>());
    indices.erase(std::unique(indices.begin(), indices.end()), indices.end());

    for (int idx : indices) {
        FPDF_PAGEOBJECT obj = FPDFPage_GetObject(page, idx);
        if (obj) {
            FPDFPage_RemoveObject(page, obj);
            FPDFPageObj_Destroy(obj);
        }
    }
}

// ---------------------------------------------------------------------------
// writeBackBlock
// ---------------------------------------------------------------------------

bool PdfWriteBackEngine::writeBackBlock(FPDF_DOCUMENT       doc,
                                         int                 pageIndex,
                                         const PdfTextBlock& block,
                                         const QString&      newText,
                                         const FontFallbackResult& font)
{
    FPDF_PAGE page = nullptr;
    {
        PDFIUM_LOCK();
        page = FPDF_LoadPage(doc, pageIndex);
    }
    if (!page) {
        spdlog::error("PdfWriteBackEngine: failed to load page {}", pageIndex);
        return false;
    }

    {
        PDFIUM_LOCK();

        // 1. Remove original text objects for this block
        removeBlockObjects(page, block);

        // 2. Determine font + size to use
        const char* stdFont = toStandardFontName(font.resolvedFontName);
        const float  fontSize = static_cast<float>(
            font.resolvedFontSize > 0.0 ? font.resolvedFontSize : 12.0);

        FPDF_FONT pdfFont = FPDFText_LoadStandardFont(doc, stdFont);
        if (!pdfFont) {
            spdlog::warn("PdfWriteBackEngine: FPDFText_LoadStandardFont('{}') failed,"
                         " falling back to Helvetica", stdFont);
            pdfFont = FPDFText_LoadStandardFont(doc, "Helvetica");
        }

        // 3. Determine the dominant color
        const QColor col = block.dominantColor.isValid()
                           ? block.dominantColor
                           : Qt::black;
        const unsigned int r = static_cast<unsigned int>(col.red());
        const unsigned int g = static_cast<unsigned int>(col.green());
        const unsigned int b = static_cast<unsigned int>(col.blue());

        // 4. Split newText into lines and insert one text object per line
        const QStringList lines = newText.split(QLatin1Char('\n'));
        const double lineHeight = fontSize * 1.2;
        const double startX = block.bboxPdf.left();
        const double startY = block.bboxPdf.top();  // PDF Y-up origin

        for (int i = 0; i < lines.size(); ++i) {
            const QString& lineStr = lines.at(i);
            if (lineStr.trimmed().isEmpty()) continue;

            FPDF_PAGEOBJECT textObj = FPDFPageObj_NewTextObj(doc, stdFont, fontSize);
            if (!textObj) {
                spdlog::warn("PdfWriteBackEngine: FPDFPageObj_NewTextObj failed for line {}", i);
                continue;
            }

            const auto utf16 = toUtf16(lineStr);
            FPDFText_SetText(textObj,
                reinterpret_cast<FPDF_WIDESTRING>(utf16.data()));

            // Position: PDF coordinates are Y-up; line 0 is at the top of bbox
            const double y = startY - i * lineHeight;
            FPDFPageObj_Transform(textObj,
                1.0, 0.0, 0.0, 1.0, startX, y);

            FPDFPageObj_SetFillColor(textObj, r, g, b, 255);
            FPDFPage_InsertObject(page, textObj);
        }

        // 5. Commit to page stream
        FPDFPage_GenerateContent(page);
        FPDF_ClosePage(page);
    }

    return true;
}

// ---------------------------------------------------------------------------
// saveTo
// ---------------------------------------------------------------------------

bool PdfWriteBackEngine::saveTo(FPDF_DOCUMENT doc, const QString& outputPath,
                                 SaveMode mode)
{
    FileWriter fw(outputPath);
    if (!fw.isOpen()) {
        spdlog::error("PdfWriteBackEngine: cannot open output file '{}'",
                      outputPath.toStdString());
        return false;
    }

    const int flags = (mode == SaveMode::Incremental)
                      ? FPDF_INCREMENTAL : FPDF_NO_INCREMENTAL;

    int result = 0;
    {
        PDFIUM_LOCK();
        result = FPDF_SaveAsCopy(doc, fw.handle(), flags);
    }

    if (!result) {
        spdlog::error("PdfWriteBackEngine: FPDF_SaveAsCopy failed for '{}'",
                      outputPath.toStdString());
    }
    return result != 0;
}

} // namespace PDFClowne::Editing
