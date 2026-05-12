#pragma once

#include "../text/PdfGlyphRunModel.h"

#include <QPolygonF>
#include <QRectF>
#include <QString>
#include <QVector>

namespace PDFClowne::Editing {

struct PdfTextEditOperation {
    QString id;
    int pageIndex = -1;
    int regionIndex = -1;

    QString originalText;
    QString replacementText;

    QVector<PdfRun> replacementRuns;
    QVector<QPolygonF> redactionQuads;
    QRectF dirtyRect;

    bool committed = false;
};

} // namespace PDFClowne::Editing
