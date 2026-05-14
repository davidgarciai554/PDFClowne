#pragma once

#include "PdfFontResolver.h"
#include "PdfGlyphRunModel.h"

#include <QByteArray>
#include <QColor>
#include <QPointF>
#include <QRectF>
#include <QString>
#include <QVector>

namespace PDFClowne::Editing {

struct PdfDetectedTextStyle {
    QString fontFamily;
    QString fontFaceName;
    QString fontResourceKey;
    qreal fontSize = 12.0;
    qreal effectiveFontSize = 12.0;
    QColor fillColor = Qt::black;
    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool strikeout = false;
    bool filled = true;
    bool stroked = false;
    bool clipped = false;
    int renderMode = 0;
    int wmode = 0;
    int bidiLevel = 0;
    QPointF direction = QPointF(1.0, 0.0);
    qreal horizontalScale = 1.0;
};

struct PdfEditLaidOutGlyph {
    uint glyphId = 0;
    uint unicode = 0;
    int textIndex = 0;
    QPointF origin;
    QPointF advance;
    QPointF offset;
    QRectF visualBox;
};

struct PdfEditCaret {
    int index = 0;
    QPointF top;
    QPointF bottom;
    qreal x = 0.0;
    QRectF visualBox;
};

struct PdfEditTextLayoutResult {
    QString text;
    PdfDetectedTextStyle style;
    QVector<PdfEditLaidOutGlyph> glyphs;
    QVector<PdfEditCaret> carets;
    QRectF visualBox;
    QPointF baselineStart;
    QPointF baselineEnd;
    qreal naturalWidth = 0.0;
    qreal fittedWidth = 0.0;
    qreal horizontalScale = 1.0;
    bool usedEmbeddedFont = false;
    bool usedFallbackFont = false;
    bool valid = false;
    QString debugFontName;
    QString debugReason;
    QByteArray fontProgram;
    QString fontName;
};

class PdfEditTextLayout {
public:
    PdfEditTextLayoutResult layoutRun(const PdfRun &sourceRun,
                                      const QString &replacementText,
                                      const QByteArray &fontProgram,
                                      const QString &debugFontName,
                                      const PdfDetectedTextStyle &requestedStyle = {}) const;

    static PdfDetectedTextStyle detectedStyleFromRun(const PdfRun &run);
};

qreal effectiveVisualFontSize(const PdfRun &run);

} // namespace PDFClowne::Editing
