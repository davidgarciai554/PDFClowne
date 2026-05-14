#include "PdfGlyphRunModel.h"

#include <QJsonDocument>

#include <algorithm>
#include <cmath>

namespace PDFClowne::Editing {
namespace {

QJsonArray pointToJson(const QPointF &point)
{
    return QJsonArray{point.x(), point.y()};
}

QJsonArray quadToJson(const QPolygonF &quad)
{
    QJsonArray array;
    for (const QPointF &point : quad)
        array.append(pointToJson(point));
    return array;
}

QJsonObject rectToJson(const QRectF &rect)
{
    QJsonObject object;
    object.insert(QStringLiteral("x"), rect.x());
    object.insert(QStringLiteral("y"), rect.y());
    object.insert(QStringLiteral("width"), rect.width());
    object.insert(QStringLiteral("height"), rect.height());
    object.insert(QStringLiteral("x0"), rect.left());
    object.insert(QStringLiteral("y0"), rect.top());
    object.insert(QStringLiteral("x1"), rect.right());
    object.insert(QStringLiteral("y1"), rect.bottom());
    return object;
}

QJsonArray transformToJson(const QTransform &transform)
{
    return QJsonArray{
        transform.m11(),
        transform.m12(),
        transform.m21(),
        transform.m22(),
        transform.dx(),
        transform.dy()
    };
}

bool samePoint(const QPointF &left, const QPointF &right)
{
    return qFuzzyCompare(left.x(), right.x()) && qFuzzyCompare(left.y(), right.y());
}

} // namespace

QJsonObject glyphToJson(const PdfGlyph &glyph)
{
    QJsonObject object;
    object.insert(QStringLiteral("pageIndex"), glyph.pageIndex);
    object.insert(QStringLiteral("blockIndex"), glyph.blockIndex);
    object.insert(QStringLiteral("lineIndex"), glyph.lineIndex);
    object.insert(QStringLiteral("spanIndex"), glyph.spanIndex);
    const char32_t scalar = static_cast<char32_t>(glyph.unicode);
    object.insert(QStringLiteral("unicode"), static_cast<int>(glyph.unicode));
    object.insert(QStringLiteral("text"), glyph.unicode ? QString::fromUcs4(&scalar, 1) : QString());
    object.insert(QStringLiteral("originalGid"), glyph.originalGid);
    object.insert(QStringLiteral("origin"), pointToJson(glyph.origin));
    object.insert(QStringLiteral("quad"), quadToJson(glyph.quad));
    object.insert(QStringLiteral("bbox"), rectToJson(glyph.bbox));
    object.insert(QStringLiteral("advance"), pointToJson(glyph.advance));
    object.insert(QStringLiteral("fontName"), glyph.fontName);
    object.insert(QStringLiteral("fontResourceKey"), glyph.fontResourceKey);
    object.insert(QStringLiteral("fontSize"), glyph.fontSize);
    object.insert(QStringLiteral("fillColor"), glyph.fillColor.name(QColor::HexArgb));
    object.insert(QStringLiteral("bold"), glyph.bold);
    object.insert(QStringLiteral("italic"), glyph.italic);
    object.insert(QStringLiteral("underline"), glyph.underline);
    object.insert(QStringLiteral("strikeout"), glyph.strikeout);
    object.insert(QStringLiteral("filled"), glyph.filled);
    object.insert(QStringLiteral("stroked"), glyph.stroked);
    object.insert(QStringLiteral("clipped"), glyph.clipped);
    object.insert(QStringLiteral("renderMode"), glyph.renderMode);
    object.insert(QStringLiteral("horizontalScale"), glyph.horizontalScale);
    object.insert(QStringLiteral("wmode"), glyph.wmode);
    object.insert(QStringLiteral("bidiLevel"), glyph.bidiLevel);
    object.insert(QStringLiteral("direction"), pointToJson(glyph.direction));
    object.insert(QStringLiteral("trm"), transformToJson(glyph.trm));
    return object;
}

QJsonObject runToJson(const PdfRun &run)
{
    QJsonArray glyphArray;
    for (const PdfGlyph &glyph : run.glyphs)
        glyphArray.append(glyphToJson(glyph));

    QJsonObject object;
    object.insert(QStringLiteral("glyphs"), glyphArray);
    object.insert(QStringLiteral("plainText"), run.plainText);
    object.insert(QStringLiteral("fontResourceKey"), run.fontResourceKey);
    object.insert(QStringLiteral("fillColor"), run.fillColor.name(QColor::HexArgb));
    object.insert(QStringLiteral("bold"), run.bold);
    object.insert(QStringLiteral("italic"), run.italic);
    object.insert(QStringLiteral("underline"), run.underline);
    object.insert(QStringLiteral("strikeout"), run.strikeout);
    object.insert(QStringLiteral("filled"), run.filled);
    object.insert(QStringLiteral("stroked"), run.stroked);
    object.insert(QStringLiteral("clipped"), run.clipped);
    object.insert(QStringLiteral("renderMode"), run.renderMode);
    object.insert(QStringLiteral("wmode"), run.wmode);
    object.insert(QStringLiteral("bidiLevel"), run.bidiLevel);
    object.insert(QStringLiteral("direction"), pointToJson(run.direction));
    object.insert(QStringLiteral("trm"), transformToJson(run.trm));
    object.insert(QStringLiteral("bbox"), rectToJson(unionGlyphBoxes(run.glyphs, 0, run.glyphs.size())));
    return object;
}

QJsonObject editableRegionToJson(const PdfEditableRegion &region)
{
    QJsonObject object;
    object.insert(QStringLiteral("glyphStart"), region.glyphRange.first);
    object.insert(QStringLiteral("glyphCount"), region.glyphRange.second);
    object.insert(QStringLiteral("unionQuad"), quadToJson(region.unionQuad));
    object.insert(QStringLiteral("baselineStart"), pointToJson(region.baselineStart));
    object.insert(QStringLiteral("baselineEnd"), pointToJson(region.baselineEnd));
    object.insert(QStringLiteral("box"), rectToJson(region.box));
    object.insert(QStringLiteral("script"), region.script);
    object.insert(QStringLiteral("language"), region.language);
    return object;
}

QJsonArray runsToJson(const QVector<PdfRun> &runs)
{
    QJsonArray array;
    for (const PdfRun &run : runs)
        array.append(runToJson(run));
    return array;
}

QJsonArray regionsToJson(const QVector<PdfEditableRegion> &regions)
{
    QJsonArray array;
    for (const PdfEditableRegion &region : regions)
        array.append(editableRegionToJson(region));
    return array;
}

bool runCanAppendGlyph(const PdfRun &run, const PdfGlyph &glyph)
{
    if (run.glyphs.isEmpty())
        return true;

    const PdfGlyph &first = run.glyphs.constFirst();
    return run.fontResourceKey == glyph.fontResourceKey &&
           qFuzzyCompare(first.fontSize, glyph.fontSize) &&
           run.fillColor == glyph.fillColor &&
           run.bold == glyph.bold &&
           run.italic == glyph.italic &&
           run.underline == glyph.underline &&
           run.strikeout == glyph.strikeout &&
           run.filled == glyph.filled &&
           run.stroked == glyph.stroked &&
           run.clipped == glyph.clipped &&
           run.renderMode == glyph.renderMode &&
           run.wmode == glyph.wmode &&
           run.bidiLevel == glyph.bidiLevel &&
           samePoint(run.direction, glyph.direction);
}

QRectF unionGlyphBoxes(const QVector<PdfGlyph> &glyphs, int first, int count)
{
    if (glyphs.isEmpty() || count <= 0 || first < 0 || first >= glyphs.size())
        return {};

    QRectF rect = glyphs.at(first).bbox;
    const int end = std::min(static_cast<int>(glyphs.size()), first + count);
    for (int i = first + 1; i < end; ++i)
        rect = rect.united(glyphs.at(i).bbox);
    return rect;
}

} // namespace PDFClowne::Editing
