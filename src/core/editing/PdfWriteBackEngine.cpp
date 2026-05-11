#include "PdfWriteBackEngine.h"

#include "FileWriter.h"
#include "PdfiumInitializer.h"

#include <QColor>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QByteArray>
#include <QStringList>
#include <QUuid>

#include <fpdf_edit.h>
#include <fpdf_save.h>
#include <spdlog/spdlog.h>

#include <algorithm>
#include <cstring>
#include <vector>

namespace PDFClowne::Editing {

namespace {

QString tempOutputPathFor(const QString& outputPath)
{
    const QFileInfo info(outputPath);
    const QDir dir = info.absoluteDir();
    if (!dir.exists())
        return {};

    const QString baseName = info.completeBaseName().isEmpty()
        ? QStringLiteral("pdfclowne-edit")
        : info.completeBaseName();
    return dir.absoluteFilePath(
        QStringLiteral(".%1-%2.tmp.pdf")
            .arg(baseName, QUuid::createUuid().toString(QUuid::Id128)));
}

bool canOpenWithPdfium(const QString& path)
{
    const QByteArray encodedPath = path.toUtf8();
    FPDF_DOCUMENT loaded = nullptr;
    {
        PDFIUM_LOCK();
        loaded = FPDF_LoadDocument(encodedPath.constData(), nullptr);
        if (loaded)
            FPDF_CloseDocument(loaded);
    }
    return loaded != nullptr;
}

} // namespace

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

FPDF_FONT PdfWriteBackEngine::loadReplacementFont(FPDF_DOCUMENT doc,
                                                  const FontFallbackResult& font,
                                                  const char* standardFontName)
{
    if (font.canEmbed && !font.fontFilePath.isEmpty()) {
        QFile fontFile(font.fontFilePath);
        if (fontFile.open(QIODevice::ReadOnly)) {
            const QByteArray data = fontFile.readAll();
            if (!data.isEmpty()) {
                FPDF_FONT embedded = FPDFText_LoadFont(
                    doc,
                    reinterpret_cast<const uint8_t*>(data.constData()),
                    static_cast<uint32_t>(data.size()),
                    FPDF_FONT_TRUETYPE,
                    true);
                if (embedded) {
                    spdlog::debug("PdfWriteBackEngine: embedded fallback font '{}'",
                                  font.fontFilePath.toStdString());
                    return embedded;
                }
            }
        }
        spdlog::warn("PdfWriteBackEngine: could not embed fallback font '{}', using standard PDF font",
                     font.fontFilePath.toStdString());
    }

    FPDF_FONT standard = FPDFText_LoadStandardFont(doc, standardFontName);
    if (!standard && std::strcmp(standardFontName, "Helvetica") != 0) {
        spdlog::warn("PdfWriteBackEngine: FPDFText_LoadStandardFont('{}') failed, falling back to Helvetica",
                     standardFontName);
        standard = FPDFText_LoadStandardFont(doc, "Helvetica");
    }
    return standard;
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

// static
bool PdfWriteBackEngine::insertVisualReplacementMasks(FPDF_PAGE page,
                                                       const PdfTextBlock& block)
{
    const QList<PdfTextLine> lines = block.lines.isEmpty()
        ? QList<PdfTextLine>{ PdfTextLine{ {}, block.bboxPdf, block.bboxPdf.top() } }
        : block.lines;

    bool insertedAny = false;
    for (const PdfTextLine& line : lines) {
        QRectF rect = line.bboxPdf.isEmpty() ? block.bboxPdf : line.bboxPdf;
        if (rect.isEmpty()) {
            continue;
        }

        const double padX = std::max(0.75, block.dominantFontSize * 0.05);
        const double padY = std::max(0.75, block.dominantFontSize * 0.08);
        rect.adjust(-padX, -padY, padX, padY);

        FPDF_PAGEOBJECT mask = FPDFPageObj_CreateNewRect(
            static_cast<float>(rect.left()),
            static_cast<float>(rect.top()),
            static_cast<float>(rect.width()),
            static_cast<float>(rect.height()));
        if (!mask) {
            spdlog::warn("PdfWriteBackEngine: could not create visual replacement mask");
            continue;
        }

        FPDFPageObj_SetFillColor(mask, 255, 255, 255, 255);
        FPDFPath_SetDrawMode(mask, FPDF_FILLMODE_WINDING, 0);
        FPDFPage_InsertObject(page, mask);
        insertedAny = true;
    }

    return insertedAny;
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

        // 1. Native rewrite removes source objects. Visual replacement keeps
        // complex source streams intact and paints a persistent page mask.
        const bool visualReplacement =
            block.editStrategy == QStringLiteral("persistentVisualReplacement");
        if (visualReplacement) {
            if (!insertVisualReplacementMasks(page, block)) {
                spdlog::warn("PdfWriteBackEngine: no visual replacement mask inserted for '{}'",
                             block.blockId.toStdString());
            }
        } else {
            removeBlockObjects(page, block);
        }

        // 2. Determine font + size to use
        const char* stdFont = toStandardFontName(font.resolvedFontName);
        const float  fontSize = static_cast<float>(
            font.resolvedFontSize > 0.0 ? font.resolvedFontSize : 12.0);

        FPDF_FONT pdfFont = loadReplacementFont(doc, font, stdFont);
        if (!pdfFont) {
            spdlog::error("PdfWriteBackEngine: failed to load any replacement font");
            FPDF_ClosePage(page);
            return false;
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

            FPDF_PAGEOBJECT textObj = FPDFPageObj_CreateTextObj(doc, pdfFont, fontSize);
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
        FPDFFont_Close(pdfFont);
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
    const QString tempPath = tempOutputPathFor(outputPath);
    if (tempPath.isEmpty()) {
        spdlog::error("PdfWriteBackEngine: cannot create temporary output path for '{}'",
                      outputPath.toStdString());
        return false;
    }

    const int flags = (mode == SaveMode::Incremental)
                      ? FPDF_INCREMENTAL : FPDF_NO_INCREMENTAL;

    int result = 0;
    {
        FileWriter fw(tempPath);
        if (!fw.isOpen()) {
            spdlog::error("PdfWriteBackEngine: cannot open temporary output file '{}'",
                          tempPath.toStdString());
            return false;
        }

        {
            PDFIUM_LOCK();
            result = FPDF_SaveAsCopy(doc, fw.handle(), flags);
        }
    }

    if (!result) {
        spdlog::error("PdfWriteBackEngine: FPDF_SaveAsCopy failed for '{}'",
                      tempPath.toStdString());
        QFile::remove(tempPath);
        return false;
    }

    if (!canOpenWithPdfium(tempPath)) {
        spdlog::error("PdfWriteBackEngine: validation failed for temporary PDF '{}'",
                      tempPath.toStdString());
        QFile::remove(tempPath);
        return false;
    }

    QFile::remove(outputPath);
    if (!QFile::rename(tempPath, outputPath)) {
        spdlog::error("PdfWriteBackEngine: failed to rename temporary PDF '{}' to '{}'",
                      tempPath.toStdString(), outputPath.toStdString());
        QFile::remove(tempPath);
        return false;
    }

    return true;
}

} // namespace PDFClowne::Editing
