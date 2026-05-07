#include "TextBlockBuilder.h"

#include <QColor>
#include <QRectF>
#include <QString>

#include <iostream>

using namespace PDFClowne::Editing;

namespace {

// Helpers — bboxPdf uses QRectF(left, pdfLowerY, width, height)
// where pdfLowerY is the lower PDF Y coordinate (baseline area).
PdfTextRun makeRun(const QString& text,
                   double left, double pdfLowerY, double width, double height,
                   double fontSize = 12.0,
                   const QString& fontName = QStringLiteral("Helvetica"),
                   QColor color = Qt::black)
{
    PdfTextRun run;
    run.text = text;
    run.bboxPdf = QRectF(left, pdfLowerY, width, height);
    run.fontSize = fontSize;
    run.fontName = fontName;
    run.color = color;
    run.isEditable = true;
    return run;
}

bool check(bool cond, const char* msg)
{
    if (!cond) std::cerr << "FAIL: " << msg << '\n';
    return cond;
}

// --- Tests ---

bool testEmpty()
{
    TextBlockBuilder b;
    const auto blocks = b.buildBlocks({}, 0);
    return check(blocks.isEmpty(), "empty input must produce 0 blocks");
}

bool testSingleRun()
{
    TextBlockBuilder b;
    QList<PdfTextRun> runs = { makeRun("Hello", 50, 700, 80, 12) };
    const auto blocks = b.buildBlocks(runs, 0);

    bool ok = true;
    ok &= check(blocks.size() == 1, "single run: expected 1 block");
    ok &= check(blocks[0].lines.size() == 1, "single run: expected 1 line");
    ok &= check(blocks[0].lines[0].runs.size() == 1, "single run: expected 1 run in line");
    ok &= check(blocks[0].lines[0].runs[0].text == QStringLiteral("Hello"),
                "single run: text mismatch");
    return ok;
}

bool testTwoRunsSameBaseline()
{
    // Two runs at the same baseline → 1 line, 1 block, sorted by X
    TextBlockBuilder b;
    QList<PdfTextRun> runs = {
        makeRun("World", 120, 700, 80, 12),   // intentionally added second
        makeRun("Hello", 30,  700, 80, 12),
    };
    const auto blocks = b.buildBlocks(runs, 0);

    bool ok = true;
    ok &= check(blocks.size() == 1, "2 runs same baseline: expected 1 block");
    ok &= check(blocks[0].lines.size() == 1, "2 runs same baseline: expected 1 line");
    ok &= check(blocks[0].lines[0].runs.size() == 2, "2 runs same baseline: expected 2 runs");
    // Runs must be sorted by X
    if (blocks[0].lines[0].runs.size() == 2) {
        ok &= check(blocks[0].lines[0].runs[0].text == QStringLiteral("Hello"),
                    "2 runs same baseline: first run should be leftmost");
        ok &= check(blocks[0].lines[0].runs[1].text == QStringLiteral("World"),
                    "2 runs same baseline: second run should be rightmost");
    }
    return ok;
}

bool testTwoLinesNormalSpacing()
{
    // 12pt font, 14.4pt leading → ratio = 1.2 → within [0.9, 1.8] → same block
    TextBlockBuilder b;
    QList<PdfTextRun> runs = {
        makeRun("Line one",  50, 700.0, 200, 12),
        makeRun("Line two",  50, 685.6, 200, 12),
    };
    const auto blocks = b.buildBlocks(runs, 1);

    bool ok = true;
    ok &= check(blocks.size() == 1, "normal spacing: expected 1 block");
    if (!blocks.isEmpty())
        ok &= check(blocks[0].lines.size() == 2, "normal spacing: expected 2 lines");
    return ok;
}

bool testTwoLinesBigGap()
{
    // 200pt gap for 12pt font → ratio = 16.7 → > 1.8 → different blocks
    TextBlockBuilder b;
    QList<PdfTextRun> runs = {
        makeRun("Heading",   50, 700, 200, 12),
        makeRun("Paragraph", 50, 500, 200, 12),
    };
    const auto blocks = b.buildBlocks(runs, 0);

    bool ok = true;
    ok &= check(blocks.size() == 2, "big gap: expected 2 blocks");
    if (blocks.size() == 2) {
        ok &= check(blocks[0].lines.size() == 1, "big gap: block 0 should have 1 line");
        ok &= check(blocks[1].lines.size() == 1, "big gap: block 1 should have 1 line");
    }
    return ok;
}

bool testNonOverlappingColumnsProduceSeparateBlocks()
{
    // Two columns at non-overlapping X ranges, interleaved baselines
    // (so each line comes from exactly one column)
    // Col 1: X [50, 250], baselines at 700, 685
    // Col 2: X [350, 550], baselines at 693, 678 (interleaved so lines don't merge)
    TextBlockBuilder b;
    QList<PdfTextRun> runs = {
        makeRun("C1L1", 50,  700.0, 200, 12),
        makeRun("C2L1", 350, 693.0, 200, 12),
        makeRun("C1L2", 50,  685.0, 200, 12),
        makeRun("C2L2", 350, 678.0, 200, 12),
    };
    const auto blocks = b.buildBlocks(runs, 0);

    // Baselines differ by 7pt which is > tolerance (0.3*12=3.6), so each run is its own line.
    // Consecutive lines alternate between col1 and col2 with small leading → may group together.
    // The overlap check: col1 [50,250] vs col2 [350,550] → zero overlap → different blocks.
    bool ok = check(blocks.size() >= 2,
                    "non-overlapping columns: expected at least 2 blocks");
    return ok;
}

bool testBlockId()
{
    TextBlockBuilder b;
    const auto blocks = b.buildBlocks({ makeRun("X", 100, 400, 50, 12) }, 3);
    bool ok = !blocks.isEmpty();
    if (ok)
        ok &= check(!blocks[0].blockId.isEmpty(), "block must have non-empty blockId");
    return ok;
}

bool testDominantFontName()
{
    TextBlockBuilder b;
    // Two runs: "Arial" has more characters → should be dominant
    QList<PdfTextRun> runs = {
        makeRun("Hi",    50, 700, 40, 12, 12.0, QStringLiteral("Arial")),
        makeRun("World!",100, 700, 80, 12, 12.0, QStringLiteral("Helvetica")),
    };
    const auto blocks = b.buildBlocks(runs, 0);
    bool ok = !blocks.isEmpty();
    if (ok)
        ok &= check(blocks[0].dominantFontName == QStringLiteral("Helvetica"),
                    "dominant font should be Helvetica (more chars)");
    return ok;
}

} // namespace

int main()
{
    bool pass = true;

    pass &= testEmpty();
    pass &= testSingleRun();
    pass &= testTwoRunsSameBaseline();
    pass &= testTwoLinesNormalSpacing();
    pass &= testTwoLinesBigGap();
    pass &= testNonOverlappingColumnsProduceSeparateBlocks();
    pass &= testBlockId();
    pass &= testDominantFontName();

    if (pass) {
        std::cout << "TextBlockBuilderTest: all tests passed\n";
        return 0;
    }
    return 1;
}
