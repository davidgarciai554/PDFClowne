#include "PdfPageObjectExtractor.h"

#include "EditingHeuristics.h"
#include "PdfiumInitializer.h"

#include <QVector>

#include <spdlog/spdlog.h>

#include <cmath>
#include <memory>
#include <type_traits>
#include <vector>

namespace PDFClowne::Editing {

namespace {

constexpr double kRadiansToDegrees = 180.0 / 3.14159265358979323846;

struct PageCloser {
    void operator()(FPDF_PAGE page) const
    {
        if (page) {
            FPDF_ClosePage(page);
        }
    }
};

struct TextPageCloser {
    void operator()(FPDF_TEXTPAGE textPage) const
    {
        if (textPage) {
            FPDFText_ClosePage(textPage);
        }
    }
};

using PagePtr = std::unique_ptr<std::remove_pointer_t<FPDF_PAGE>, PageCloser>;
using TextPagePtr = std::unique_ptr<std::remove_pointer_t<FPDF_TEXTPAGE>, TextPageCloser>;

QString readFontName(FPDF_FONT font)
{
    if (!font) {
        return {};
    }

    const size_t length = FPDFFont_GetBaseFontName(font, nullptr, 0);
    if (length == 0) {
        return {};
    }

    std::vector<char> buffer(length);
    FPDFFont_GetBaseFontName(font, buffer.data(), buffer.size());
    return QString::fromUtf8(buffer.data());
}

bool looksLikeSubsetFont(const QString& fontName)
{
    if (fontName.size() < 7 || fontName.at(6) != QLatin1Char('+')) {
        return false;
    }

    for (int i = 0; i < 6; ++i) {
        const QChar ch = fontName.at(i);
        if (ch < QLatin1Char('A') || ch > QLatin1Char('Z')) {
            return false;
        }
    }

    return true;
}

bool shouldDiscardRun(const PdfTextRun& run)
{
    return run.text.trimmed().isEmpty()
        || run.bboxPdf.isEmpty()
        || run.renderMode == FPDF_TEXTRENDERMODE_INVISIBLE;
}

void applyEditabilityFlags(PdfTextRun& run)
{
    if (std::abs(run.rotation) > PDFClowne::Heuristics::TEXT_ROTATION_EDITABLE_MAX_DEGREES) {
        run.isEditable = false;
        run.nonEditableReason = QStringLiteral("Texto rotado");
    }
}

} // namespace

PdfPageObjectExtractor::PdfPageObjectExtractor(FPDF_DOCUMENT doc)
    : m_doc(doc)
{
}

QList<PdfTextRun> PdfPageObjectExtractor::extractTextRunsFromPage(int pageNumber)
{
    PDFIUM_LOCK();

    QList<PdfTextRun> result;
    if (!m_doc || pageNumber < 0) {
        spdlog::warn("PDF text extraction skipped for invalid document/page: {}", pageNumber);
        return result;
    }

    PagePtr page(FPDF_LoadPage(m_doc, pageNumber));
    if (!page) {
        spdlog::error("PDFium failed to load page {} for text extraction", pageNumber);
        return result;
    }

    TextPagePtr textPage(FPDFText_LoadPage(page.get()));
    if (!textPage) {
        spdlog::error("PDFium failed to load text page {} for text extraction", pageNumber);
        return result;
    }

    const int objectCount = FPDFPage_CountObjects(page.get());
    for (int i = 0; i < objectCount; ++i) {
        FPDF_PAGEOBJECT obj = FPDFPage_GetObject(page.get(), i);
        if (!obj || FPDFPageObj_GetType(obj) != FPDF_PAGEOBJ_TEXT) {
            continue;
        }

        PdfTextRun run = extractRun(obj, textPage.get(), i);
        applyEditabilityFlags(run);
        if (!shouldDiscardRun(run)) {
            result.append(run);
        }
    }

    spdlog::debug("Extracted {} PDF text runs from page {}", result.size(), pageNumber);
    return result;
}

PdfTextRun PdfPageObjectExtractor::extractRun(FPDF_PAGEOBJECT obj, FPDF_TEXTPAGE textPage, int idx)
{
    PdfTextRun run;
    run.pageObjectIndex = idx;
    run.text = readUnicodeString(obj, textPage);

    float left = 0.0f;
    float bottom = 0.0f;
    float right = 0.0f;
    float top = 0.0f;
    if (FPDFPageObj_GetBounds(obj, &left, &bottom, &right, &top)) {
        run.bboxPdf = QRectF(QPointF(left, bottom), QPointF(right, top)).normalized();
    }

    FPDF_FONT font = FPDFTextObj_GetFont(obj);
    run.fontName = readFontName(font);
    run.fontIsEmbedded = font ? (FPDFFont_GetIsEmbedded(font) != 0) : false;
    run.fontIsSubset = looksLikeSubsetFont(run.fontName);

    float fontSize = 0.0f;
    if (FPDFTextObj_GetFontSize(obj, &fontSize)) {
        run.fontSize = fontSize;
    }

    unsigned int r = 0;
    unsigned int g = 0;
    unsigned int b = 0;
    unsigned int a = 255;
    if (FPDFPageObj_GetFillColor(obj, &r, &g, &b, &a)) {
        run.color = QColor(static_cast<int>(r), static_cast<int>(g), static_cast<int>(b), static_cast<int>(a));
    }

    FS_MATRIX matrix {};
    if (FPDFPageObj_GetMatrix(obj, &matrix)) {
        run.matrix = { matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f };
        run.rotation = std::atan2(matrix.b, matrix.a) * kRadiansToDegrees;
    }

    run.renderMode = static_cast<int>(FPDFTextObj_GetTextRenderMode(obj));
    if (run.renderMode == FPDF_TEXTRENDERMODE_INVISIBLE) {
        run.isEditable = false;
        run.nonEditableReason = QStringLiteral("Texto invisible/OCR");
    }

    return run;
}

QString PdfPageObjectExtractor::readUnicodeString(FPDF_PAGEOBJECT obj, FPDF_TEXTPAGE textPage)
{
    const unsigned long length = FPDFTextObj_GetText(obj, textPage, nullptr, 0);
    if (length == 0) {
        return {};
    }

    QVector<FPDF_WCHAR> buffer(static_cast<qsizetype>(length));
    const unsigned long written = FPDFTextObj_GetText(obj, textPage, buffer.data(), length);
    if (written == 0) {
        return {};
    }

    const qsizetype textLength = buffer.last() == 0 ? buffer.size() - 1 : buffer.size();
    return QString::fromUtf16(reinterpret_cast<const char16_t*>(buffer.constData()), textLength);
}

} // namespace PDFClowne::Editing
