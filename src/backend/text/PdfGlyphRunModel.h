#pragma once

#include <QColor>
#include <QJsonArray>
#include <QJsonObject>
#include <QPair>
#include <QPointF>
#include <QPolygonF>
#include <QRectF>
#include <QString>
#include <QTransform>
#include <QVector>

namespace PDFClowne::Editing {

struct PdfGlyph {
    int pageIndex = -1;
    int blockIndex = -1;
    int lineIndex = -1;
    int spanIndex = -1;
    uint unicode = 0;
    int originalGid = 0;
    QPointF origin;
    QPolygonF quad;
    QRectF bbox;
    QPointF advance;
    QString fontName;
    QString fontResourceKey;
    qreal fontSize = 0.0;
    QColor fillColor = Qt::black;
    int wmode = 0;
    int bidiLevel = 0;
    QPointF direction = QPointF(1.0, 0.0);
    QTransform trm;
};

struct PdfRun {
    QVector<PdfGlyph> glyphs;
    QString plainText;
    QString fontResourceKey;
    QColor fillColor = Qt::black;
    int wmode = 0;
    int bidiLevel = 0;
    QPointF direction = QPointF(1.0, 0.0);
    QTransform trm;
};

struct PdfEditableRegion {
    QPair<int, int> glyphRange = {0, 0};
    QPolygonF unionQuad;
    QPointF baselineStart;
    QPointF baselineEnd;
    QRectF box;
    QString script = QStringLiteral("Zyyy");
    QString language = QStringLiteral("und");
};

struct PdfShapedGlyph {
    uint glyphId = 0;
    uint cluster = 0;
    QPointF offset;
    QPointF advance;
};

struct PdfShapedRun {
    QString fontResourceKey;
    QVector<PdfShapedGlyph> glyphs;
    QRectF dirtyRect;
};

QJsonObject glyphToJson(const PdfGlyph &glyph);
QJsonObject runToJson(const PdfRun &run);
QJsonObject editableRegionToJson(const PdfEditableRegion &region);
QJsonArray runsToJson(const QVector<PdfRun> &runs);
QJsonArray regionsToJson(const QVector<PdfEditableRegion> &regions);
bool runCanAppendGlyph(const PdfRun &run, const PdfGlyph &glyph);
QRectF unionGlyphBoxes(const QVector<PdfGlyph> &glyphs, int first, int count);

} // namespace PDFClowne::Editing

Q_DECLARE_METATYPE(PDFClowne::Editing::PdfGlyph)
Q_DECLARE_METATYPE(PDFClowne::Editing::PdfRun)
Q_DECLARE_METATYPE(PDFClowne::Editing::PdfEditableRegion)
