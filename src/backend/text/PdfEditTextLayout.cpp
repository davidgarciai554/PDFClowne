#include "PdfEditTextLayout.h"

#include <hb.h>

#include <algorithm>
#include <cmath>

namespace PDFClowne::Editing {
namespace {

QByteArray runTextUtf8(const QString &text)
{
    return text.toUtf8();
}

hb_script_t scriptForUnicode(uint unicode)
{
    if ((unicode >= 0x0590 && unicode <= 0x05FF) ||
        (unicode >= 0xFB1D && unicode <= 0xFB4E))
        return HB_SCRIPT_HEBREW;
    if ((unicode >= 0x0600 && unicode <= 0x08FF) ||
        (unicode >= 0xFB50 && unicode <= 0xFEFC))
        return HB_SCRIPT_ARABIC;
    if (unicode >= 0x3040 && unicode <= 0x9FFF)
        return HB_SCRIPT_HAN;
    return HB_SCRIPT_LATIN;
}

hb_language_t languageForScript(hb_script_t script)
{
    switch (script) {
    case HB_SCRIPT_ARABIC:  return hb_language_from_string("ar", 2);
    case HB_SCRIPT_HEBREW:  return hb_language_from_string("he", 2);
    case HB_SCRIPT_HAN:     return hb_language_from_string("zh", 2);
    default:                return hb_language_from_string("und", 3);
    }
}

struct ShapedGlyph {
    uint glyphId = 0;
    uint cluster = 0;
    QPointF offset;
    QPointF advance;
};

QVector<ShapedGlyph> shapeText(const PdfRun &run, const QString &text, const QByteArray &fontProgram)
{
    QVector<ShapedGlyph> shaped;
    if (text.isEmpty() || fontProgram.isEmpty())
        return shaped;

    hb_blob_t *blob = hb_blob_create(fontProgram.constData(),
                                     static_cast<unsigned int>(fontProgram.size()),
                                     HB_MEMORY_MODE_READONLY,
                                     nullptr,
                                     nullptr);
    hb_face_t *face = hb_face_create(blob, 0);
    hb_font_t *font = hb_font_create(face);
    const unsigned int upem = std::max(1u, hb_face_get_upem(face));
    hb_font_set_scale(font, static_cast<int>(upem), static_cast<int>(upem));

    hb_buffer_t *buffer = hb_buffer_create();
    const QByteArray utf8 = runTextUtf8(text);
    hb_buffer_add_utf8(buffer, utf8.constData(), utf8.size(), 0, utf8.size());
    const uint firstUnicode = text.isEmpty() ? 0u : static_cast<uint>(text.at(0).unicode());
    const hb_script_t hbScript = scriptForUnicode(firstUnicode);
    hb_buffer_set_direction(buffer, run.bidiLevel % 2 ? HB_DIRECTION_RTL : HB_DIRECTION_LTR);
    hb_buffer_set_script(buffer, hbScript);
    hb_buffer_set_language(buffer, languageForScript(hbScript));
    hb_shape(font, buffer, nullptr, 0);

    unsigned int glyphCount = 0;
    hb_glyph_info_t *infos = hb_buffer_get_glyph_infos(buffer, &glyphCount);
    hb_glyph_position_t *positions = hb_buffer_get_glyph_positions(buffer, &glyphCount);
    shaped.reserve(static_cast<int>(glyphCount));

    for (unsigned int i = 0; i < glyphCount; ++i) {
        ShapedGlyph glyph;
        glyph.glyphId = infos[i].codepoint;
        glyph.cluster = infos[i].cluster;
        glyph.offset = QPointF(static_cast<qreal>(positions[i].x_offset) / upem,
                               -static_cast<qreal>(positions[i].y_offset) / upem);
        glyph.advance = QPointF(static_cast<qreal>(positions[i].x_advance) / upem,
                                -static_cast<qreal>(positions[i].y_advance) / upem);
        shaped.append(glyph);
    }

    hb_buffer_destroy(buffer);
    hb_font_destroy(font);
    hb_face_destroy(face);
    hb_blob_destroy(blob);
    return shaped;
}

QVector<ShapedGlyph> fallbackShapeText(const PdfRun &run, const QString &text, qreal fontSize)
{
    QVector<ShapedGlyph> shaped;
    if (text.isEmpty())
        return shaped;

    const QRectF sourceBox = unionGlyphBoxes(run.glyphs, 0, run.glyphs.size()).normalized();
    qreal averageAdvance = fontSize * 0.55;
    if (!run.glyphs.isEmpty() && sourceBox.width() > 0.0)
        averageAdvance = sourceBox.width() / std::max(1, static_cast<int>(run.glyphs.size()));

    shaped.reserve(static_cast<int>(text.size()));
    for (int i = 0; i < static_cast<int>(text.size()); ++i) {
        const PdfGlyph *sourceGlyph = !run.glyphs.isEmpty()
            ? &run.glyphs.at(std::min(i, static_cast<int>(run.glyphs.size()) - 1))
            : nullptr;
        const qreal sourceAdvance = sourceGlyph && std::abs(sourceGlyph->advance.x()) > 0.001
            ? std::abs(sourceGlyph->advance.x())
            : averageAdvance;
        ShapedGlyph glyph;
        glyph.glyphId = static_cast<uint>(std::max(0, static_cast<int>(text.at(i).unicode())));
        glyph.cluster = static_cast<uint>(i);
        glyph.advance = QPointF(sourceAdvance / std::max<qreal>(1.0, fontSize), 0.0);
        shaped.append(glyph);
    }
    return shaped;
}

int textIndexForCluster(const QString &text, uint cluster)
{
    const QByteArray utf8 = text.toUtf8();
    const int byteIndex = std::max(0, std::min(static_cast<int>(cluster), static_cast<int>(utf8.size())));
    return QString::fromUtf8(utf8.constData(), byteIndex).size();
}

} // namespace

qreal effectiveVisualFontSize(const PdfRun &run)
{
    if (run.glyphs.isEmpty())
        return 12.0;

    return std::max<qreal>(1.0, run.glyphs.constFirst().fontSize);
}

PdfDetectedTextStyle PdfEditTextLayout::detectedStyleFromRun(const PdfRun &run)
{
    PdfDetectedTextStyle style;
    if (run.glyphs.isEmpty())
        return style;

    const PdfGlyph &first = run.glyphs.constFirst();
    style.fontFamily = first.fontName;
    style.fontFaceName = first.fontName;
    style.fontResourceKey = run.fontResourceKey;
    style.fontSize = std::max<qreal>(1.0, first.fontSize);
    style.effectiveFontSize = run.effectiveFontSize > 0.0 ? run.effectiveFontSize : effectiveVisualFontSize(run);
    style.fillColor = run.fillColor.isValid() ? run.fillColor : first.fillColor;
    style.bold = run.bold;
    style.italic = run.italic;
    style.underline = run.underline;
    style.strikeout = run.strikeout;
    style.filled = run.filled;
    style.stroked = run.stroked;
    style.clipped = run.clipped;
    style.renderMode = run.renderMode;
    style.wmode = run.wmode;
    style.bidiLevel = run.bidiLevel;
    style.direction = run.direction;
    style.horizontalScale = run.horizontalScale > 0.0 ? run.horizontalScale : 1.0;
    return style;
}

PdfEditTextLayoutResult PdfEditTextLayout::layoutRun(const PdfRun &sourceRun,
                                                     const QString &replacementText,
                                                     const QByteArray &fontProgram,
                                                     const QString &debugFontName,
                                                     const PdfDetectedTextStyle &requestedStyle) const
{
    PdfEditTextLayoutResult result;
    result.text = replacementText;
    result.debugFontName = debugFontName;
    result.fontProgram = fontProgram;
    result.fontName = debugFontName;

    if (sourceRun.glyphs.isEmpty() || replacementText.isEmpty()) {
        result.debugReason = QStringLiteral("empty-source-or-text");
        return result;
    }

    const bool hasRequestedStyle = !requestedStyle.fontResourceKey.isEmpty()
        || !requestedStyle.fontFamily.isEmpty()
        || !requestedStyle.fontFaceName.isEmpty();
    PdfDetectedTextStyle style = hasRequestedStyle
        ? requestedStyle
        : detectedStyleFromRun(sourceRun);

    const QRectF sourceBox = unionGlyphBoxes(sourceRun.glyphs, 0, sourceRun.glyphs.size()).normalized();
    const PdfGlyph &first = sourceRun.glyphs.constFirst();

    style.fontSize = std::max<qreal>(1.0, first.fontSize);
    if (style.effectiveFontSize <= 0.0)
        style.effectiveFontSize = effectiveVisualFontSize(sourceRun);
    style.direction = sourceRun.direction;
    style.wmode = sourceRun.wmode;
    style.bidiLevel = sourceRun.bidiLevel;
    style.fontResourceKey = sourceRun.fontResourceKey;
    if (style.fontFamily.isEmpty())
        style.fontFamily = first.fontName;
    if (style.fontFaceName.isEmpty())
        style.fontFaceName = first.fontName;

    result.style = style;
    result.baselineStart = first.origin;
    result.usedEmbeddedFont = !fontProgram.isEmpty();
    result.usedFallbackFont = fontProgram.isEmpty();

    QVector<ShapedGlyph> shaped = shapeText(sourceRun, replacementText, fontProgram);
    if (shaped.isEmpty()) {
        shaped = fallbackShapeText(sourceRun, replacementText, style.effectiveFontSize);
        result.usedEmbeddedFont = false;
        result.usedFallbackFont = true;
        result.debugReason = QStringLiteral("fallback-layout");
    }

    qreal naturalWidth = 0.0;
    for (const ShapedGlyph &glyph : shaped)
        naturalWidth += glyph.advance.x() * style.effectiveFontSize;

    const qreal sourceWidth = sourceBox.width();
    qreal horizontalScale = 1.0;
    if (!result.usedFallbackFont && naturalWidth > 0.0 && sourceWidth > 0.0) {
        const qreal ratio = sourceWidth / naturalWidth;
        if (ratio >= 0.70 && ratio <= 1.45)
            horizontalScale = ratio;
    }

    style.horizontalScale = horizontalScale;
    result.style = style;
    result.naturalWidth = naturalWidth;
    result.horizontalScale = horizontalScale;
    result.fittedWidth = naturalWidth * horizontalScale;

    QPointF pen = result.baselineStart;
    const qreal ascent = sourceBox.height() * 0.78;
    const qreal descent = sourceBox.height() * 0.22;

    result.carets.reserve(shaped.size() + 1);
    PdfEditCaret firstCaret;
    firstCaret.index = 0;
    firstCaret.x = pen.x();
    firstCaret.top = QPointF(pen.x(), sourceBox.top());
    firstCaret.bottom = QPointF(pen.x(), sourceBox.bottom());
    firstCaret.visualBox = QRectF(QPointF(pen.x(), sourceBox.top()),
                                  QPointF(pen.x() + 1.0, sourceBox.bottom())).normalized();
    result.carets.append(firstCaret);

    result.glyphs.reserve(shaped.size());
    for (int i = 0; i < shaped.size(); ++i) {
        const ShapedGlyph &source = shaped.at(i);
        PdfEditLaidOutGlyph glyph;
        glyph.textIndex = textIndexForCluster(replacementText, source.cluster);
        glyph.glyphId = source.glyphId;
        glyph.unicode = glyph.textIndex < replacementText.size()
            ? static_cast<uint>(replacementText.at(glyph.textIndex).unicode())
            : 0u;
        glyph.offset = source.offset * style.effectiveFontSize;
        glyph.origin = pen + glyph.offset;
        glyph.advance = QPointF(source.advance.x() * style.effectiveFontSize * horizontalScale,
                                source.advance.y() * style.effectiveFontSize);
        glyph.visualBox = QRectF(QPointF(glyph.origin.x(), result.baselineStart.y() - ascent),
                                 QPointF(glyph.origin.x() + glyph.advance.x(), result.baselineStart.y() + descent)).normalized();
        result.glyphs.append(glyph);

        pen += glyph.advance;

        PdfEditCaret caret;
        caret.index = result.carets.size();
        caret.x = pen.x();
        caret.top = QPointF(pen.x(), sourceBox.top());
        caret.bottom = QPointF(pen.x(), sourceBox.bottom());
        caret.visualBox = QRectF(QPointF(pen.x(), sourceBox.top()),
                                 QPointF(pen.x() + 1.0, sourceBox.bottom())).normalized();
        result.carets.append(caret);
    }

    result.baselineEnd = pen;

    QRectF visualBox;
    bool ready = false;
    for (const PdfEditLaidOutGlyph &glyph : result.glyphs) {
        visualBox = ready ? visualBox.united(glyph.visualBox) : glyph.visualBox;
        ready = true;
    }

    if (!ready)
        visualBox = sourceBox;

    if (result.usedFallbackFont)
        visualBox.setRight(visualBox.right() + 1.0);
    visualBox.setTop(sourceBox.top());
    visualBox.setBottom(sourceBox.bottom());
    result.visualBox = visualBox.normalized();
    result.valid = true;
    return result;
}

} // namespace PDFClowne::Editing
