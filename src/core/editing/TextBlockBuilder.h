#pragma once

#include "PdfTextBlock.h"
#include "PdfTextLine.h"
#include "PdfTextRun.h"

#include <QList>

namespace PDFClowne::Editing {

class TextBlockBuilder {
public:
    QList<PdfTextBlock> buildBlocks(const QList<PdfTextRun>& runs, int pageNumber);

private:
    QList<PdfTextLine> groupRunsIntoLines(const QList<PdfTextRun>& runs);
    QList<PdfTextBlock> groupLinesIntoBlocks(const QList<PdfTextLine>& lines, int pageNumber);
    void finalizeBlock(PdfTextBlock& block);
    static Qt::Alignment detectAlignment(const PdfTextBlock& block);
};

} // namespace PDFClowne::Editing
