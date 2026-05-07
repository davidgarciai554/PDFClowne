#include "TextBlockBuilder.h"

#include "EditingHeuristics.h"

#include <QDebug>
#include <QMap>

#include <algorithm>
#include <cmath>

namespace PDFClowne::Editing {

namespace {

double lineDominantFontSize(const PdfTextLine& line)
{
    if (line.runs.isEmpty()) return 12.0;
    double total = 0.0;
    for (const PdfTextRun& run : line.runs)
        total += run.fontSize;
    return total / line.runs.size();
}

QColor lineDominantColor(const PdfTextLine& line)
{
    if (line.runs.isEmpty()) return Qt::black;
    double r = 0, g = 0, b = 0;
    for (const PdfTextRun& run : line.runs) {
        r += run.color.red();
        g += run.color.green();
        b += run.color.blue();
    }
    const int n = line.runs.size();
    return QColor(static_cast<int>(r / n), static_cast<int>(g / n), static_cast<int>(b / n));
}

double colorDistance(const QColor& a, const QColor& b)
{
    const double dr = a.red() - b.red();
    const double dg = a.green() - b.green();
    const double db = a.blue() - b.blue();
    return std::sqrt(dr * dr + dg * dg + db * db);
}

QRectF uniteAll(const QList<QRectF>& rects)
{
    if (rects.isEmpty()) return {};
    QRectF result = rects.first();
    for (const QRectF& r : rects)
        result = result.united(r);
    return result;
}

} // namespace

QList<PdfTextBlock> TextBlockBuilder::buildBlocks(const QList<PdfTextRun>& runs, int pageNumber)
{
    const QList<PdfTextLine> lines = groupRunsIntoLines(runs);
    return groupLinesIntoBlocks(lines, pageNumber);
}

QList<PdfTextLine> TextBlockBuilder::groupRunsIntoLines(const QList<PdfTextRun>& runs)
{
    if (runs.isEmpty()) return {};

    // Sort top-of-page first: in PDF Y-up space that means descending bboxPdf.top()
    // bboxPdf.top() = QRectF::y() = lower PDF Y edge (near baseline / descent)
    // Larger PDF Y = nearer to top of page
    QList<PdfTextRun> sorted = runs;
    std::sort(sorted.begin(), sorted.end(), [](const PdfTextRun& a, const PdfTextRun& b) {
        return a.bboxPdf.top() > b.bboxPdf.top();
    });

    QList<PdfTextLine> lines;
    QList<PdfTextRun> current;
    double currentBaseline = 0.0;
    double currentFontSize = 0.0;

    auto flushLine = [&]() {
        if (current.isEmpty()) return;
        std::sort(current.begin(), current.end(), [](const PdfTextRun& a, const PdfTextRun& b) {
            return a.bboxPdf.left() < b.bboxPdf.left();
        });
        PdfTextLine line;
        line.runs = current;
        double baselineSum = 0.0;
        QList<QRectF> bboxes;
        for (const PdfTextRun& r : current) {
            baselineSum += r.bboxPdf.top();
            bboxes.append(r.bboxPdf);
        }
        line.baseline = baselineSum / current.size();
        line.bboxPdf = uniteAll(bboxes);
        lines.append(line);
        current.clear();
    };

    for (const PdfTextRun& run : sorted) {
        if (current.isEmpty()) {
            currentBaseline = run.bboxPdf.top();
            currentFontSize = std::max(run.fontSize, 1.0);
            current.append(run);
        } else {
            const double tolerance = PDFClowne::Heuristics::LINE_BASELINE_TOL_RATIO * currentFontSize;
            if (std::abs(run.bboxPdf.top() - currentBaseline) <= tolerance) {
                const int n = current.size();
                currentBaseline = (currentBaseline * n + run.bboxPdf.top()) / (n + 1);
                currentFontSize = (currentFontSize * n + std::max(run.fontSize, 1.0)) / (n + 1);
                current.append(run);
            } else {
                flushLine();
                currentBaseline = run.bboxPdf.top();
                currentFontSize = std::max(run.fontSize, 1.0);
                current.append(run);
            }
        }
    }
    flushLine();

    return lines;
}

QList<PdfTextBlock> TextBlockBuilder::groupLinesIntoBlocks(const QList<PdfTextLine>& lines,
                                                           int pageNumber)
{
    if (lines.isEmpty()) return {};

    QList<PdfTextBlock> blocks;
    PdfTextBlock current;
    current.pageNumber = pageNumber;
    current.lines.append(lines.first());

    for (int i = 1; i < lines.size(); ++i) {
        const PdfTextLine& prev = lines[i - 1];
        const PdfTextLine& line = lines[i];

        const double prevFs = lineDominantFontSize(prev);
        const double curFs = lineDominantFontSize(line);

        // Baseline-to-baseline distance (prev is above in PDF Y-up, so prev.baseline > line.baseline)
        const double leading = prev.baseline - line.baseline;
        const double leadingRatio = prevFs > 0.0 ? leading / prevFs : 999.0;

        const bool leadingOk = leadingRatio >= PDFClowne::Heuristics::BLOCK_LEADING_RATIO_MIN
            && leadingRatio <= PDFClowne::Heuristics::BLOCK_LEADING_RATIO_MAX;

        const double fsRatio = prevFs > 0.0 ? curFs / prevFs : 0.0;
        const bool fontSizeOk = fsRatio >= PDFClowne::Heuristics::BLOCK_FONT_SIZE_RATIO_MIN
            && fsRatio <= PDFClowne::Heuristics::BLOCK_FONT_SIZE_RATIO_MAX;

        const bool colorOk =
            colorDistance(lineDominantColor(prev), lineDominantColor(line))
            < PDFClowne::Heuristics::BLOCK_COLOR_DISTANCE_MAX;

        const double overlapLeft = std::max(prev.bboxPdf.left(), line.bboxPdf.left());
        const double overlapRight = std::min(prev.bboxPdf.right(), line.bboxPdf.right());
        const double overlap = std::max(0.0, overlapRight - overlapLeft);
        const double minWidth = std::min(prev.bboxPdf.width(), line.bboxPdf.width());
        const bool overlapOk =
            minWidth <= 0.0 || (overlap / minWidth) >= PDFClowne::Heuristics::BLOCK_HORIZ_OVERLAP_MIN;

        if (leadingOk && fontSizeOk && colorOk && overlapOk) {
            current.lines.append(line);
        } else {
            finalizeBlock(current);
            blocks.append(current);
            current = PdfTextBlock{};
            current.pageNumber = pageNumber;
            current.lines.append(line);
        }
    }

    if (!current.lines.isEmpty()) {
        finalizeBlock(current);
        blocks.append(current);
    }

    return blocks;
}

void TextBlockBuilder::finalizeBlock(PdfTextBlock& block)
{
    if (block.lines.isEmpty()) return;

    QList<QRectF> lineBboxes;
    QMap<QString, double> fontWeight;
    double wFontSize = 0.0, wR = 0.0, wG = 0.0, wB = 0.0, totalW = 0.0;
    bool anyEditable = false;

    for (const PdfTextLine& line : block.lines) {
        lineBboxes.append(line.bboxPdf);
        for (const PdfTextRun& run : line.runs) {
            const double w = std::max(1.0, static_cast<double>(run.text.length()));
            fontWeight[run.fontName] += w;
            wFontSize += run.fontSize * w;
            wR += run.color.red() * w;
            wG += run.color.green() * w;
            wB += run.color.blue() * w;
            totalW += w;
            if (run.isEditable) anyEditable = true;
        }
    }

    block.bboxPdf = uniteAll(lineBboxes);

    double bestW = 0.0;
    for (auto it = fontWeight.cbegin(); it != fontWeight.cend(); ++it) {
        if (it.value() > bestW) {
            bestW = it.value();
            block.dominantFontName = it.key();
        }
    }

    if (totalW > 0.0) {
        block.dominantFontSize = wFontSize / totalW;
        block.dominantColor = QColor(
            static_cast<int>(std::round(wR / totalW)),
            static_cast<int>(std::round(wG / totalW)),
            static_cast<int>(std::round(wB / totalW)));
    }

    if (block.lines.size() >= 2) {
        double spacingSum = 0.0;
        for (int i = 1; i < block.lines.size(); ++i)
            spacingSum += block.lines[i - 1].baseline - block.lines[i].baseline;
        block.lineSpacing = spacingSum / (block.lines.size() - 1);
    } else {
        block.lineSpacing = block.dominantFontSize * 1.2;
    }

    block.alignment = detectAlignment(block);
    block.isEditable = anyEditable;
    if (!anyEditable && !block.lines.isEmpty() && !block.lines.first().runs.isEmpty())
        block.nonEditableReason = block.lines.first().runs.first().nonEditableReason;

    block.blockId = QString("blk_p%1_x%2_y%3")
        .arg(block.pageNumber)
        .arg(static_cast<int>(block.bboxPdf.left()))
        .arg(static_cast<int>(block.bboxPdf.top()));
}

Qt::Alignment TextBlockBuilder::detectAlignment(const PdfTextBlock& block)
{
    if (block.lines.size() < 2 || block.bboxPdf.width() <= 0.0)
        return Qt::AlignLeft;

    const double tol = PDFClowne::Heuristics::ALIGNMENT_TOLERANCE_RATIO
        * std::max(block.dominantFontSize, 1.0);
    const double bLeft = block.bboxPdf.left();
    const double bRight = block.bboxPdf.right();
    const double bCx = (bLeft + bRight) * 0.5;

    bool allLeft = true, allRight = true, allCenter = true;

    for (const PdfTextLine& line : block.lines) {
        if (std::abs(line.bboxPdf.left() - bLeft) > tol) allLeft = false;
        if (std::abs(line.bboxPdf.right() - bRight) > tol) allRight = false;
        const double cx = (line.bboxPdf.left() + line.bboxPdf.right()) * 0.5;
        if (std::abs(cx - bCx) > tol) allCenter = false;
    }

    if (allLeft) return Qt::AlignLeft;
    if (allRight) return Qt::AlignRight;
    if (allCenter) return Qt::AlignHCenter;
    return Qt::AlignJustify;
}

} // namespace PDFClowne::Editing
