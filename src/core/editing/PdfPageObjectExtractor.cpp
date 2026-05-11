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
        run.editability = QStringLiteral("visualEditable");
        run.editStrategy = QStringLiteral("persistentVisualReplacement");
        run.nonEditableReason = QStringLiteral("Texto rotado: se usará reemplazo visual persistente.");
    }

    if (run.fontIsSubset) {
        run.editability = QStringLiteral("visualEditable");
        run.editStrategy = QStringLiteral("persistentVisualReplacement");
        if (run.nonEditableReason.isEmpty()) {
            run.nonEditableReason =
                QStringLiteral("Fuente subset embebida: se usará reemplazo visual persistente.");
        }
    }
}

QString readTextPageFontName(FPDF_TEXTPAGE textPage, int charIndex)
{
    int flags = 0;
    const unsigned long length = FPDFText_GetFontInfo(textPage, charIndex, nullptr, 0, &flags);
    if (length == 0) {
        return {};
    }

    std::vector<char> buffer(length);
    if (FPDFText_GetFontInfo(textPage, charIndex, buffer.data(), length, &flags) == 0) {
        return {};
    }
    return QString::fromUtf8(buffer.data());
}

QString unicodeToString(unsigned int unicode)
{
    if (unicode == 0) {
        return {};
    }
    if (unicode <= 0xffff) {
        return QString(QChar(static_cast<ushort>(unicode)));
    }
    char32_t ucs4 = static_cast<char32_t>(unicode);
    return QString::fromUcs4(&ucs4, 1);
}

int plainTextLength(const QList<PdfTextRun>& runs)
{
    int total = 0;
    for (const PdfTextRun& run : runs) {
        total += run.text.trimmed().size();
    }
    return total;
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

    const QList<PdfTextRun> fallbackRuns = extractTextPageFallbackRuns(textPage.get());
    if (!fallbackRuns.isEmpty()
        && plainTextLength(fallbackRuns) > plainTextLength(result) + 20) {
        spdlog::info("PdfPageObjectExtractor: using text-page fallback for page {} "
                     "(direct runs={}, fallback runs={})",
                     pageNumber, result.size(), fallbackRuns.size());
        result = fallbackRuns;
    }

    spdlog::debug("Extracted {} PDF text runs from page {}", result.size(), pageNumber);
    return result;
}

PdfTextRun PdfPageObjectExtractor::extractRun(FPDF_PAGEOBJECT obj, FPDF_TEXTPAGE textPage, int idx)
{
    PdfTextRun run;
    run.pageObjectIndex = idx;
    run.sourceKind = QStringLiteral("directPageText");
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
        run.editability = QStringLiteral("ocrEditable");
        run.editStrategy = QStringLiteral("ocrLayerReplacement");
        run.sourceKind = QStringLiteral("invisibleTextLayer");
        run.nonEditableReason = QStringLiteral("Texto invisible/OCR");
    }

    return run;
}

QList<PdfTextRun> PdfPageObjectExtractor::extractTextPageFallbackRuns(FPDF_TEXTPAGE textPage)
{
    QList<PdfTextRun> runs;
    if (!textPage) {
        return runs;
    }

    PdfTextRun current;
    bool hasCurrent = false;
    double currentCenterY = 0.0;
    int unknownUnicode = 0;
    int seenChars = 0;

    auto resetCurrent = [&]() {
        current = PdfTextRun{};
        current.pageObjectIndex = -1;
        current.sourceKind = QStringLiteral("extractedStructuredText");
        current.editability = QStringLiteral("visualEditable");
        current.editStrategy = QStringLiteral("persistentVisualReplacement");
        current.nonEditableReason =
            QStringLiteral("Texto detectado por capa estructurada; se usará reemplazo visual persistente.");
        current.isEditable = true;
    };

    auto flush = [&]() {
        if (!hasCurrent || current.text.trimmed().isEmpty() || current.bboxPdf.isEmpty()) {
            resetCurrent();
            hasCurrent = false;
            return;
        }
        current.unicodeQuality = seenChars > 0
            ? 1.0 - (static_cast<double>(unknownUnicode) / static_cast<double>(seenChars))
            : 0.0;
        runs.append(current);
        resetCurrent();
        hasCurrent = false;
        currentCenterY = 0.0;
        unknownUnicode = 0;
        seenChars = 0;
    };

    resetCurrent();

    const int charCount = FPDFText_CountChars(textPage);
    for (int i = 0; i < charCount; ++i) {
        const unsigned int unicode = FPDFText_GetUnicode(textPage, i);
        if (unicode == '\r' || unicode == '\n') {
            flush();
            continue;
        }

        const QString ch = unicodeToString(unicode);
        if (ch.isEmpty()) {
            ++unknownUnicode;
            ++seenChars;
            continue;
        }

        double left = 0.0;
        double right = 0.0;
        double bottom = 0.0;
        double top = 0.0;
        const bool hasBox = FPDFText_GetCharBox(textPage, i, &left, &right, &bottom, &top);
        const QRectF charBox = hasBox
            ? QRectF(QPointF(left, bottom), QPointF(right, top)).normalized()
            : QRectF();

        if (hasBox && !charBox.isEmpty()) {
            const double centerY = charBox.center().y();
            const double fontSize = (std::max)(1.0, FPDFText_GetFontSize(textPage, i));
            if (hasCurrent
                && std::abs(centerY - currentCenterY) > (std::max)(2.0, fontSize * 0.75)) {
                flush();
            }

            if (!hasCurrent) {
                current.fontName = readTextPageFontName(textPage, i);
                current.fontIsSubset = looksLikeSubsetFont(current.fontName);
                current.fontSize = fontSize;
                current.bboxPdf = charBox;
                currentCenterY = centerY;

                unsigned int r = 0, g = 0, b = 0, a = 255;
                if (FPDFText_GetFillColor(textPage, i, &r, &g, &b, &a)) {
                    current.color = QColor(static_cast<int>(r),
                                           static_cast<int>(g),
                                           static_cast<int>(b),
                                           static_cast<int>(a));
                }

                FS_MATRIX matrix {};
                if (FPDFText_GetMatrix(textPage, i, &matrix)) {
                    current.matrix = { matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f };
                    current.rotation = std::atan2(matrix.b, matrix.a) * kRadiansToDegrees;
                } else {
                    const float angle = FPDFText_GetCharAngle(textPage, i);
                    if (angle >= 0.0f) {
                        current.rotation = angle * kRadiansToDegrees;
                    }
                }
                applyEditabilityFlags(current);
            } else {
                current.bboxPdf = current.bboxPdf.united(charBox);
                currentCenterY = (currentCenterY + centerY) * 0.5;
            }
        }

        current.text += ch;
        hasCurrent = true;
        ++seenChars;
    }

    flush();
    return runs;
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
