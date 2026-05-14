#pragma once

#include "PdfFontWritePlan.h"
#include "../text/PdfGlyphRunModel.h"

#include <QByteArray>
#include <QPointF>
#include <QRectF>
#include <QString>
#include <QVector>

namespace PDFClowne::Editing {

class PdfContentWriter {
public:
    // Owns the generated PDF operators for destructive text replacement:
    // BT, Tf, Tm, Tj, and TJ.
    struct StreamBuildResult {
        QByteArray contentStream;
        QVector<int> glyphIds;
        QString fontResourceKey;
        bool usesTJ = false;
    };

    StreamBuildResult buildReplacementTextStream(const PdfRun &run,
                                                 const QString &newText,
                                                 const PdfFontWritePlan &fontPlan,
                                                 qreal pageHeight,
                                                 const QString &editId = QString()) const;
    QByteArray buildRedactionCoverStream(const PdfRun &run,
                                         qreal pageHeight,
                                         const QString &editId = QString()) const;

    static QPointF visualPointToPdfPoint(const QPointF &visualPoint, qreal pageHeight);
    static QPointF visualBaselineToPdfBaseline(const QPointF &visualBaseline, qreal pageHeight);
    static QRectF visualRectToPdfRect(const QRectF &visualRect, qreal pageHeight);
    static QRectF expandVisualRedactionRect(const QRectF &visualRect, qreal fontSize);

private:
    static QByteArray escapedPdfBytes(const QByteArray &text);
};

} // namespace PDFClowne::Editing
