#include "PdfDocument.h"
#include "PdfEditableLayout.h"

#include <QBuffer>
#include <QByteArray>
#include <QColor>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QImage>
#include <QIODevice>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QStringList>
#include <QUrl>
#include <QVector>
#include <QRegularExpression>

#include <mupdf/fitz.h>
#include <mupdf/pdf.h>

#include <algorithm>
#include <cmath>

namespace {
constexpr float kRenderScale = 4.0f;
constexpr float kThumbnailScale = 0.30f;
using FontResourceMap = QHash<QString, QJsonObject>;

QString toLocalPath(const QString &source)
{
    if (source.startsWith(QLatin1String("file://"), Qt::CaseInsensitive))
        return QUrl(source).toLocalFile();
    return source;
}

QString displayNameForPath(const QString &path)
{
    const QFileInfo info(path);
    return info.fileName().isEmpty() ? path : info.fileName();
}

QString cleanedFontFamily(const QString &fontName)
{
    QString value = fontName.trimmed();
    const int subsetSeparator = value.indexOf(QLatin1Char('+'));
    if (subsetSeparator > 0)
        value = value.mid(subsetSeparator + 1);
    return value.isEmpty() ? QStringLiteral("Helvetica") : value;
}

QString fontSubsetPrefix(const QString &fontName)
{
    const int subsetSeparator = fontName.indexOf(QLatin1Char('+'));
    if (subsetSeparator <= 0)
        return {};
    return fontName.left(subsetSeparator);
}

QString ensurePdfSuffix(const QString &path)
{
    const QFileInfo fileInfo(path);
    if (fileInfo.suffix().compare(QLatin1String("pdf"), Qt::CaseInsensitive) == 0)
        return path;

    return path + QStringLiteral(".pdf");
}

QString tempPdfPathFor(const QString &targetPath)
{
    const QFileInfo targetInfo(targetPath);
    const QString basePath = targetInfo.absoluteDir().absoluteFilePath(
        targetInfo.completeBaseName() + QStringLiteral(".pdfclowne-save"));

    for (int attempt = 0; attempt < 1000; ++attempt) {
        const QString suffix = attempt == 0
            ? QStringLiteral(".tmp.pdf")
            : QStringLiteral(".%1.tmp.pdf").arg(attempt);
        const QString tempPath = basePath + suffix;
        if (!QFileInfo::exists(tempPath))
            return tempPath;
    }

    return {};
}

bool replaceFileWithBackup(const QString &sourcePath, const QString &replacementPath, QString *error)
{
    const QFileInfo sourceInfo(sourcePath);
    const QString backupPath = sourceInfo.absoluteDir().absoluteFilePath(
        sourceInfo.fileName() + QStringLiteral(".pdfclowne-backup"));

    QFile::remove(backupPath);
    if (!QFile::rename(sourcePath, backupPath)) {
        if (error)
            *error = QObject::tr("Could not prepare the original PDF for overwrite.");
        return false;
    }

    if (!QFile::rename(replacementPath, sourcePath)) {
        QFile::rename(backupPath, sourcePath);
        if (error)
            *error = QObject::tr("Could not replace the original PDF.");
        return false;
    }

    QFile::remove(backupPath);
    return true;
}

bool hasRotationChanges(const QVector<int> &rotations)
{
    for (int rotation : rotations) {
        if (rotation != 0)
            return true;
    }

    return false;
}

bool hasStructuralPageChanges(const QVector<int> &pageOrder, int pageCount)
{
    if (pageOrder.size() != pageCount)
        return true;

    for (int page = 0; page < pageCount; ++page) {
        if (pageOrder.at(page) != page)
            return true;
    }

    return false;
}

QVector<int> parseRotations(const QString &rotationsJson)
{
    QVector<int> rotations;
    const QJsonDocument document = QJsonDocument::fromJson(rotationsJson.toUtf8());
    if (!document.isArray())
        return rotations;

    const QJsonArray array = document.array();
    rotations.reserve(array.size());
    for (const QJsonValue &value : array) {
        int rotation = value.toInt(0) % 360;
        if (rotation < 0)
            rotation += 360;
        rotations.append(rotation);
    }

    return rotations;
}

QVector<int> parsePageOrder(const QString &pageOrderJson)
{
    QVector<int> pageOrder;
    const QJsonDocument document = QJsonDocument::fromJson(pageOrderJson.toUtf8());
    if (!document.isArray())
        return pageOrder;

    const QJsonArray array = document.array();
    pageOrder.reserve(array.size());
    for (const QJsonValue &value : array)
        pageOrder.append(value.toInt(-1));

    return pageOrder;
}

QJsonArray parseAnnotationEdits(const QString &annotationsJson)
{
    const QJsonDocument document = QJsonDocument::fromJson(annotationsJson.toUtf8());
    if (!document.isArray())
        return {};

    return document.array();
}

bool pointInRect(const fz_rect &rect, const QPointF &point, float padding = 0.0f)
{
    return point.x() >= rect.x0 - padding && point.x() <= rect.x1 + padding &&
           point.y() >= rect.y0 - padding && point.y() <= rect.y1 + padding;
}

QString colorNameFromArgb(uint32_t argb)
{
    const int red = static_cast<int>((argb >> 16) & 0xff);
    const int green = static_cast<int>((argb >> 8) & 0xff);
    const int blue = static_cast<int>(argb & 0xff);
    return QColor(red, green, blue).name(QColor::HexRgb).toUpper();
}

QString defaultAnnotationColor()
{
    return QStringLiteral("#1C1C2E");
}

QColor colorFromJson(const QJsonObject &object, const QString &key, const QColor &fallback)
{
    const QColor parsed(object.value(key).toString());
    return parsed.isValid() ? parsed : fallback;
}

QColor colorFromString(const QString &value, const QColor &fallback)
{
    const QColor parsed(value);
    return parsed.isValid() ? parsed : fallback;
}

void colorToPdfComponents(const QColor &color, float components[3])
{
    const QColor rgb = color.toRgb();
    components[0] = static_cast<float>(rgb.redF());
    components[1] = static_cast<float>(rgb.greenF());
    components[2] = static_cast<float>(rgb.blueF());
}

QString standardPdfFontName(const QString &fontFamily)
{
    const QString normalized = fontFamily.trimmed().toLower();
    if (normalized.contains(QStringLiteral("cour")))
        return QStringLiteral("Cour");
    if (normalized.contains(QStringLiteral("times")) || normalized.contains(QStringLiteral("tiro")) ||
        normalized.contains(QStringLiteral("serif")))
        return QStringLiteral("TiRo");
    return QStringLiteral("Helv");
}

QString cssFontFamily(const QString &fontFamily)
{
    const QString normalized = fontFamily.trimmed();
    if (normalized.compare(QStringLiteral("Cour"), Qt::CaseInsensitive) == 0 ||
        normalized.contains(QStringLiteral("cour"), Qt::CaseInsensitive))
        return QStringLiteral("Courier");
    if (normalized.compare(QStringLiteral("TiRo"), Qt::CaseInsensitive) == 0 ||
        normalized.contains(QStringLiteral("times"), Qt::CaseInsensitive) ||
        normalized.contains(QStringLiteral("serif"), Qt::CaseInsensitive))
        return QStringLiteral("Times New Roman");
    return QStringLiteral("Helvetica");
}

QString richTextStyle(const QString &fontFamily,
                      double fontSize,
                      const QColor &color,
                      bool bold,
                      bool italic,
                      bool underline)
{
    QStringList styles;
    styles.append(QStringLiteral("font-family:%1").arg(cssFontFamily(fontFamily)));
    styles.append(QStringLiteral("font-size:%1pt").arg(fontSize, 0, 'f', 2));
    styles.append(QStringLiteral("color:%1").arg(color.name(QColor::HexRgb)));
    if (bold)
        styles.append(QStringLiteral("font-weight:bold"));
    if (italic)
        styles.append(QStringLiteral("font-style:italic"));
    if (underline)
        styles.append(QStringLiteral("text-decoration:underline"));
    return styles.join(QLatin1Char(';')) + QLatin1Char(';');
}

QString richTextContents(const QString &text)
{
    QString escaped = text.toHtmlEscaped();
    escaped.replace(QStringLiteral("\r\n"), QStringLiteral("\n"));
    escaped.replace(QLatin1Char('\r'), QLatin1Char('\n'));
    escaped.replace(QLatin1Char('\n'), QStringLiteral("<br/>"));
    return QStringLiteral("<body><p>%1</p></body>").arg(escaped);
}

double jsonNumber(const QJsonObject &object, const QString &key, double fallback);
fz_rect rectFromJson(const QJsonObject &object, const fz_rect &fallback);
fz_point pointFromJson(const QJsonValue &value);
QJsonObject rectToJson(const fz_rect &rect);
QJsonArray pointToJson(const fz_point &point);
QJsonArray quadPathToJson(const fz_quad &quad);

int textBlockExtractionFlags()
{
    return FZ_STEXT_PRESERVE_SPANS |
           FZ_STEXT_COLLECT_STYLES |
           FZ_STEXT_PRESERVE_WHITESPACE |
           FZ_STEXT_ACCURATE_BBOXES |
           FZ_STEXT_ACCURATE_ASCENDERS |
           FZ_STEXT_ACCURATE_SIDE_BEARINGS;
}

QString blockKeyForRect(int pageIndex, const fz_rect &rect)
{
    return QStringLiteral("%1:%2:%3:%4:%5")
        .arg(pageIndex)
        .arg(rect.x0, 0, 'f', 2)
        .arg(rect.y0, 0, 'f', 2)
        .arg(rect.x1, 0, 'f', 2)
        .arg(rect.y1, 0, 'f', 2);
}

QString stableTextElementId(int pageIndex, const fz_rect &rect, const QString &text)
{
    QByteArray seed;
    seed.append(QByteArray::number(pageIndex));
    seed.append('|');
    seed.append(QByteArray::number(rect.x0, 'f', 2));
    seed.append('|');
    seed.append(QByteArray::number(rect.y0, 'f', 2));
    seed.append('|');
    seed.append(QByteArray::number(rect.x1, 'f', 2));
    seed.append('|');
    seed.append(QByteArray::number(rect.y1, 'f', 2));
    seed.append('|');
    seed.append(text.left(160).toUtf8());

    return QStringLiteral("text-%1-%2")
        .arg(pageIndex)
        .arg(QString::fromLatin1(QCryptographicHash::hash(seed, QCryptographicHash::Sha1).toHex().left(16)));
}

QString fontResourceNameForFace(const FontResourceMap *fontResources, const QString &fontFaceName)
{
    if (!fontResources)
        return {};

    QJsonObject font = fontResources->value(fontFaceName);
    if (font.isEmpty())
        font = fontResources->value(cleanedFontFamily(fontFaceName));
    return font.value(QStringLiteral("resourceName")).toString();
}

QJsonObject unknownFontMetadata(const QString &resourceName = {},
                                const QString &baseFont = {},
                                const QString &encoding = {})
{
    QJsonObject font;
    font.insert(QStringLiteral("resourceName"), resourceName);
    font.insert(QStringLiteral("subtype"), QStringLiteral("unknown"));
    font.insert(QStringLiteral("baseFont"), baseFont);
    font.insert(QStringLiteral("encoding"), encoding.isEmpty() ? QStringLiteral("unknown") : encoding);
    font.insert(QStringLiteral("objectNumber"), QJsonValue(QJsonValue::Null));
    return font;
}

QJsonObject fontMetadataForFace(const FontResourceMap *fontResources,
                                const QString &fontFaceName,
                                const QString &fontFamily)
{
    if (fontResources) {
        QJsonObject font = fontResources->value(fontFaceName);
        if (font.isEmpty())
            font = fontResources->value(fontFamily);
        if (!font.isEmpty())
            return font;
    }

    return unknownFontMetadata({}, fontFaceName);
}

QJsonObject fontMetadataFromStyle(const QJsonObject &style)
{
    QJsonObject font;
    font.insert(QStringLiteral("resourceName"), style.value(QStringLiteral("fontResourceName")).toString());
    font.insert(QStringLiteral("subtype"), style.value(QStringLiteral("fontSubtype")).toString(QStringLiteral("unknown")));
    font.insert(QStringLiteral("baseFont"), style.value(QStringLiteral("fontBaseFont")).toString(
                    style.value(QStringLiteral("fontFaceName")).toString()));
    font.insert(QStringLiteral("encoding"), style.value(QStringLiteral("fontEncoding")).toString(QStringLiteral("unknown")));
    font.insert(QStringLiteral("objectNumber"), style.value(QStringLiteral("fontObjectNumber")));
    return font;
}

QJsonObject unknownTextStateJson()
{
    QJsonObject textState;
    textState.insert(QStringLiteral("matrix"), QJsonArray());
    textState.insert(QStringLiteral("renderMode"), QStringLiteral("unknown"));
    textState.insert(QStringLiteral("charSpacing"), QStringLiteral("unknown"));
    textState.insert(QStringLiteral("wordSpacing"), QStringLiteral("unknown"));
    textState.insert(QStringLiteral("horizontalScale"), QStringLiteral("unknown"));
    textState.insert(QStringLiteral("rise"), QStringLiteral("unknown"));
    return textState;
}

QJsonObject fidelityMetadataFromStyle(const QJsonObject &style)
{
    const bool hasResourceName = !style.value(QStringLiteral("fontResourceName")).toString().isEmpty();

    QJsonArray reasons;
    reasons.append(QStringLiteral("structured-text-does-not-expose-original-text-state-operators"));
    reasons.append(QStringLiteral("font-encoding-not-verified-for-new-text"));
    reasons.append(hasResourceName
                       ? QStringLiteral("font-resource-name-inferred-from-page-resources")
                       : QStringLiteral("font-resource-name-unavailable"));

    QJsonObject fidelity;
    fidelity.insert(QStringLiteral("level"), hasResourceName ? QStringLiteral("partial") : QStringLiteral("low"));
    fidelity.insert(QStringLiteral("reasons"), reasons);
    fidelity.insert(QStringLiteral("fontReusable"), hasResourceName);
    fidelity.insert(QStringLiteral("canEncodeNewText"), false);
    return fidelity;
}

QJsonObject visualRunFromSpan(const QJsonObject &span, const fz_stext_line *line, const fz_point &baselineOrigin)
{
    QJsonObject run;
    run.insert(QStringLiteral("text"), span.value(QStringLiteral("text")).toString());
    run.insert(QStringLiteral("bbox"), span.value(QStringLiteral("bbox")));
    run.insert(QStringLiteral("baselineOrigin"), pointToJson(baselineOrigin));
    run.insert(QStringLiteral("dir"), line ? pointToJson(line->dir) : pointToJson(fz_make_point(1, 0)));
    run.insert(QStringLiteral("wmode"), line ? line->wmode : 0);
    run.insert(QStringLiteral("fontFamily"), span.value(QStringLiteral("fontFamily")));
    run.insert(QStringLiteral("fontFaceName"), span.value(QStringLiteral("fontFaceName")));
    run.insert(QStringLiteral("fontResourceName"), span.value(QStringLiteral("fontResourceName")));
    run.insert(QStringLiteral("fontSize"), span.value(QStringLiteral("fontSize")));
    run.insert(QStringLiteral("color"), span.value(QStringLiteral("color")));
    run.insert(QStringLiteral("bold"), span.value(QStringLiteral("bold")));
    run.insert(QStringLiteral("italic"), span.value(QStringLiteral("italic")));
    run.insert(QStringLiteral("underline"), span.value(QStringLiteral("underline")));
    run.insert(QStringLiteral("glyphs"), span.value(QStringLiteral("glyphs")));
    run.insert(QStringLiteral("start"), span.value(QStringLiteral("start")));
    run.insert(QStringLiteral("end"), span.value(QStringLiteral("end")));
    return run;
}

QJsonObject styleFromChar(fz_context *ctx, fz_stext_char *ch, const FontResourceMap *fontResources = nullptr)
{
    QJsonObject style;
    const QString fontFaceName = ch && ch->font
        ? QString::fromUtf8(fz_font_name(ctx, ch->font))
        : QStringLiteral("Helvetica");
    const QString fontName = ch && ch->font
        ? cleanedFontFamily(fontFaceName)
        : QStringLiteral("Helvetica");
    const bool isBold = ch && ((ch->flags & FZ_STEXT_BOLD) ||
                               (ch->font && fz_font_is_bold(ctx, ch->font)));
    const bool isItalic = ch && ch->font && fz_font_is_italic(ctx, ch->font);
    const bool isUnderline = ch && (ch->flags & FZ_STEXT_UNDERLINE);
    const bool isStrikeout = ch && (ch->flags & FZ_STEXT_STRIKEOUT);
    const QJsonObject fontMetadata = fontMetadataForFace(fontResources, fontFaceName, fontName);

    style.insert(QStringLiteral("fontFamily"), fontName);
    style.insert(QStringLiteral("fontFaceName"), fontFaceName);
    style.insert(QStringLiteral("fontSubsetPrefix"), fontSubsetPrefix(fontFaceName));
    style.insert(QStringLiteral("fontResourceName"), fontMetadata.value(QStringLiteral("resourceName")).toString());
    style.insert(QStringLiteral("fontSubtype"), fontMetadata.value(QStringLiteral("subtype")));
    style.insert(QStringLiteral("fontBaseFont"), fontMetadata.value(QStringLiteral("baseFont")));
    style.insert(QStringLiteral("fontEncoding"), fontMetadata.value(QStringLiteral("encoding")));
    style.insert(QStringLiteral("fontObjectNumber"), fontMetadata.value(QStringLiteral("objectNumber")));
    style.insert(QStringLiteral("fontSize"), std::max(6.0f, ch ? ch->size : 12.0f));
    style.insert(QStringLiteral("color"), colorNameFromArgb(ch ? ch->argb : 0xff1c1c2e));
    style.insert(QStringLiteral("argb"), static_cast<double>(ch ? ch->argb : 0xff1c1c2e));
    style.insert(QStringLiteral("bold"), isBold);
    style.insert(QStringLiteral("italic"), isItalic);
    style.insert(QStringLiteral("underline"), isUnderline);
    style.insert(QStringLiteral("strikeout"), isStrikeout);
    style.insert(QStringLiteral("synthetic"), ch && (ch->flags & FZ_STEXT_SYNTHETIC));
    style.insert(QStringLiteral("filled"), !ch || (ch->flags & FZ_STEXT_FILLED));
    style.insert(QStringLiteral("stroked"), ch && (ch->flags & FZ_STEXT_STROKED));
    style.insert(QStringLiteral("clipped"), ch && (ch->flags & FZ_STEXT_CLIPPED));
    return style;
}

bool sameStyle(const QJsonObject &left, const QJsonObject &right)
{
    return left.value(QStringLiteral("fontFamily")) == right.value(QStringLiteral("fontFamily")) &&
           left.value(QStringLiteral("fontFaceName")) == right.value(QStringLiteral("fontFaceName")) &&
           left.value(QStringLiteral("fontResourceName")) == right.value(QStringLiteral("fontResourceName")) &&
           left.value(QStringLiteral("fontSize")) == right.value(QStringLiteral("fontSize")) &&
           left.value(QStringLiteral("color")) == right.value(QStringLiteral("color")) &&
           left.value(QStringLiteral("bold")) == right.value(QStringLiteral("bold")) &&
           left.value(QStringLiteral("italic")) == right.value(QStringLiteral("italic")) &&
           left.value(QStringLiteral("underline")) == right.value(QStringLiteral("underline")) &&
           left.value(QStringLiteral("strikeout")) == right.value(QStringLiteral("strikeout"));
}

QJsonObject makeSpanObject(const QString &text, const QJsonObject &style)
{
    QJsonObject span = style;
    span.insert(QStringLiteral("text"), text);
    return span;
}

QJsonObject makeSpanObject(const QString &text,
                           const QJsonObject &style,
                           const QJsonArray &glyphs,
                           const fz_rect &bbox,
                           int start,
                           int end,
                           int lineIndex)
{
    QJsonObject span = makeSpanObject(text, style);
    span.insert(QStringLiteral("glyphs"), glyphs);
    span.insert(QStringLiteral("bbox"), rectToJson(bbox));
    span.insert(QStringLiteral("start"), start);
    span.insert(QStringLiteral("end"), end);
    span.insert(QStringLiteral("lineIndex"), lineIndex);
    span.insert(QStringLiteral("fidelity"), fidelityMetadataFromStyle(style));
    span.insert(QStringLiteral("font"), fontMetadataFromStyle(style));
    span.insert(QStringLiteral("textState"), unknownTextStateJson());
    return span;
}

QString runeFromCodepoint(int codepoint)
{
    if (codepoint <= 0 || codepoint > 0x10ffff)
        return {};
    uint unicode = static_cast<uint>(codepoint);
    return QString::fromUcs4(&unicode, 1);
}

void expandRect(fz_rect *target, const fz_rect &rect, bool *initialized)
{
    if (!target || !initialized)
        return;

    if (!*initialized) {
        *target = rect;
        *initialized = true;
        return;
    }

    target->x0 = std::min(target->x0, rect.x0);
    target->y0 = std::min(target->y0, rect.y0);
    target->x1 = std::max(target->x1, rect.x1);
    target->y1 = std::max(target->y1, rect.y1);
}

double projectedGlyphAdvance(fz_context *ctx, const fz_stext_line *line, const fz_stext_char *ch)
{
    if (!line || !ch)
        return 0.0;

    if (ch->next) {
        const double dx = static_cast<double>(ch->next->origin.x - ch->origin.x);
        const double dy = static_cast<double>(ch->next->origin.y - ch->origin.y);
        const double projected = dx * line->dir.x + dy * line->dir.y;
        if (std::isfinite(projected) && std::abs(projected) > 0.001)
            return std::abs(projected);
    }

    if (ch->font && ch->c > 0) {
        const int glyph = fz_encode_character(ctx, ch->font, ch->c);
        if (glyph > 0) {
            const float advance = fz_advance_glyph(ctx, ch->font, glyph, line->wmode) * ch->size;
            if (std::isfinite(advance) && advance > 0.0f)
                return advance;
        }
    }

    const fz_rect bbox = fz_rect_from_quad(ch->quad);
    return line->wmode == 0 ? std::max(0.0f, bbox.x1 - bbox.x0)
                            : std::max(0.0f, bbox.y1 - bbox.y0);
}

QJsonObject glyphFromChar(fz_context *ctx, const fz_stext_line *line, const fz_stext_char *ch, const QString &rune)
{
    QJsonObject glyph;
    glyph.insert(QStringLiteral("char"), rune);
    glyph.insert(QStringLiteral("unicode"), ch ? ch->c : 0);
    glyph.insert(QStringLiteral("bidiLevel"), ch ? ch->bidi : 0);
    glyph.insert(QStringLiteral("origin"), ch ? pointToJson(ch->origin) : pointToJson(fz_make_point(0, 0)));
    glyph.insert(QStringLiteral("quad"), ch ? quadPathToJson(ch->quad) : QJsonArray());
    glyph.insert(QStringLiteral("bbox"), ch ? rectToJson(fz_rect_from_quad(ch->quad)) : rectToJson(fz_make_rect(0, 0, 0, 0)));
    glyph.insert(QStringLiteral("advance"), projectedGlyphAdvance(ctx, line, ch));
    glyph.insert(QStringLiteral("fontSize"), std::max(6.0f, ch ? ch->size : 12.0f));
    glyph.insert(QStringLiteral("charStart"), -1);
    glyph.insert(QStringLiteral("charEnd"), -1);
    return glyph;
}

QJsonObject buildTextBlockJson(fz_context *ctx, int pageIndex, fz_stext_block *block, const FontResourceMap *fontResources = nullptr)
{
    QJsonObject item;
    item.insert(QStringLiteral("found"), true);
    item.insert(QStringLiteral("elementType"), QStringLiteral("text"));
    item.insert(QStringLiteral("editable"), true);
    item.insert(QStringLiteral("pageIndex"), pageIndex);
    item.insert(QStringLiteral("rect"), rectToJson(block->bbox));
    item.insert(QStringLiteral("originalRect"), rectToJson(block->bbox));
    item.insert(QStringLiteral("blockKey"), blockKeyForRect(pageIndex, block->bbox));
    item.insert(QStringLiteral("blockFlags"), block->u.t.flags);

    QString blockText;
    QJsonArray spans;
    QJsonArray lines;
    QJsonArray visualRuns;
    QJsonObject fallbackStyle = styleFromChar(ctx, nullptr, fontResources);
    bool styleInitialized = false;
    bool paragraphInitialized = false;
    int paragraphWritingMode = 0;
    fz_point paragraphDirection = fz_make_point(1, 0);
    int lineIndex = 0;
    int glyphCount = 0;

    for (fz_stext_line *line = block->u.t.first_line; line; line = line->next) {
        if (!paragraphInitialized) {
            paragraphWritingMode = line->wmode;
            paragraphDirection = line->dir;
            paragraphInitialized = true;
        }

        QJsonObject lineObject;
        QJsonArray lineSpans;
        QJsonArray lineVisualRuns;
        QString lineText;
        QString currentSpanText;
        QJsonObject currentStyle;
        QJsonArray currentGlyphs;
        fz_rect currentSpanRect = fz_make_rect(0, 0, 0, 0);
        bool currentSpanRectInitialized = false;
        int currentSpanStart = blockText.length();
        int spanIndex = 0;
        fz_point baselineOrigin = line->first_char ? line->first_char->origin : fz_make_point(line->bbox.x0, line->bbox.y1);

        auto flushCurrentSpan = [&]() {
            if (currentSpanText.isEmpty())
                return;

            const fz_rect spanRect = currentSpanRectInitialized ? currentSpanRect : line->bbox;
            QJsonObject span = makeSpanObject(currentSpanText,
                                              currentStyle,
                                              currentGlyphs,
                                              spanRect,
                                              currentSpanStart,
                                              currentSpanStart + currentSpanText.length(),
                                              lineIndex);
            span.insert(QStringLiteral("spanIndex"), spanIndex);
            lineSpans.append(span);
            spans.append(span);
            lineVisualRuns.append(visualRunFromSpan(span, line, baselineOrigin));
            ++spanIndex;

            currentSpanText.clear();
            currentGlyphs = QJsonArray();
            currentSpanRectInitialized = false;
        };

        for (fz_stext_char *ch = line->first_char; ch; ch = ch->next) {
            if (ch->c <= 0)
                continue;

            const QString rune = runeFromCodepoint(ch->c);
            if (rune.isEmpty())
                continue;

            const QJsonObject charStyle = styleFromChar(ctx, ch, fontResources);
            QJsonObject glyph = glyphFromChar(ctx, line, ch, rune);
            glyph.insert(QStringLiteral("charStart"), blockText.length());
            glyph.insert(QStringLiteral("charEnd"), blockText.length() + rune.length());
            const fz_rect glyphRect = fz_rect_from_quad(ch->quad);

            if (!styleInitialized) {
                fallbackStyle = charStyle;
                styleInitialized = true;
            }

            if (currentSpanText.isEmpty()) {
                currentStyle = charStyle;
                currentSpanStart = blockText.length();
            } else if (!sameStyle(currentStyle, charStyle)) {
                flushCurrentSpan();
                currentStyle = charStyle;
                currentSpanStart = blockText.length();
            }

            currentSpanText.append(rune);
            currentGlyphs.append(glyph);
            expandRect(&currentSpanRect, glyphRect, &currentSpanRectInitialized);
            lineText.append(rune);
            blockText.append(rune);
            ++glyphCount;
        }

        flushCurrentSpan();

        lineObject.insert(QStringLiteral("bbox"), rectToJson(line->bbox));
        lineObject.insert(QStringLiteral("wmode"), line->wmode);
        lineObject.insert(QStringLiteral("dir"), pointToJson(line->dir));
        lineObject.insert(QStringLiteral("baselineOrigin"), pointToJson(baselineOrigin));
        lineObject.insert(QStringLiteral("flags"), line->flags);
        lineObject.insert(QStringLiteral("text"), lineText);
        lineObject.insert(QStringLiteral("spans"), lineSpans);
        lineObject.insert(QStringLiteral("visualRuns"), lineVisualRuns);
        lineObject.insert(QStringLiteral("lineIndex"), lineIndex);
        lines.append(lineObject);

        QJsonObject visualLine;
        visualLine.insert(QStringLiteral("lineIndex"), lineIndex);
        visualLine.insert(QStringLiteral("text"), lineText);
        visualLine.insert(QStringLiteral("bbox"), rectToJson(line->bbox));
        visualLine.insert(QStringLiteral("baselineOrigin"), pointToJson(baselineOrigin));
        visualLine.insert(QStringLiteral("dir"), pointToJson(line->dir));
        visualLine.insert(QStringLiteral("wmode"), line->wmode);
        visualLine.insert(QStringLiteral("runs"), lineVisualRuns);
        visualRuns.append(visualLine);

        if (line->next) {
            blockText.append(QLatin1Char('\n'));
            QJsonObject newlineSpan = fallbackStyle;
            newlineSpan.insert(QStringLiteral("text"), QStringLiteral("\n"));
            newlineSpan.insert(QStringLiteral("start"), blockText.length() - 1);
            newlineSpan.insert(QStringLiteral("end"), blockText.length());
            newlineSpan.insert(QStringLiteral("lineIndex"), lineIndex);
            spans.append(newlineSpan);
        }

        ++lineIndex;
    }

    item.insert(QStringLiteral("text"), blockText);
    item.insert(QStringLiteral("originalText"), blockText);
    item.insert(QStringLiteral("stableElementId"), stableTextElementId(pageIndex, block->bbox, blockText));
    item.insert(QStringLiteral("spans"), spans);
    item.insert(QStringLiteral("lines"), lines);
    item.insert(QStringLiteral("visualRuns"), visualRuns);
    item.insert(QStringLiteral("lineCount"), lines.size());
    item.insert(QStringLiteral("glyphCount"), glyphCount);
    item.insert(QStringLiteral("writingMode"), paragraphWritingMode);
    item.insert(QStringLiteral("paragraphDirection"), pointToJson(paragraphDirection));
    item.insert(QStringLiteral("fontFamily"), fallbackStyle.value(QStringLiteral("fontFamily")));
    item.insert(QStringLiteral("fontFaceName"), fallbackStyle.value(QStringLiteral("fontFaceName")));
    item.insert(QStringLiteral("fontSubsetPrefix"), fallbackStyle.value(QStringLiteral("fontSubsetPrefix")));
    item.insert(QStringLiteral("fontResourceName"), fallbackStyle.value(QStringLiteral("fontResourceName")));
    item.insert(QStringLiteral("fontSize"), fallbackStyle.value(QStringLiteral("fontSize")));
    item.insert(QStringLiteral("color"), fallbackStyle.value(QStringLiteral("color")));
    item.insert(QStringLiteral("bold"), fallbackStyle.value(QStringLiteral("bold")));
    item.insert(QStringLiteral("italic"), fallbackStyle.value(QStringLiteral("italic")));
    item.insert(QStringLiteral("underline"), fallbackStyle.value(QStringLiteral("underline")));
    item.insert(QStringLiteral("fidelity"), fidelityMetadataFromStyle(fallbackStyle));
    item.insert(QStringLiteral("font"), fontMetadataFromStyle(fallbackStyle));
    item.insert(QStringLiteral("textState"), unknownTextStateJson());
    return item;
}

QJsonArray collectTextBlocks(fz_context *ctx, int pageIndex, fz_stext_page *textPage, const FontResourceMap *fontResources = nullptr)
{
    QJsonArray blocks;
    if (!textPage)
        return blocks;

    for (fz_stext_block *block = textPage->first_block; block; block = block->next) {
        if (block->type != FZ_STEXT_BLOCK_TEXT)
            continue;

        const QJsonObject item = buildTextBlockJson(ctx, pageIndex, block, fontResources);
        if (item.value(QStringLiteral("text")).toString().trimmed().isEmpty())
            continue;
        blocks.append(item);
    }

    return blocks;
}

QString pdfNameValue(fz_context *ctx, pdf_obj *object)
{
    if (!pdf_is_name(ctx, object))
        return QStringLiteral("unknown");
    return QString::fromUtf8(pdf_to_name(ctx, object));
}

QString pdfEncodingValue(fz_context *ctx, pdf_obj *fontObject)
{
    pdf_obj *encoding = pdf_dict_get(ctx, fontObject, PDF_NAME(Encoding));
    if (pdf_is_name(ctx, encoding))
        return QString::fromUtf8(pdf_to_name(ctx, encoding));
    if (pdf_is_dict(ctx, encoding))
        return QStringLiteral("dictionary");
    return QStringLiteral("unknown");
}

QJsonValue pdfObjectNumberValue(fz_context *ctx, pdf_obj *object)
{
    Q_UNUSED(ctx);
    Q_UNUSED(object);
    return QJsonValue(QJsonValue::Null);
}

QJsonObject fontResourceMetadata(fz_context *ctx, pdf_obj *fontObject, const QString &resourceName)
{
    QJsonObject metadata;
    metadata.insert(QStringLiteral("resourceName"), resourceName);
    metadata.insert(QStringLiteral("subtype"), pdfNameValue(ctx, pdf_dict_get(ctx, fontObject, PDF_NAME(Subtype))));
    metadata.insert(QStringLiteral("baseFont"), pdfNameValue(ctx, pdf_dict_get(ctx, fontObject, PDF_NAME(BaseFont))));
    metadata.insert(QStringLiteral("encoding"), pdfEncodingValue(ctx, fontObject));
    metadata.insert(QStringLiteral("objectNumber"), pdfObjectNumberValue(ctx, fontObject));
    return metadata;
}

void addFontResourceAlias(FontResourceMap *resources, const QString &fontName, const QJsonObject &fontMetadata)
{
    if (!resources || fontName.isEmpty() || fontMetadata.value(QStringLiteral("resourceName")).toString().isEmpty())
        return;

    resources->insert(fontName, fontMetadata);
    resources->insert(cleanedFontFamily(fontName), fontMetadata);
}

void addFontResourceFromObject(fz_context *ctx, FontResourceMap *resources, pdf_obj *fontObject, const QString &resourceName)
{
    if (!fontObject)
        return;

    QJsonObject metadata = fontResourceMetadata(ctx, fontObject, resourceName);
    pdf_obj *baseFont = pdf_dict_get(ctx, fontObject, PDF_NAME(BaseFont));
    if (pdf_is_name(ctx, baseFont))
        addFontResourceAlias(resources, QString::fromUtf8(pdf_to_name(ctx, baseFont)), metadata);

    pdf_obj *descendantFonts = pdf_dict_get(ctx, fontObject, PDF_NAME(DescendantFonts));
    if (pdf_is_array(ctx, descendantFonts) && pdf_array_len(ctx, descendantFonts) > 0) {
        pdf_obj *descendantFont = pdf_array_get(ctx, descendantFonts, 0);
        pdf_obj *descendantBaseFont = pdf_dict_get(ctx, descendantFont, PDF_NAME(BaseFont));
        if (pdf_is_name(ctx, descendantBaseFont)) {
            QJsonObject descendantMetadata = metadata;
            descendantMetadata.insert(QStringLiteral("baseFont"), QString::fromUtf8(pdf_to_name(ctx, descendantBaseFont)));
            addFontResourceAlias(resources, QString::fromUtf8(pdf_to_name(ctx, descendantBaseFont)), descendantMetadata);
        }
    }
}

FontResourceMap collectPageFontResources(fz_context *ctx, fz_document *doc, int pageIndex)
{
    FontResourceMap resources;
    pdf_document *pdfDoc = pdf_specifics(ctx, doc);
    if (!pdfDoc)
        return resources;

    pdf_obj *pageObj = pdf_lookup_page_obj(ctx, pdfDoc, pageIndex);
    pdf_obj *pageResources = pdf_dict_get_inheritable(ctx, pageObj, PDF_NAME(Resources));
    pdf_obj *fonts = pdf_dict_get(ctx, pageResources, PDF_NAME(Font));
    if (!fonts)
        return resources;

    const int fontCount = pdf_dict_len(ctx, fonts);
    for (int i = 0; i < fontCount; ++i) {
        pdf_obj *key = pdf_dict_get_key(ctx, fonts, i);
        pdf_obj *fontObject = pdf_dict_get_val(ctx, fonts, i);
        if (!pdf_is_name(ctx, key))
            continue;

        addFontResourceFromObject(ctx,
                                  &resources,
                                  fontObject,
                                  QString::fromUtf8(pdf_to_name(ctx, key)));
    }

    return resources;
}

QString fontFaceNameForStyle(const QString &fontFamily, bool bold, bool italic)
{
    const QString family = standardPdfFontName(fontFamily);
    if (family == QStringLiteral("Cour")) {
        if (bold && italic)
            return QStringLiteral("Courier-BoldOblique");
        if (bold)
            return QStringLiteral("Courier-Bold");
        if (italic)
            return QStringLiteral("Courier-Oblique");
        return QStringLiteral("Courier");
    }

    if (family == QStringLiteral("TiRo")) {
        if (bold && italic)
            return QStringLiteral("Times-BoldItalic");
        if (bold)
            return QStringLiteral("Times-Bold");
        if (italic)
            return QStringLiteral("Times-Italic");
        return QStringLiteral("Times-Roman");
    }

    if (bold && italic)
        return QStringLiteral("Helvetica-BoldOblique");
    if (bold)
        return QStringLiteral("Helvetica-Bold");
    if (italic)
        return QStringLiteral("Helvetica-Oblique");
    return QStringLiteral("Helvetica");
}

bool pdfLiteralLatin1EscapedString(const QString &text, QByteArray *escaped)
{
    if (!escaped)
        return false;

    escaped->clear();
    escaped->reserve(text.size());
    for (const QChar ch : text) {
        const ushort unicode = ch.unicode();
        if (unicode == '\r' || unicode == '\n')
            continue;
        if (unicode < 0x20 || unicode > 0xff || (unicode >= 0x7f && unicode < 0xa0))
            return false;

        const char byte = static_cast<char>(unicode & 0xff);
        if (byte == '\\' || byte == '(' || byte == ')')
            escaped->append('\\');
        escaped->append(byte);
    }
    return true;
}

QString sanitizedPdfResourceName(const QString &value, const QString &fallback)
{
    QString sanitized;
    const QString source = value.isEmpty() ? fallback : value;
    sanitized.reserve(source.size());

    for (const QChar ch : source) {
        if (ch.isLetterOrNumber() || ch == QLatin1Char('_'))
            sanitized.append(ch);
    }

    if (sanitized.isEmpty())
        sanitized = QStringLiteral("PCF_Font");
    if (sanitized.at(0).isDigit())
        sanitized.prepend(QStringLiteral("PCF_"));
    return sanitized;
}

pdf_obj *pageFontResource(fz_context *ctx, pdf_page *page, const QString &resourceName)
{
    if (!page || resourceName.isEmpty())
        return nullptr;

    pdf_obj *resources = pdf_page_resources(ctx, page);
    pdf_obj *fonts = resources ? pdf_dict_get(ctx, resources, PDF_NAME(Font)) : nullptr;
    if (!fonts)
        return nullptr;

    return pdf_dict_gets(ctx, fonts, resourceName.toUtf8().constData());
}

bool isBase14FontName(const QString &fontName)
{
    const QString cleaned = cleanedFontFamily(fontName);
    static const QStringList names = {
        QStringLiteral("Courier"),
        QStringLiteral("Courier-Bold"),
        QStringLiteral("Courier-Oblique"),
        QStringLiteral("Courier-BoldOblique"),
        QStringLiteral("Helvetica"),
        QStringLiteral("Helvetica-Bold"),
        QStringLiteral("Helvetica-Oblique"),
        QStringLiteral("Helvetica-BoldOblique"),
        QStringLiteral("Times-Roman"),
        QStringLiteral("Times-Bold"),
        QStringLiteral("Times-Italic"),
        QStringLiteral("Times-BoldItalic"),
        QStringLiteral("Symbol"),
        QStringLiteral("ZapfDingbats")
    };
    return names.contains(cleaned);
}

bool canReusePageFontResource(fz_context *ctx, pdf_obj *fontObject)
{
    if (!fontObject)
        return false;

    pdf_obj *subtype = pdf_dict_get(ctx, fontObject, PDF_NAME(Subtype));
    if (!pdf_is_name(ctx, subtype))
        return false;

    const QByteArray subtypeName = QByteArray(pdf_to_name(ctx, subtype));
    if (subtypeName != "Type1")
        return false;

    pdf_obj *baseFont = pdf_dict_get(ctx, fontObject, PDF_NAME(BaseFont));
    return pdf_is_name(ctx, baseFont) &&
           isBase14FontName(QString::fromUtf8(pdf_to_name(ctx, baseFont)));
}

QString firstReusableFontResource(fz_context *ctx, pdf_page *page, const QJsonObject &style, const QJsonObject &edit)
{
    const QStringList candidates = {
        style.value(QStringLiteral("fontResourceName")).toString(),
        edit.value(QStringLiteral("fontResourceName")).toString()
    };

    for (const QString &candidate : candidates) {
        if (candidate.isEmpty())
            continue;
        pdf_obj *fontObject = pageFontResource(ctx, page, candidate);
        if (canReusePageFontResource(ctx, fontObject))
            return candidate;
    }

    return {};
}

QString ensureBase14FontResource(fz_context *ctx,
                                 pdf_document *doc,
                                 pdf_obj *fonts,
                                 const QJsonObject &style,
                                 const QString &idPrefix,
                                 QHash<QString, QString> *resourceCache,
                                 QString *error)
{
    const QString fontFamily = style.value(QStringLiteral("fontFamily")).toString(QStringLiteral("Helv"));
    const bool bold = style.value(QStringLiteral("bold")).toBool(false);
    const bool italic = style.value(QStringLiteral("italic")).toBool(false);
    const QString faceName = fontFaceNameForStyle(fontFamily, bold, italic);
    const QString cacheKey = faceName;
    if (resourceCache && resourceCache->contains(cacheKey))
        return resourceCache->value(cacheKey);

    fz_font *font = fz_new_base14_font(ctx, faceName.toUtf8().constData());
    if (!font) {
        if (error)
            *error = QStringLiteral("MuPDF could not load a writable font.");
        return {};
    }

    pdf_obj *fontRef = pdf_add_simple_font(ctx, doc, font, PDF_SIMPLE_ENCODING_LATIN);
    const QString resourceName = sanitizedPdfResourceName(QStringLiteral("%1_%2").arg(idPrefix, faceName),
                                                          QStringLiteral("PCF_Font"));
    pdf_dict_puts(ctx, fonts, resourceName.toUtf8().constData(), fontRef);
    fz_drop_font(ctx, font);

    if (resourceCache)
        resourceCache->insert(cacheKey, resourceName);
    return resourceName;
}

double characterAdvanceForFont(fz_context *ctx, fz_font *font, QChar ch)
{
    if (!font)
        return 0.5;

    const int glyph = fz_encode_character(ctx, font, ch.unicode());
    if (glyph == 0 && !ch.isSpace())
        return 0.6;
    return std::max(0.0f, fz_advance_glyph(ctx, font, glyph, 0));
}

QStringList wrapTextForRect(fz_context *ctx, fz_font *font, const QString &text, double fontSize, double maxWidth)
{
    QStringList lines;
    if (text.isEmpty()) {
        lines.append(QString());
        return lines;
    }

    const double safeWidth = std::max(24.0, maxWidth);
    const QString normalized = text;
    const QStringList paragraphs = normalized.split(QLatin1Char('\n'));

    for (const QString &paragraph : paragraphs) {
        QString currentLine;
        double currentWidth = 0.0;

        const QStringList words = paragraph.split(QRegularExpression(QStringLiteral("(\\s+)")),
                                                  Qt::KeepEmptyParts);
        for (const QString &word : words) {
            double wordWidth = 0.0;
            for (const QChar ch : word)
                wordWidth += characterAdvanceForFont(ctx, font, ch) * fontSize;

            if (!currentLine.isEmpty() && currentWidth + wordWidth > safeWidth) {
                lines.append(currentLine.trimmed().isEmpty() ? currentLine : currentLine.trimmed());
                currentLine.clear();
                currentWidth = 0.0;
            }

            currentLine.append(word);
            currentWidth += wordWidth;
        }

        lines.append(currentLine);
    }

    return lines;
}

QStringList plainTextLines(const QString &text)
{
    QStringList lines = text.split(QLatin1Char('\n'));
    if (lines.isEmpty())
        lines.append(QString());
    return lines;
}

QJsonObject firstSpanStyle(const QJsonObject &lineObject, const QJsonObject &fallback)
{
    const QJsonArray spans = lineObject.value(QStringLiteral("spans")).toArray();
    if (!spans.isEmpty())
        return spans.first().toObject(fallback);
    return fallback;
}

fz_point runOriginFromSpan(const QJsonObject &spanObject, const QJsonObject &lineObject)
{
    const QJsonArray glyphs = spanObject.value(QStringLiteral("glyphs")).toArray();
    if (!glyphs.isEmpty())
        return pointFromJson(glyphs.first().toObject().value(QStringLiteral("origin")));
    return pointFromJson(lineObject.value(QStringLiteral("baselineOrigin")));
}

struct ReplacementTextRun {
    QString text;
    QJsonObject style;
    fz_point origin = fz_make_point(0, 0);
    fz_point dir = fz_make_point(1, 0);
    int wmode = 0;
};

QVector<ReplacementTextRun> replacementRunsFromEnrichedModel(const QJsonObject &edit)
{
    QVector<ReplacementTextRun> runs;
    const QJsonArray modelLines = edit.value(QStringLiteral("lines")).toArray();
    if (modelLines.isEmpty())
        return runs;

    const QStringList targetLines = plainTextLines(edit.value(QStringLiteral("text")).toString());
    if (targetLines.size() != modelLines.size())
        return runs;

    const QJsonObject fallbackStyle = edit;
    for (int lineIndex = 0; lineIndex < modelLines.size(); ++lineIndex) {
        const QJsonObject lineObject = modelLines.at(lineIndex).toObject();
        const QString targetLine = targetLines.at(lineIndex);
        if (targetLine.isEmpty())
            continue;

        const QString originalLine = lineObject.value(QStringLiteral("text")).toString();
        const QJsonArray spans = lineObject.value(QStringLiteral("spans")).toArray();
        const fz_point lineOrigin = pointFromJson(lineObject.value(QStringLiteral("baselineOrigin")));
        const fz_point lineDir = pointFromJson(lineObject.value(QStringLiteral("dir")));
        const int wmode = lineObject.value(QStringLiteral("wmode")).toInt(0);

        if (!spans.isEmpty() && targetLine.size() == originalLine.size()) {
            int cursor = 0;
            for (const QJsonValue &spanValue : spans) {
                const QJsonObject spanObject = spanValue.toObject();
                const int spanLength = spanObject.value(QStringLiteral("text")).toString().size();
                if (spanLength <= 0)
                    continue;

                ReplacementTextRun run;
                run.text = targetLine.mid(cursor, spanLength);
                run.style = spanObject;
                run.origin = runOriginFromSpan(spanObject, lineObject);
                run.dir = lineDir;
                run.wmode = wmode;
                if (!run.text.isEmpty())
                    runs.append(run);
                cursor += spanLength;
            }
            continue;
        }

        ReplacementTextRun run;
        run.text = targetLine;
        run.style = firstSpanStyle(lineObject, fallbackStyle);
        run.origin = lineOrigin;
        run.dir = lineDir;
        run.wmode = wmode;
        runs.append(run);
    }

    return runs;
}

QVector<ReplacementTextRun> fallbackReplacementRuns(fz_context *ctx,
                                                    fz_font *font,
                                                    const QJsonObject &edit,
                                                    const fz_rect &fitzRect)
{
    QVector<ReplacementTextRun> runs;
    const QString text = edit.value(QStringLiteral("text")).toString();
    const double fontSize = std::clamp(jsonNumber(edit, QStringLiteral("fontSize"), 12.0), 6.0, 144.0);
    const QStringList wrappedLines = wrapTextForRect(ctx, font, text, fontSize, fitzRect.x1 - fitzRect.x0);
    const double lineHeight = fontSize * 1.2;

    for (int i = 0; i < wrappedLines.size(); ++i) {
        if (wrappedLines.at(i).isEmpty())
            continue;

        ReplacementTextRun run;
        run.text = wrappedLines.at(i);
        run.style = edit;
        run.origin = fz_make_point(static_cast<float>(fitzRect.x0),
                                   static_cast<float>(fitzRect.y0 + fontSize + i * lineHeight));
        run.dir = fz_make_point(1, 0);
        run.wmode = 0;
        runs.append(run);
    }

    return runs;
}

fz_matrix textMatrixForRun(const ReplacementTextRun &run, const fz_matrix &pageCtm)
{
    // MuPDF's pdf_page_transform maps Fitz page coordinates back to PDF user space.
    const fz_point origin = fz_transform_point(run.origin, pageCtm);
    const fz_point dirPoint = fz_make_point(run.origin.x + run.dir.x, run.origin.y + run.dir.y);
    const fz_point transformedDirPoint = fz_transform_point(dirPoint, pageCtm);
    double dx = static_cast<double>(transformedDirPoint.x - origin.x);
    double dy = static_cast<double>(transformedDirPoint.y - origin.y);
    const double length = std::hypot(dx, dy);
    if (!std::isfinite(length) || length < 0.001) {
        dx = 1.0;
        dy = 0.0;
    } else {
        dx /= length;
        dy /= length;
    }

    const double a = dx;
    const double b = dy;
    const double c = run.wmode == 0 ? -dy : dy;
    const double d = run.wmode == 0 ? dx : -dx;
    return fz_make_matrix(static_cast<float>(a),
                          static_cast<float>(b),
                          static_cast<float>(c),
                          static_cast<float>(d),
                          origin.x,
                          origin.y);
}

pdf_obj *ensurePageResources(fz_context *ctx, pdf_document *doc, pdf_page *page)
{
    pdf_obj *resources = pdf_page_resources(ctx, page);
    if (resources)
        return resources;

    resources = pdf_new_dict(ctx, doc, 4);
    pdf_dict_put_drop(ctx, page->obj, PDF_NAME(Resources), resources);
    return pdf_page_resources(ctx, page);
}

QString appendReplacementTextStream(fz_context *ctx, pdf_document *doc, pdf_page *page, const QJsonObject &edit)
{
    const QString text = edit.value(QStringLiteral("text")).toString();
    if (text.isEmpty())
        return {};

    const fz_rect fitzRect = rectFromJson(edit, fz_make_rect(72, 72, 252, 120));
    const double fontSize = std::clamp(jsonNumber(edit, QStringLiteral("fontSize"), 12.0), 6.0, 144.0);
    const QString fallbackFaceName = fontFaceNameForStyle(edit.value(QStringLiteral("fontFamily")).toString(QStringLiteral("Helv")),
                                                          edit.value(QStringLiteral("bold")).toBool(false),
                                                          edit.value(QStringLiteral("italic")).toBool(false));

    fz_font *fallbackFont = fz_new_base14_font(ctx, fallbackFaceName.toUtf8().constData());
    if (!fallbackFont)
        return QStringLiteral("MuPDF could not load a writable font.");

    fz_buffer *streamBuffer = nullptr;
    QString error;

    fz_try(ctx)
    {
        pdf_obj *resources = ensurePageResources(ctx, doc, page);
        pdf_obj *fonts = pdf_dict_get(ctx, resources, PDF_NAME(Font));
        if (!fonts) {
            fonts = pdf_dict_put_dict(ctx, resources, PDF_NAME(Font), 4);
        }

        QVector<ReplacementTextRun> runs = replacementRunsFromEnrichedModel(edit);
        if (runs.isEmpty()) {
            qInfo().noquote() << QStringLiteral("[pdf-save] replaceTextBlock fallback=wrap reason=\"missing-or-structurally-changed-line-model\" id=\"%1\"")
                                     .arg(edit.value(QStringLiteral("id")).toString());
            runs = fallbackReplacementRuns(ctx, fallbackFont, edit, fitzRect);
        }

        fz_rect mediabox;
        fz_matrix pageCtm;
        pdf_page_transform(ctx, page, &mediabox, &pageCtm);

        streamBuffer = fz_new_buffer(ctx, 1024);
        fz_append_string(ctx, streamBuffer, "q\n");
        QHash<QString, QString> base14Resources;
        const QString idPrefix = sanitizedPdfResourceName(QStringLiteral("PCF_%1").arg(edit.value(QStringLiteral("id")).toString(QStringLiteral("block"))),
                                                          QStringLiteral("PCF_block"));

        for (const ReplacementTextRun &run : runs) {
            if (run.text.isEmpty())
                continue;

            QByteArray escaped;
            if (!pdfLiteralLatin1EscapedString(run.text, &escaped)) {
                error = QStringLiteral("Replacement text contains characters this PDF text composer cannot encode safely yet.");
                break;
            }

            QString fontResourceName = firstReusableFontResource(ctx, page, run.style, edit);
            if (fontResourceName.isEmpty()) {
                fontResourceName = ensureBase14FontResource(ctx,
                                                            doc,
                                                            fonts,
                                                            run.style,
                                                            idPrefix,
                                                            &base14Resources,
                                                            &error);
                if (!error.isEmpty())
                    break;
                qInfo().noquote() << QStringLiteral("[pdf-save] replaceTextBlock fallback=base14 reason=\"font-resource-unusable\" id=\"%1\"")
                                         .arg(edit.value(QStringLiteral("id")).toString());
            }

            const QColor color = colorFromJson(run.style, QStringLiteral("color"), QColor(defaultAnnotationColor()));
            const double runFontSize = std::clamp(jsonNumber(run.style, QStringLiteral("fontSize"), fontSize), 6.0, 144.0);
            const fz_matrix textMatrix = textMatrixForRun(run, pageCtm);

            fz_append_printf(ctx,
                             streamBuffer,
                             "%g %g %g rg\n",
                             color.redF(),
                             color.greenF(),
                             color.blueF());
            fz_append_string(ctx, streamBuffer, "BT\n");
            fz_append_printf(ctx, streamBuffer,
                             "/%s %g Tf\n%g %g %g %g %g %g Tm\n(%s) Tj\nET\n",
                             fontResourceName.toUtf8().constData(),
                             runFontSize,
                             textMatrix.a,
                             textMatrix.b,
                             textMatrix.c,
                             textMatrix.d,
                             textMatrix.e,
                             textMatrix.f,
                             escaped.constData());
        }
        if (!error.isEmpty())
            fz_throw(ctx, FZ_ERROR_GENERIC, error.toUtf8().constData());
        fz_append_string(ctx, streamBuffer, "Q\n");

        pdf_obj *newStream = pdf_add_stream(ctx, doc, streamBuffer, nullptr, 1);
        pdf_obj *contents = pdf_page_contents(ctx, page);
        if (!contents) {
            pdf_dict_put_drop(ctx, page->obj, PDF_NAME(Contents), newStream);
        } else if (pdf_is_array(ctx, contents)) {
            pdf_array_push_drop(ctx, contents, newStream);
        } else {
            pdf_obj *array = pdf_new_array(ctx, doc, 2);
            pdf_array_push(ctx, array, contents);
            pdf_array_push_drop(ctx, array, newStream);
            pdf_dict_put_drop(ctx, page->obj, PDF_NAME(Contents), array);
        }
    }
    fz_catch(ctx)
    {
        error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (streamBuffer)
        fz_drop_buffer(ctx, streamBuffer);
    if (fallbackFont)
        fz_drop_font(ctx, fallbackFont);
    return error;
}

void applyReplaceTextBlockEdit(fz_context *ctx, pdf_document *doc, pdf_page *page, const QJsonObject &edit)
{
    const fz_rect originalRect = rectFromJson(edit.value(QStringLiteral("originalRect")).toObject(),
                                              rectFromJson(edit, fz_make_rect(72, 72, 252, 120)));

    pdf_annot *annot = pdf_create_annot(ctx, page, PDF_ANNOT_REDACT);
    pdf_set_annot_rect(ctx, annot, originalRect);
    pdf_set_annot_flags(ctx, annot, PDF_ANNOT_IS_PRINT);
    pdf_set_annot_border_width(ctx, annot, 0);

    float fillColor[3] = { 1.0f, 1.0f, 1.0f };
    pdf_set_annot_interior_color(ctx, annot, 3, fillColor);
    pdf_update_annot(ctx, annot);

    pdf_redact_options redactOptions = {};
    redactOptions.black_boxes = 0;
    redactOptions.image_method = PDF_REDACT_IMAGE_NONE;
    redactOptions.line_art = PDF_REDACT_LINE_ART_NONE;
    redactOptions.text = PDF_REDACT_TEXT_REMOVE;
    pdf_apply_redaction(ctx, annot, &redactOptions);
    pdf_drop_annot(ctx, annot);

    const QString replacementError = appendReplacementTextStream(ctx, doc, page, edit);
    if (!replacementError.isEmpty())
        fz_throw(ctx, FZ_ERROR_GENERIC, replacementError.toUtf8().constData());
}

double jsonNumber(const QJsonObject &object, const QString &key, double fallback)
{
    const QJsonValue value = object.value(key);
    if (!value.isDouble())
        return fallback;
    return value.toDouble(fallback);
}

fz_rect rectFromJson(const QJsonObject &object, const fz_rect &fallback)
{
    const QJsonObject rect = object.value(QStringLiteral("rect")).toObject();
    if (rect.isEmpty())
        return fallback;

    const float x = static_cast<float>(jsonNumber(rect, QStringLiteral("x"), fallback.x0));
    const float y = static_cast<float>(jsonNumber(rect, QStringLiteral("y"), fallback.y0));
    const float width = std::max(1.0f, static_cast<float>(jsonNumber(rect, QStringLiteral("width"), fallback.x1 - fallback.x0)));
    const float height = std::max(1.0f, static_cast<float>(jsonNumber(rect, QStringLiteral("height"), fallback.y1 - fallback.y0)));
    return fz_make_rect(x, y, x + width, y + height);
}

fz_point pointFromJson(const QJsonValue &value)
{
    const QJsonArray point = value.toArray();
    if (point.size() < 2)
        return fz_make_point(0, 0);
    return fz_make_point(static_cast<float>(point.at(0).toDouble()),
                         static_cast<float>(point.at(1).toDouble()));
}

QVector<fz_quad> quadsFromJson(const QJsonArray &paths)
{
    QVector<fz_quad> quads;
    quads.reserve(paths.size());

    for (const QJsonValue &pathValue : paths) {
        const QJsonArray path = pathValue.toArray();
        if (path.size() < 4)
            continue;

        fz_quad quad;
        quad.ul = pointFromJson(path.at(0));
        quad.ur = pointFromJson(path.at(1));
        quad.lr = pointFromJson(path.at(2));
        quad.ll = pointFromJson(path.at(3));
        quads.append(quad);
    }

    return quads;
}

QVector<fz_point> pointsFromJson(const QJsonArray &pointsJson)
{
    QVector<fz_point> points;
    points.reserve(pointsJson.size());
    for (const QJsonValue &value : pointsJson) {
        const QJsonArray point = value.toArray();
        if (point.size() < 2)
            continue;
        points.append(fz_make_point(static_cast<float>(point.at(0).toDouble()),
                                    static_cast<float>(point.at(1).toDouble())));
    }
    return points;
}

fz_rect rectFromPoints(const QVector<fz_point> &points, const fz_rect &fallback)
{
    if (points.isEmpty())
        return fallback;

    fz_rect rect = fz_make_rect(points.first().x, points.first().y, points.first().x, points.first().y);
    for (const fz_point &point : points) {
        rect.x0 = std::min(rect.x0, point.x);
        rect.y0 = std::min(rect.y0, point.y);
        rect.x1 = std::max(rect.x1, point.x);
        rect.y1 = std::max(rect.y1, point.y);
    }
    rect.x0 -= 2.0f;
    rect.y0 -= 2.0f;
    rect.x1 += 2.0f;
    rect.y1 += 2.0f;
    return rect;
}

fz_rect unionQuadRects(const QVector<fz_quad> &quads)
{
    if (quads.isEmpty())
        return fz_make_rect(0, 0, 1, 1);

    fz_rect rect = fz_rect_from_quad(quads.first());
    for (int i = 1; i < quads.size(); ++i) {
        const fz_rect next = fz_rect_from_quad(quads.at(i));
        rect.x0 = std::min(rect.x0, next.x0);
        rect.y0 = std::min(rect.y0, next.y0);
        rect.x1 = std::max(rect.x1, next.x1);
        rect.y1 = std::max(rect.y1, next.y1);
    }
    return rect;
}

void applyFreeTextAnnotation(fz_context *ctx, pdf_page *page, const QJsonObject &edit)
{
    const QString text = edit.value(QStringLiteral("text")).toString();
    if (text.trimmed().isEmpty())
        return;

    const fz_rect defaultRect = fz_make_rect(72, 72, 252, 96);
    const fz_rect rect = rectFromJson(edit, defaultRect);
    const QString fontFamily = edit.value(QStringLiteral("fontFamily")).toString(QStringLiteral("Helv"));
    const double fontSize = std::clamp(jsonNumber(edit, QStringLiteral("fontSize"), 12.0), 6.0, 144.0);
    const QColor color = colorFromJson(edit, QStringLiteral("color"), QColor(defaultAnnotationColor()));
    const bool bold = edit.value(QStringLiteral("bold")).toBool(false);
    const bool italic = edit.value(QStringLiteral("italic")).toBool(false);
    const bool underline = edit.value(QStringLiteral("underline")).toBool(false);
    const double opacity = std::clamp(jsonNumber(edit, QStringLiteral("opacity"), 1.0), 0.05, 1.0);

    float colorComponents[3] = {};
    colorToPdfComponents(color, colorComponents);
    const QByteArray contents = text.toUtf8();
    const QByteArray font = standardPdfFontName(fontFamily).toUtf8();
    const QByteArray defaults = richTextStyle(fontFamily, fontSize, color, bold, italic, underline).toUtf8();
    const QByteArray rich = richTextContents(text).toUtf8();

    pdf_annot *annot = pdf_create_annot(ctx, page, PDF_ANNOT_FREE_TEXT);
    pdf_set_annot_rect(ctx, annot, rect);
    pdf_set_annot_flags(ctx, annot, PDF_ANNOT_IS_PRINT);
    pdf_set_annot_border_width(ctx, annot, 0);
    pdf_set_annot_opacity(ctx, annot, static_cast<float>(opacity));
    pdf_set_annot_default_appearance(ctx, annot, font.constData(), static_cast<float>(fontSize), 3, colorComponents);
    pdf_set_annot_rich_defaults(ctx, annot, defaults.constData());
    pdf_set_annot_rich_contents(ctx, annot, contents.constData(), rich.constData());
    pdf_update_annot(ctx, annot);
}

void applyHighlightAnnotation(fz_context *ctx, pdf_page *page, const QJsonObject &edit)
{
    QVector<fz_quad> quads = quadsFromJson(edit.value(QStringLiteral("quads")).toArray());
    if (quads.isEmpty()) {
        const fz_rect rect = rectFromJson(edit, fz_make_rect(72, 72, 144, 88));
        fz_quad quad;
        quad.ul = fz_make_point(rect.x0, rect.y0);
        quad.ur = fz_make_point(rect.x1, rect.y0);
        quad.lr = fz_make_point(rect.x1, rect.y1);
        quad.ll = fz_make_point(rect.x0, rect.y1);
        quads.append(quad);
    }

    const QColor color = colorFromJson(edit, QStringLiteral("color"), QColor(QStringLiteral("#FFE45A")));
    const double opacity = std::clamp(jsonNumber(edit, QStringLiteral("opacity"), 0.42), 0.05, 1.0);
    float colorComponents[3] = {};
    colorToPdfComponents(color, colorComponents);

    pdf_annot *annot = pdf_create_annot(ctx, page, PDF_ANNOT_HIGHLIGHT);
    pdf_set_annot_flags(ctx, annot, PDF_ANNOT_IS_PRINT);
    pdf_set_annot_rect(ctx, annot, unionQuadRects(quads));
    pdf_set_annot_quad_points(ctx, annot, quads.size(), quads.constData());
    pdf_set_annot_color(ctx, annot, 3, colorComponents);
    pdf_set_annot_opacity(ctx, annot, static_cast<float>(opacity));
    pdf_set_annot_contents(ctx, annot, "PDFClowne highlight");
    pdf_update_annot(ctx, annot);
}

void applyTextMarkupAnnotation(fz_context *ctx, pdf_page *page, const QJsonObject &edit, enum pdf_annot_type annotType)
{
    QVector<fz_quad> quads = quadsFromJson(edit.value(QStringLiteral("quads")).toArray());
    if (quads.isEmpty()) {
        const fz_rect rect = rectFromJson(edit, fz_make_rect(72, 72, 144, 88));
        fz_quad quad;
        quad.ul = fz_make_point(rect.x0, rect.y0);
        quad.ur = fz_make_point(rect.x1, rect.y0);
        quad.lr = fz_make_point(rect.x1, rect.y1);
        quad.ll = fz_make_point(rect.x0, rect.y1);
        quads.append(quad);
    }

    const QColor color = colorFromJson(edit, QStringLiteral("color"), QColor(defaultAnnotationColor()));
    const double opacity = std::clamp(jsonNumber(edit, QStringLiteral("opacity"), 0.80), 0.05, 1.0);
    float colorComponents[3] = {};
    colorToPdfComponents(color, colorComponents);

    pdf_annot *annot = pdf_create_annot(ctx, page, annotType);
    pdf_set_annot_flags(ctx, annot, PDF_ANNOT_IS_PRINT);
    pdf_set_annot_rect(ctx, annot, unionQuadRects(quads));
    pdf_set_annot_quad_points(ctx, annot, quads.size(), quads.constData());
    pdf_set_annot_color(ctx, annot, 3, colorComponents);
    pdf_set_annot_opacity(ctx, annot, static_cast<float>(opacity));
    pdf_set_annot_contents(ctx, annot, "PDFClowne text markup");
    pdf_update_annot(ctx, annot);
}

void applyStickyNoteAnnotation(fz_context *ctx, pdf_page *page, const QJsonObject &edit)
{
    const fz_rect rect = rectFromJson(edit, fz_make_rect(72, 72, 96, 96));
    const QColor color = colorFromJson(edit, QStringLiteral("color"), QColor(QStringLiteral("#FFE45A")));
    float colorComponents[3] = {};
    colorToPdfComponents(color, colorComponents);

    pdf_annot *annot = pdf_create_annot(ctx, page, PDF_ANNOT_TEXT);
    pdf_set_annot_rect(ctx, annot, rect);
    pdf_set_annot_flags(ctx, annot, PDF_ANNOT_IS_PRINT);
    pdf_set_annot_color(ctx, annot, 3, colorComponents);
    pdf_set_annot_contents(ctx, annot, edit.value(QStringLiteral("text")).toString(QStringLiteral("Nota")).toUtf8().constData());
    pdf_update_annot(ctx, annot);
}

void applyShapeAnnotation(fz_context *ctx, pdf_page *page, const QJsonObject &edit, enum pdf_annot_type annotType)
{
    const fz_rect rect = rectFromJson(edit, fz_make_rect(72, 72, 144, 120));
    const QColor color = colorFromJson(edit, QStringLiteral("color"), QColor(defaultAnnotationColor()));
    const double opacity = std::clamp(jsonNumber(edit, QStringLiteral("opacity"), 1.0), 0.05, 1.0);
    const double borderWidth = std::clamp(jsonNumber(edit, QStringLiteral("borderWidth"), 1.5), 0.25, 24.0);
    float colorComponents[3] = {};
    colorToPdfComponents(color, colorComponents);

    pdf_annot *annot = pdf_create_annot(ctx, page, annotType);
    pdf_set_annot_rect(ctx, annot, rect);
    pdf_set_annot_flags(ctx, annot, PDF_ANNOT_IS_PRINT);
    pdf_set_annot_color(ctx, annot, 3, colorComponents);
    pdf_set_annot_border_width(ctx, annot, static_cast<float>(borderWidth));
    pdf_set_annot_opacity(ctx, annot, static_cast<float>(opacity));
    pdf_update_annot(ctx, annot);
}

void applyInkAnnotation(fz_context *ctx, pdf_page *page, const QJsonObject &edit)
{
    QVector<fz_point> points = pointsFromJson(edit.value(QStringLiteral("points")).toArray());
    if (points.size() < 2) {
        const fz_rect rect = rectFromJson(edit, fz_make_rect(72, 72, 144, 120));
        points = { fz_make_point(rect.x0, rect.y0), fz_make_point(rect.x1, rect.y1) };
    }

    const QColor color = colorFromJson(edit, QStringLiteral("color"), QColor(defaultAnnotationColor()));
    const double opacity = std::clamp(jsonNumber(edit, QStringLiteral("opacity"), 1.0), 0.05, 1.0);
    const double borderWidth = std::clamp(jsonNumber(edit, QStringLiteral("borderWidth"), 1.8), 0.25, 24.0);
    float colorComponents[3] = {};
    colorToPdfComponents(color, colorComponents);
    const int count = points.size();

    pdf_annot *annot = pdf_create_annot(ctx, page, PDF_ANNOT_INK);
    pdf_set_annot_rect(ctx, annot, rectFromPoints(points, fz_make_rect(72, 72, 144, 120)));
    pdf_set_annot_flags(ctx, annot, PDF_ANNOT_IS_PRINT);
    pdf_set_annot_color(ctx, annot, 3, colorComponents);
    pdf_set_annot_border_width(ctx, annot, static_cast<float>(borderWidth));
    pdf_set_annot_opacity(ctx, annot, static_cast<float>(opacity));
    pdf_set_annot_ink_list(ctx, annot, 1, &count, points.constData());
    pdf_update_annot(ctx, annot);
}

void applyAnnotationEdits(fz_context *ctx, pdf_document *doc, int pageCount, const QJsonArray &annotationEdits)
{
    for (const QJsonValue &value : annotationEdits) {
        const QJsonObject edit = value.toObject();
        const int pageIndex = edit.value(QStringLiteral("pageIndex")).toInt(-1);
        if (pageIndex < 0 || pageIndex >= pageCount)
            continue;

        const QString type = edit.value(QStringLiteral("type")).toString();
        pdf_page *page = nullptr;

        fz_try(ctx)
        {
            page = pdf_load_page(ctx, doc, pageIndex);
            if (type == QStringLiteral("freeText"))
                applyFreeTextAnnotation(ctx, page, edit);
            else if (type == QStringLiteral("highlight"))
                applyHighlightAnnotation(ctx, page, edit);
            else if (type == QStringLiteral("underline"))
                applyTextMarkupAnnotation(ctx, page, edit, PDF_ANNOT_UNDERLINE);
            else if (type == QStringLiteral("strikeout"))
                applyTextMarkupAnnotation(ctx, page, edit, PDF_ANNOT_STRIKE_OUT);
            else if (type == QStringLiteral("stickyNote"))
                applyStickyNoteAnnotation(ctx, page, edit);
            else if (type == QStringLiteral("rect"))
                applyShapeAnnotation(ctx, page, edit, PDF_ANNOT_SQUARE);
            else if (type == QStringLiteral("circle"))
                applyShapeAnnotation(ctx, page, edit, PDF_ANNOT_CIRCLE);
            else if (type == QStringLiteral("ink"))
                applyInkAnnotation(ctx, page, edit);
            else if (type == QStringLiteral("replaceTextBlock"))
                applyReplaceTextBlockEdit(ctx, doc, page, edit);
        }
        fz_always(ctx)
        {
            if (page)
                pdf_drop_page(ctx, page);
        }
        fz_catch(ctx)
        {
            fz_rethrow(ctx);
        }
    }
}

void applyInPlaceRotations(fz_context *ctx, pdf_document *doc, const QVector<int> &rotations)
{
    const int pageCount = pdf_count_pages(ctx, doc);
    const int limit = std::min(pageCount, static_cast<int>(rotations.size()));
    for (int page = 0; page < limit; ++page) {
        const int rotation = rotations.at(page);
        if (rotation == 0)
            continue;

        pdf_obj *pageObj = pdf_lookup_page_obj(ctx, doc, page);
        const int existingRotation = pdf_to_int_default(
            ctx,
            pdf_dict_get_inheritable(ctx, pageObj, PDF_NAME(Rotate)),
            0);
        int savedRotation = (existingRotation + rotation) % 360;
        if (savedRotation < 0)
            savedRotation += 360;

        pdf_dict_put_int(ctx, pageObj, PDF_NAME(Rotate), savedRotation);
    }
}

void graftEditedPages(fz_context *ctx,
                      pdf_document *sourceDoc,
                      pdf_document *editedDoc,
                      pdf_graft_map *map,
                      const QVector<int> &pageOrder,
                      const QVector<int> &rotations,
                      int pageCount)
{
    int outputPage = 0;
    for (int index = 0; index < pageOrder.size(); ++index) {
        const int sourcePage = pageOrder.at(index);
        if (sourcePage < 0 || sourcePage >= pageCount)
            fz_throw(ctx, FZ_ERROR_GENERIC, "Edited page order references an invalid page.");

        pdf_graft_mapped_page(ctx, map, -1, sourceDoc, sourcePage);

        const int rotation = sourcePage < rotations.size() ? rotations.at(sourcePage) : 0;
        if (rotation != 0) {
            pdf_obj *pageObj = pdf_lookup_page_obj(ctx, editedDoc, outputPage);
            const int existingRotation = pdf_to_int_default(
                ctx,
                pdf_dict_get_inheritable(ctx, pageObj, PDF_NAME(Rotate)),
                0);
            int savedRotation = (existingRotation + rotation) % 360;
            if (savedRotation < 0)
                savedRotation += 360;

            pdf_dict_put_int(ctx, pageObj, PDF_NAME(Rotate), savedRotation);
        }

        ++outputPage;
    }
}

QString pixmapToDataUrl(fz_pixmap *pix)
{
    if (!pix || pix->w <= 0 || pix->h <= 0)
        return {};

    QImage::Format format = QImage::Format_Invalid;
    if (pix->n == 3)
        format = QImage::Format_RGB888;
    else if (pix->n == 4)
        format = QImage::Format_RGBA8888;
    else
        return {};

    const QImage image(pix->samples, pix->w, pix->h, pix->stride, format);
    const QImage owned = image.copy();

    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    owned.save(&buffer, "PNG");

    return QStringLiteral("data:image/png;base64,") + QString::fromLatin1(png.toBase64());
}

void dropOpenDocument(fz_context *&ctx, fz_document *&doc)
{
    if (doc) {
        fz_drop_document(ctx, doc);
        doc = nullptr;
    }

    if (ctx) {
        fz_drop_context(ctx);
        ctx = nullptr;
    }
}

QString renderPageToDataUrl(fz_context *ctx, fz_document *doc, int pageIndex, float scale, QString *error)
{
    if (!ctx || !doc || pageIndex < 0)
        return {};

    fz_pixmap *pix = nullptr;
    QString source;

    fz_try(ctx)
    {
        const fz_matrix matrix = fz_scale(scale, scale);
        pix = fz_new_pixmap_from_page_number(ctx, doc, pageIndex, matrix, fz_device_rgb(ctx), 0);
        source = pixmapToDataUrl(pix);
    }
    fz_catch(ctx)
    {
        if (error)
            *error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (pix)
        fz_drop_pixmap(ctx, pix);

    return source;
}

int resolveUriPageNumber(fz_context *ctx, fz_document *doc, const char *uri, float *x = nullptr, float *y = nullptr)
{
    if (!ctx || !doc || !uri || !*uri)
        return -1;

    int pageNumber = -1;
    fz_try(ctx)
    {
        float resolvedX = 0.0f;
        float resolvedY = 0.0f;
        const fz_location location = fz_resolve_link(ctx, doc, uri, &resolvedX, &resolvedY);
        pageNumber = fz_page_number_from_location(ctx, doc, location);
        if (x)
            *x = resolvedX;
        if (y)
            *y = resolvedY;
    }
    fz_catch(ctx)
    {
        pageNumber = -1;
    }

    return pageNumber;
}

QJsonObject rectToJson(const fz_rect &rect)
{
    QJsonObject object;
    object.insert(QStringLiteral("x"), rect.x0);
    object.insert(QStringLiteral("y"), rect.y0);
    object.insert(QStringLiteral("width"), rect.x1 - rect.x0);
    object.insert(QStringLiteral("height"), rect.y1 - rect.y0);
    return object;
}

QJsonObject quadToJson(const fz_quad &quad)
{
    return rectToJson(fz_rect_from_quad(quad));
}

QJsonArray pointToJson(const fz_point &point)
{
    return QJsonArray{ point.x, point.y };
}

QJsonArray quadPathToJson(const fz_quad &quad)
{
    return QJsonArray{
        pointToJson(quad.ul),
        pointToJson(quad.ur),
        pointToJson(quad.lr),
        pointToJson(quad.ll)
    };
}

QString selectionGeometryToJson(const QVector<fz_quad> &quads, int count)
{
    QJsonArray geometry;
    const int safeCount = std::clamp(count, 0, static_cast<int>(quads.size()));
    for (int i = 0; i < safeCount; ++i)
        geometry.append(quadPathToJson(quads.at(i)));
    return QString::fromUtf8(QJsonDocument(geometry).toJson(QJsonDocument::Compact));
}

QJsonArray outlineToJson(fz_context *ctx, fz_document *doc, fz_outline *outline)
{
    QJsonArray items;

    for (fz_outline *node = outline; node; node = node->next) {
        QJsonObject entry;
        entry.insert(QStringLiteral("title"), QString::fromUtf8(node->title ? node->title : ""));
        entry.insert(QStringLiteral("uri"), QString::fromUtf8(node->uri ? node->uri : ""));
        entry.insert(QStringLiteral("isOpen"), node->is_open != 0);
        entry.insert(QStringLiteral("x"), node->x);
        entry.insert(QStringLiteral("y"), node->y);

        int pageIndex = -1;
        if (ctx && doc)
            pageIndex = fz_page_number_from_location(ctx, doc, node->page);
        entry.insert(QStringLiteral("pageIndex"), pageIndex);
        entry.insert(QStringLiteral("children"), outlineToJson(ctx, doc, node->down));
        items.append(entry);
    }

    return items;
}

QString extractPageTextInternal(fz_context *ctx, fz_document *doc, int pageIndex, QString *error)
{
    if (!ctx || !doc || pageIndex < 0)
        return {};

    fz_page *page = nullptr;
    fz_stext_page *textPage = nullptr;
    fz_buffer *buffer = nullptr;
    fz_output *output = nullptr;
    QString extracted;

    fz_try(ctx)
    {
        fz_stext_options options = {};
        page = fz_load_page(ctx, doc, pageIndex);
        textPage = fz_new_stext_page_from_page(ctx, page, &options);
        buffer = fz_new_buffer(ctx, 256);
        output = fz_new_output_with_buffer(ctx, buffer);
        fz_print_stext_page_as_text(ctx, output, textPage);
        fz_close_output(ctx, output);
        extracted = QString::fromUtf8(fz_string_from_buffer(ctx, buffer)).trimmed();
    }
    fz_catch(ctx)
    {
        if (error)
            *error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (output)
        fz_drop_output(ctx, output);
    if (buffer)
        fz_drop_buffer(ctx, buffer);
    if (textPage)
        fz_drop_stext_page(ctx, textPage);
    if (page)
        fz_drop_page(ctx, page);

    return extracted;
}

QString pageLinksJsonForPage(fz_context *ctx, fz_document *doc, int pageIndex)
{
    if (!ctx || !doc || pageIndex < 0)
        return QStringLiteral("[]");

    fz_page *page = nullptr;
    fz_link *links = nullptr;
    QJsonArray linksJson;

    fz_try(ctx)
    {
        page = fz_load_page(ctx, doc, pageIndex);
        links = fz_load_links(ctx, page);
        for (fz_link *link = links; link; link = link->next) {
            float targetX = 0.0f;
            float targetY = 0.0f;
            const int targetPage = resolveUriPageNumber(ctx, doc, link->uri, &targetX, &targetY);

            QJsonObject item;
            item.insert(QStringLiteral("uri"), QString::fromUtf8(link->uri ? link->uri : ""));
            item.insert(QStringLiteral("external"), link->uri ? fz_is_external_link(ctx, link->uri) != 0 : false);
            item.insert(QStringLiteral("pageIndex"), targetPage);
            item.insert(QStringLiteral("targetX"), targetX);
            item.insert(QStringLiteral("targetY"), targetY);
            item.insert(QStringLiteral("rect"), rectToJson(link->rect));
            linksJson.append(item);
        }
    }
    fz_catch(ctx)
    {
        linksJson = QJsonArray();
    }

    if (links)
        fz_drop_link(ctx, links);
    if (page)
        fz_drop_page(ctx, page);

    return QString::fromUtf8(QJsonDocument(linksJson).toJson(QJsonDocument::Compact));
}

QString normalizedSearchText(const QString &text)
{
    QString normalized = text;
    normalized.replace(QRegularExpression(QStringLiteral("\\s+")), QStringLiteral(" "));
    return normalized.trimmed();
}

QString snippetForMatch(const QString &pageText, const QString &query, int occurrenceIndex)
{
    const QString text = normalizedSearchText(pageText);
    const QString needle = normalizedSearchText(query);
    if (text.isEmpty() || needle.isEmpty())
        return {};

    const QString haystackFolded = text.toCaseFolded();
    const QString needleFolded = needle.toCaseFolded();

    int from = 0;
    int matchIndex = -1;
    for (int i = 0; i <= occurrenceIndex; ++i) {
        matchIndex = haystackFolded.indexOf(needleFolded, from);
        if (matchIndex < 0)
            break;
        from = matchIndex + needleFolded.size();
    }

    if (matchIndex < 0)
        matchIndex = haystackFolded.indexOf(needleFolded);
    if (matchIndex < 0)
        return text.left(160);

    const int snippetRadius = 54;
    const int start = std::max(0, matchIndex - snippetRadius);
    const int end = std::min(text.size(), matchIndex + needle.size() + snippetRadius);
    QString snippet = text.mid(start, end - start).trimmed();

    if (start > 0)
        snippet.prepend(QStringLiteral("..."));
    if (end < text.size())
        snippet.append(QStringLiteral("..."));

    return snippet;
}
}

class PdfDocument::PdfEngine {
public:
    ~PdfEngine()
    {
        close();
    }

    bool open(const QByteArray &pathBytes, const QString &password, QString *error, bool *passwordRequired)
    {
        close();

        m_ctx = fz_new_context(nullptr, nullptr, FZ_STORE_UNLIMITED);
        if (!m_ctx) {
            if (error)
                *error = PdfDocument::tr("MuPDF could not create a rendering context.");
            return false;
        }

        QString openError;
        const QByteArray passwordBytes = password.toUtf8();
        fz_try(m_ctx)
        {
            fz_register_document_handlers(m_ctx);
            m_doc = fz_open_document(m_ctx, pathBytes.constData());

            if (fz_needs_password(m_ctx, m_doc)) {
                if (passwordRequired)
                    *passwordRequired = true;

                if (passwordBytes.isEmpty()) {
                    openError = QStringLiteral("password-protected PDF requires a password");
                } else if (!fz_authenticate_password(m_ctx, m_doc, passwordBytes.constData())) {
                    openError = QStringLiteral("Incorrect password for password-protected PDF");
                }
            }
        }
        fz_catch(m_ctx)
        {
            openError = QString::fromUtf8(fz_caught_message(m_ctx));
        }

        if (!openError.isEmpty()) {
            if (error)
                *error = openError;
            close();
            return false;
        }

        return true;
    }

    void close()
    {
        clearSelectionCache();
        dropOpenDocument(m_ctx, m_doc);
    }

    bool isOpen() const
    {
        return m_ctx && m_doc;
    }

    fz_context *context() const
    {
        return m_ctx;
    }

    fz_document *document() const
    {
        return m_doc;
    }

    fz_stext_page *selectionTextPage(int pageIndex, QString *error)
    {
        if (!m_ctx || !m_doc || pageIndex < 0)
            return nullptr;

        if (m_selectionTextPage && m_selectionPageIndex == pageIndex)
            return m_selectionTextPage;

        clearSelectionCache();

        QString selectionError;
        fz_try(m_ctx)
        {
            fz_stext_options options = {};
            m_selectionPage = fz_load_page(m_ctx, m_doc, pageIndex);
            m_selectionTextPage = fz_new_stext_page_from_page(m_ctx, m_selectionPage, &options);
            m_selectionPageIndex = pageIndex;
        }
        fz_catch(m_ctx)
        {
            selectionError = QString::fromUtf8(fz_caught_message(m_ctx));
        }

        if (!selectionError.isEmpty()) {
            clearSelectionCache();
            if (error)
                *error = selectionError;
            return nullptr;
        }

        return m_selectionTextPage;
    }

    void clearSelectionCache()
    {
        if (m_selectionTextPage) {
            fz_drop_stext_page(m_ctx, m_selectionTextPage);
            m_selectionTextPage = nullptr;
        }
        if (m_selectionPage) {
            fz_drop_page(m_ctx, m_selectionPage);
            m_selectionPage = nullptr;
        }
        m_selectionPageIndex = -1;
    }

private:
    fz_context *m_ctx = nullptr;
    fz_document *m_doc = nullptr;
    fz_page *m_selectionPage = nullptr;
    fz_stext_page *m_selectionTextPage = nullptr;
    int m_selectionPageIndex = -1;
};

PdfDocument::PdfDocument(QObject *parent)
    : QObject(parent)
    , m_engine(std::make_unique<PdfEngine>())
{
}

PdfDocument::~PdfDocument()
= default;

void PdfDocument::setPassword(const QString &password)
{
    if (m_password == password)
        return;

    m_password = password;
    emit passwordChanged();
}

void PdfDocument::setSelectionState(const QString &text, const QString &geometryJson, int pageIndex)
{
    const QString nextGeometry = geometryJson.isEmpty() ? QStringLiteral("[]") : geometryJson;
    if (m_selectionText == text && m_selectionGeometryJson == nextGeometry && m_selectionPage == pageIndex)
        return;

    m_selectionText = text;
    m_selectionGeometryJson = nextGeometry;
    m_selectionPage = pageIndex;
    emit selectionChanged();
}

void PdfDocument::beginSelection(int pageIndex, const QPointF &point)
{
    m_selectionInProgress = true;
    m_selectionAnchor = point;
    updateSelection(pageIndex, point);
}

void PdfDocument::updateSelection(int pageIndex, const QPointF &point)
{
    fz_context *ctx = m_engine->context();
    if (!ctx || !m_engine->document() || pageIndex < 0 || pageIndex >= m_pageCount) {
        setSelectionState(QString(), QStringLiteral("[]"), -1);
        return;
    }

    if (!m_selectionInProgress)
        m_selectionAnchor = point;

    QString error;
    fz_stext_page *textPage = m_engine->selectionTextPage(pageIndex, &error);
    if (!textPage) {
        setSelectionState(QString(), QStringLiteral("[]"), -1);
        return;
    }

    fz_point anchor = { static_cast<float>(m_selectionAnchor.x()), static_cast<float>(m_selectionAnchor.y()) };
    fz_point cursor = { static_cast<float>(point.x()), static_cast<float>(point.y()) };
    QVector<fz_quad> quads(2048);
    QString selectionText;
    QString geometryJson = QStringLiteral("[]");
    int selectionPageIndex = -1;

    fz_try(ctx)
    {
        fz_snap_selection(ctx, textPage, &anchor, &cursor, FZ_SELECT_WORDS);
        const int quadCount = fz_highlight_selection(ctx, textPage, anchor, cursor, quads.data(), quads.size());
        geometryJson = selectionGeometryToJson(quads, quadCount);
        char *copied = fz_copy_selection(ctx, textPage, anchor, cursor, 0);
        if (copied) {
            selectionText = QString::fromUtf8(copied).trimmed();
            fz_free(ctx, copied);
        }
        if (!selectionText.isEmpty() && quadCount > 0)
            selectionPageIndex = pageIndex;
    }
    fz_catch(ctx)
    {
        selectionText.clear();
        geometryJson = QStringLiteral("[]");
        selectionPageIndex = -1;
    }

    setSelectionState(selectionText, geometryJson, selectionPageIndex);
}

void PdfDocument::endSelection()
{
    m_selectionInProgress = false;
}

void PdfDocument::clearSelection()
{
    m_selectionInProgress = false;
    m_selectionAnchor = QPointF();
    setSelectionState(QString(), QStringLiteral("[]"), -1);
}

void PdfDocument::clear()
{
    if (m_filePath.isEmpty() && m_previewSource.isEmpty() && m_pageSources.isEmpty() &&
        m_thumbnailSources.isEmpty() && m_pageSizesJson.isEmpty() && m_outlineJson.isEmpty() &&
        m_pageLinksJson.isEmpty() && m_pageCount == 0 && m_title.isEmpty() &&
        m_errorMessage.isEmpty() && m_fileSizeBytes == 0 && !m_isLoaded && !m_engine->isOpen())
        return;

    m_engine->close();

    m_filePath.clear();
    m_previewSource.clear();
    m_pageSources.clear();
    m_thumbnailSources.clear();
    m_pageSizesJson.clear();
    m_outlineJson = QStringLiteral("[]");
    m_pageLinksJson = QStringLiteral("[]");
    m_title.clear();
    m_password.clear();
    m_errorMessage.clear();
    m_pageCount = 0;
    m_fileSizeBytes = 0;
    m_isLoaded = false;
    m_passwordRequired = false;
    m_selectionInProgress = false;
    m_selectionAnchor = QPointF();

    emit filePathChanged();
    emit previewSourceChanged();
    emit pageSourcesChanged();
    emit thumbnailSourcesChanged();
    emit pageSizesJsonChanged();
    emit outlineJsonChanged();
    emit pageLinksJsonChanged();
    emit pageCountChanged();
    emit fileSizeBytesChanged();
    emit titleChanged();
    emit passwordChanged();
    emit errorMessageChanged();
    emit isLoadedChanged();
    emit passwordRequiredChanged();
    setSelectionState(QString(), QStringLiteral("[]"), -1);
}

bool PdfDocument::load(const QString &source, const QString &password)
{
    QElapsedTimer timer;
    timer.start();
    const QString localPath = toLocalPath(source);
    const QFileInfo fileInfo(localPath);

    m_previewSource.clear();
    m_pageSources.clear();
    m_thumbnailSources.clear();
    m_pageSizesJson.clear();
    m_outlineJson = QStringLiteral("[]");
    m_pageLinksJson = QStringLiteral("[]");
    const bool hadPasswordRequired = m_passwordRequired;
    m_passwordRequired = false;
    m_errorMessage.clear();
    m_pageCount = 0;
    m_fileSizeBytes = 0;
    m_isLoaded = false;
    m_selectionInProgress = false;
    m_selectionAnchor = QPointF();
    setPassword(QString());
    m_engine->close();
    emit previewSourceChanged();
    emit pageSourcesChanged();
    emit thumbnailSourcesChanged();
    emit pageSizesJsonChanged();
    emit outlineJsonChanged();
    emit pageLinksJsonChanged();
    if (hadPasswordRequired)
        emit passwordRequiredChanged();
    emit errorMessageChanged();
    emit pageCountChanged();
    emit fileSizeBytesChanged();
    emit isLoadedChanged();
    setSelectionState(QString(), QStringLiteral("[]"), -1);

    if (!fileInfo.exists() || !fileInfo.isFile() ||
        fileInfo.suffix().compare(QLatin1String("pdf"), Qt::CaseInsensitive) != 0) {
        m_errorMessage = tr("Select a valid PDF file.");
        emit errorMessageChanged();
        emit loadFailed(m_errorMessage);
        return false;
    }

    const QString canonical = fileInfo.canonicalFilePath();
    if (canonical.isEmpty()) {
        m_errorMessage = tr("The PDF path could not be resolved.");
        emit errorMessageChanged();
        emit loadFailed(m_errorMessage);
        return false;
    }

    m_filePath = canonical;
    m_fileSizeBytes = fileInfo.size();
    m_title = QFileInfo(canonical).fileName();
    emit filePathChanged();
    emit fileSizeBytesChanged();
    emit titleChanged();
    qInfo().noquote() << QStringLiteral("[pdf-load] start file=\"%1\"").arg(displayNameForPath(canonical));

    QString error;
    bool passwordRequired = false;
    const QByteArray pathBytes = canonical.toUtf8();

    if (!m_engine->open(pathBytes, password, &error, &passwordRequired)) {
        m_passwordRequired = passwordRequired;
        m_errorMessage = error.startsWith(QStringLiteral("MuPDF could not create"))
            ? error
            : tr("MuPDF failed to open this PDF: %1").arg(error);
        if (m_passwordRequired)
            emit passwordRequiredChanged();
        emit errorMessageChanged();
        emit loadFailed(m_errorMessage);
        return false;
    }

    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();

    fz_try(ctx)
    {
        m_pageCount = fz_count_pages(ctx, doc);
        if (m_pageCount <= 0)
            fz_throw(ctx, FZ_ERROR_GENERIC, "PDF has no pages");

        QJsonArray pageSizes;
        m_pageSources = QStringList();
        m_thumbnailSources = QStringList();
        m_pageSources.reserve(m_pageCount);
        m_thumbnailSources.reserve(m_pageCount);
        for (int page = 0; page < m_pageCount; ++page) {
            fz_page *loadedPage = fz_load_page(ctx, doc, page);
            const fz_rect bounds = fz_bound_page(ctx, loadedPage);
            fz_drop_page(ctx, loadedPage);

            QJsonObject size;
            size.insert(QStringLiteral("width"), bounds.x1 - bounds.x0);
            size.insert(QStringLiteral("height"), bounds.y1 - bounds.y0);
            pageSizes.append(size);

            m_pageSources.append(QString());
            m_thumbnailSources.append(QString());
        }

        m_pageSizesJson = QString::fromUtf8(QJsonDocument(pageSizes).toJson(QJsonDocument::Compact));

        m_previewSource.clear();
        rebuildNavigationData();
        m_isLoaded = true;
        setPassword(password);
    }
    fz_catch(ctx)
    {
        error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (!error.isEmpty()) {
        m_engine->close();
        m_previewSource.clear();
        m_pageSources.clear();
        m_thumbnailSources.clear();
        m_pageSizesJson.clear();
        m_outlineJson = QStringLiteral("[]");
        m_pageLinksJson = QStringLiteral("[]");
        m_pageCount = 0;
        m_fileSizeBytes = 0;
        m_isLoaded = false;
        m_passwordRequired = false;
        m_errorMessage = tr("MuPDF failed to open this PDF: %1").arg(error);
        emit previewSourceChanged();
        emit pageSourcesChanged();
        emit thumbnailSourcesChanged();
        emit pageSizesJsonChanged();
        emit outlineJsonChanged();
        emit pageLinksJsonChanged();
        emit pageCountChanged();
        emit fileSizeBytesChanged();
        emit errorMessageChanged();
        emit isLoadedChanged();
        emit passwordRequiredChanged();
        emit loadFailed(m_errorMessage);
        qWarning().noquote() << QStringLiteral("[pdf-load] failed file=\"%1\" elapsed_ms=%2 error=\"%3\"")
                                    .arg(displayNameForPath(canonical))
                                    .arg(timer.elapsed())
                                    .arg(error);
        return false;
    }

    emit previewSourceChanged();
    emit pageSourcesChanged();
    emit thumbnailSourcesChanged();
    emit pageSizesJsonChanged();
    emit outlineJsonChanged();
    emit pageLinksJsonChanged();
    emit pageCountChanged();
    emit isLoadedChanged();
    emit loaded();
    qInfo().noquote() << QStringLiteral("[pdf-load] done file=\"%1\" pages=%2 elapsed_ms=%3")
                             .arg(displayNameForPath(canonical))
                             .arg(m_pageCount)
                             .arg(timer.elapsed());
    return true;
}

bool PdfDocument::retryWithPassword(const QString &password)
{
    if (m_filePath.isEmpty())
        return false;

    return load(m_filePath, password);
}

QString PdfDocument::renderPage(int pageIndex, qreal scale)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return {};

    const float safeScale = std::clamp(static_cast<float>(scale), 0.25f, kRenderScale);
    QString error;
    const QString source = renderPageToDataUrl(ctx, doc, pageIndex, safeScale, &error);
    if (source.isEmpty())
        return {};

    if (pageIndex >= 0 && pageIndex < m_pageSources.size() && safeScale >= kRenderScale * 0.95f) {
        m_pageSources[pageIndex] = source;
        emit pageSourcesChanged();
    }

    return source;
}

QString PdfDocument::renderThumbnail(int pageIndex)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return {};

    QString error;
    const QString source = renderPageToDataUrl(ctx, doc, pageIndex, kThumbnailScale, &error);
    if (source.isEmpty())
        return {};

    if (pageIndex >= 0 && pageIndex < m_thumbnailSources.size()) {
        m_thumbnailSources[pageIndex] = source;
        emit thumbnailSourcesChanged();
    }

    return source;
}

QString PdfDocument::searchPage(int pageIndex, const QString &query)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return QStringLiteral("[]");

    const QString trimmed = query.trimmed();
    if (trimmed.isEmpty())
        return QStringLiteral("[]");

    fz_page *page = nullptr;
    fz_stext_page *textPage = nullptr;
    QJsonArray hitsJson;

    fz_try(ctx)
    {
        fz_stext_options options = {};
        page = fz_load_page(ctx, doc, pageIndex);
        textPage = fz_new_stext_page_from_page(ctx, page, &options);

        constexpr int kMaxHits = 256;
        int marks[kMaxHits] = {};
        fz_quad quads[kMaxHits];
        const QByteArray needle = trimmed.toUtf8();
        const int hitCount = fz_search_stext_page(ctx, textPage, needle.constData(), marks, quads, kMaxHits);
        const int limit = std::max(0, std::min(hitCount, kMaxHits));
        for (int i = 0; i < limit; ++i)
            hitsJson.append(quadToJson(quads[i]));
    }
    fz_catch(ctx)
    {
        hitsJson = QJsonArray();
    }

    if (textPage)
        fz_drop_stext_page(ctx, textPage);
    if (page)
        fz_drop_page(ctx, page);

    return QString::fromUtf8(QJsonDocument(hitsJson).toJson(QJsonDocument::Compact));
}

QString PdfDocument::searchDocument(const QString &query)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || m_pageCount <= 0)
        return QStringLiteral("[]");

    const QString trimmed = query.trimmed();
    if (trimmed.isEmpty())
        return QStringLiteral("[]");

    QJsonArray resultsJson;

    for (int pageIndex = 0; pageIndex < m_pageCount; ++pageIndex) {
        fz_page *page = nullptr;
        fz_stext_page *textPage = nullptr;
        fz_buffer *buffer = nullptr;
        fz_output *output = nullptr;
        QJsonArray pageHits;
        QString pageText;

        fz_try(ctx)
        {
            fz_stext_options options = {};
            page = fz_load_page(ctx, doc, pageIndex);
            textPage = fz_new_stext_page_from_page(ctx, page, &options);

            constexpr int kMaxHits = 256;
            int marks[kMaxHits] = {};
            fz_quad quads[kMaxHits];
            const QByteArray needle = trimmed.toUtf8();
            const int hitCount = fz_search_stext_page(ctx, textPage, needle.constData(), marks, quads, kMaxHits);
            const int limit = std::max(0, std::min(hitCount, kMaxHits));

            if (limit > 0) {
                buffer = fz_new_buffer(ctx, 256);
                output = fz_new_output_with_buffer(ctx, buffer);
                fz_print_stext_page_as_text(ctx, output, textPage);
                fz_close_output(ctx, output);
                pageText = QString::fromUtf8(fz_string_from_buffer(ctx, buffer)).trimmed();
                fz_drop_output(ctx, output);
                fz_drop_buffer(ctx, buffer);
                output = nullptr;
                buffer = nullptr;
            }

            for (int i = 0; i < limit; ++i) {
                QJsonObject item;
                item.insert(QStringLiteral("pageIndex"), pageIndex);
                item.insert(QStringLiteral("pageLabel"), pageIndex + 1);
                item.insert(QStringLiteral("snippet"), snippetForMatch(pageText, trimmed, i));
                item.insert(QStringLiteral("rect"), quadToJson(quads[i]));
                pageHits.append(item);
            }
        }
        fz_catch(ctx)
        {
            pageHits = QJsonArray();
        }

        if (textPage)
            fz_drop_stext_page(ctx, textPage);
        if (page)
            fz_drop_page(ctx, page);
        if (output)
            fz_drop_output(ctx, output);
        if (buffer)
            fz_drop_buffer(ctx, buffer);

        for (const QJsonValue &hit : pageHits)
            resultsJson.append(hit);
    }

    return QString::fromUtf8(QJsonDocument(resultsJson).toJson(QJsonDocument::Compact));
}

QString PdfDocument::textBlocksForPage(int pageIndex)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return QStringLiteral("[]");

    fz_page *page = nullptr;
    fz_stext_page *textPage = nullptr;
    QString error;
    QJsonArray blocks;

    fz_try(ctx)
    {
        const FontResourceMap fontResources = collectPageFontResources(ctx, doc, pageIndex);
        fz_stext_options options = {};
        options.flags = textBlockExtractionFlags();
        page = fz_load_page(ctx, doc, pageIndex);
        textPage = fz_new_stext_page_from_page(ctx, page, &options);
        blocks = collectTextBlocks(ctx, pageIndex, textPage, &fontResources);
    }
    fz_catch(ctx)
    {
        error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (textPage)
        fz_drop_stext_page(ctx, textPage);
    if (page)
        fz_drop_page(ctx, page);

    if (!error.isEmpty())
        return QStringLiteral("[]");
    return QString::fromUtf8(QJsonDocument(blocks).toJson(QJsonDocument::Compact));
}

QString PdfDocument::textElementsForPage(int pageIndex)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return QStringLiteral("[]");

    fz_page *page = nullptr;
    fz_stext_page *textPage = nullptr;
    fz_link *links = nullptr;
    QString error;
    QJsonArray elements;

    fz_try(ctx)
    {
        const FontResourceMap fontResources = collectPageFontResources(ctx, doc, pageIndex);
        fz_stext_options options = {};
        options.flags = textBlockExtractionFlags();
        page = fz_load_page(ctx, doc, pageIndex);
        textPage = fz_new_stext_page_from_page(ctx, page, &options);

        const QJsonArray textBlocks = collectTextBlocks(ctx, pageIndex, textPage, &fontResources);
        for (const QJsonValue &value : textBlocks) {
            QJsonObject element = value.toObject();
            element.insert(QStringLiteral("elementType"), QStringLiteral("text"));
            element.insert(QStringLiteral("editable"), true);
            element.insert(QStringLiteral("stableElementId"),
                           element.value(QStringLiteral("stableElementId")).toString(
                               stableTextElementId(pageIndex,
                                                   rectFromJson(element, fz_make_rect(0, 0, 0, 0)),
                                                   element.value(QStringLiteral("text")).toString())));
            elements.append(element);
        }

        links = fz_load_links(ctx, page);
        int linkIndex = 0;
        for (fz_link *link = links; link; link = link->next, ++linkIndex) {
            QJsonObject element;
            element.insert(QStringLiteral("elementType"), QStringLiteral("link"));
            element.insert(QStringLiteral("editable"), false);
            element.insert(QStringLiteral("pageIndex"), pageIndex);
            element.insert(QStringLiteral("rect"), rectToJson(link->rect));
            element.insert(QStringLiteral("stableElementId"),
                           QStringLiteral("link-%1-%2:%3:%4:%5")
                               .arg(pageIndex)
                               .arg(link->rect.x0, 0, 'f', 2)
                               .arg(link->rect.y0, 0, 'f', 2)
                               .arg(link->rect.x1, 0, 'f', 2)
                               .arg(linkIndex));
            element.insert(QStringLiteral("uri"), QString::fromUtf8(link->uri ? link->uri : ""));
            elements.append(element);
        }
    }
    fz_catch(ctx)
    {
        error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (links)
        fz_drop_link(ctx, links);
    if (textPage)
        fz_drop_stext_page(ctx, textPage);
    if (page)
        fz_drop_page(ctx, page);

    if (!error.isEmpty())
        return QStringLiteral("[]");
    return QString::fromUtf8(QJsonDocument(elements).toJson(QJsonDocument::Compact));
}

QString PdfDocument::extractEditableLayout(int pageIndex)
{
    QJsonArray elements;
    const QJsonDocument document = QJsonDocument::fromJson(textElementsForPage(pageIndex).toUtf8());
    if (document.isArray())
        elements = document.array();

    PdfEditableLayout layout = PdfEditableLayout::fromJsonElements(pageIndex, elements);
    int nativeTextLength = 0;
    for (const QJsonValue &value : elements)
        nativeTextLength += value.toObject().value(QStringLiteral("text")).toString().trimmed().length();

    if (nativeTextLength < 4)
        layout.markOcrCandidate(QStringLiteral("native-text-insufficient"));

    return QString::fromUtf8(QJsonDocument(layout.toJson()).toJson(QJsonDocument::Compact));
}

QString PdfDocument::textEditAt(int pageIndex, const QPointF &point)
{
    QJsonObject result;
    result.insert(QStringLiteral("found"), false);
    result.insert(QStringLiteral("pageIndex"), pageIndex);
    result.insert(QStringLiteral("text"), QString());
    result.insert(QStringLiteral("fontFamily"), QStringLiteral("Helv"));
    result.insert(QStringLiteral("fontSize"), 12.0);
    result.insert(QStringLiteral("color"), defaultAnnotationColor());
    result.insert(QStringLiteral("bold"), false);
    result.insert(QStringLiteral("italic"), false);
    result.insert(QStringLiteral("underline"), false);
    result.insert(QStringLiteral("rect"), rectToJson(fz_make_rect(
                                            static_cast<float>(point.x()),
                                            static_cast<float>(point.y()),
                                            static_cast<float>(point.x() + 180.0),
                                            static_cast<float>(point.y() + 24.0))));

    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));

    fz_page *page = nullptr;
    fz_stext_page *textPage = nullptr;
    QString error;

    fz_try(ctx)
    {
        const FontResourceMap fontResources = collectPageFontResources(ctx, doc, pageIndex);
        fz_stext_options options = {};
        options.flags = textBlockExtractionFlags();
        page = fz_load_page(ctx, doc, pageIndex);
        textPage = fz_new_stext_page_from_page(ctx, page, &options);
        for (fz_stext_block *block = textPage->first_block; block; block = block->next) {
            if (block->type != FZ_STEXT_BLOCK_TEXT)
                continue;
            if (!pointInRect(block->bbox, point, 3.0f))
                continue;

            result = buildTextBlockJson(ctx, pageIndex, block, &fontResources);
            break;
        }
    }
    fz_catch(ctx)
    {
        error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (textPage)
        fz_drop_stext_page(ctx, textPage);
    if (page)
        fz_drop_page(ctx, page);

    if (!error.isEmpty())
        result.insert(QStringLiteral("error"), error);

    return QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));
}

QString PdfDocument::extractPageText(int pageIndex)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    QString error;
    const QString extracted = extractPageTextInternal(ctx, doc, pageIndex, &error);
    if (!error.isEmpty())
        return {};
    return extracted;
}

QString PdfDocument::extractDocumentText()
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || m_pageCount <= 0)
        return {};

    QStringList pages;
    pages.reserve(m_pageCount);
    for (int pageIndex = 0; pageIndex < m_pageCount; ++pageIndex) {
        QString error;
        const QString extracted = extractPageTextInternal(ctx, doc, pageIndex, &error);
        if (!error.isEmpty())
            continue;

        const QString trimmed = extracted.trimmed();
        if (trimmed.isEmpty())
            continue;

        pages.append(QStringLiteral("Page %1\n\n%2").arg(pageIndex + 1).arg(trimmed));
    }

    return pages.join(QStringLiteral("\n\n----------------------------------------\n\n"));
}

int PdfDocument::resolveLinkPage(const QString &uri)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    const QByteArray utf8 = uri.toUtf8();
    return resolveUriPageNumber(ctx, doc, utf8.constData());
}

void PdfDocument::rebuildNavigationData()
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc) {
        m_outlineJson = QStringLiteral("[]");
        m_pageLinksJson = QStringLiteral("[]");
        return;
    }

    QStringList pageLinks;
    pageLinks.reserve(m_pageCount);

    fz_outline *outline = nullptr;
    fz_try(ctx)
    {
        outline = fz_load_outline(ctx, doc);
        m_outlineJson = QString::fromUtf8(QJsonDocument(outlineToJson(ctx, doc, outline)).toJson(QJsonDocument::Compact));

        for (int pageIndex = 0; pageIndex < m_pageCount; ++pageIndex) {
            pageLinks.append(pageLinksJsonForPage(ctx, doc, pageIndex));
        }
    }
    fz_always(ctx)
    {
        if (outline)
            fz_drop_outline(ctx, outline);
    }
    fz_catch(ctx)
    {
        m_outlineJson = QStringLiteral("[]");
        pageLinks.clear();
    }

    QJsonArray allLinks;
    for (const QString &pageJson : pageLinks)
        allLinks.append(QJsonDocument::fromJson(pageJson.toUtf8()).array());
    m_pageLinksJson = QString::fromUtf8(QJsonDocument(allLinks).toJson(QJsonDocument::Compact));
}

bool PdfDocument::saveRotatedCopy(const QString &source, const QString &target, const QString &rotationsJson)
{
    return saveEditedCopy(source, target, QStringLiteral("[]"), rotationsJson, m_password, QStringLiteral("[]"));
}

void PdfDocument::setPendingEditJournal(const QString &journalJson)
{
    const QString normalized = journalJson.trimmed().isEmpty() ? QStringLiteral("[]") : journalJson;
    if (m_pendingEditJournalJson == normalized)
        return;

    m_pendingEditJournalJson = normalized;
    emit pendingEditJournalChanged();
}

bool PdfDocument::saveEditedCopy(const QString &outPath)
{
    return saveEditedCopy(m_filePath,
                          outPath,
                          QStringLiteral("[]"),
                          QStringLiteral("[]"),
                          m_password,
                          m_pendingEditJournalJson);
}

bool PdfDocument::replaceOriginalSafely(bool createBackup)
{
    const QString sourcePath = toLocalPath(m_filePath);
    const QFileInfo sourceInfo(sourcePath);
    m_errorMessage.clear();
    emit errorMessageChanged();

    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        m_errorMessage = tr("No loaded PDF can be replaced safely.");
        emit errorMessageChanged();
        return false;
    }

    const QString tempPath = tempPdfPathFor(sourceInfo.absoluteFilePath());
    if (tempPath.isEmpty()) {
        m_errorMessage = tr("Could not create a temporary PDF path.");
        emit errorMessageChanged();
        return false;
    }

    if (!saveEditedCopy(sourceInfo.absoluteFilePath(),
                        tempPath,
                        QStringLiteral("[]"),
                        QStringLiteral("[]"),
                        m_password,
                        m_pendingEditJournalJson)) {
        QFile::remove(tempPath);
        return false;
    }

    const QFileInfo tempInfo(tempPath);
    if (!tempInfo.exists() || tempInfo.size() <= 0) {
        QFile::remove(tempPath);
        m_errorMessage = tr("The edited PDF copy could not be validated.");
        emit errorMessageChanged();
        return false;
    }

    if (createBackup) {
        const QString backupPath = sourceInfo.absoluteDir().absoluteFilePath(
            sourceInfo.completeBaseName() + QStringLiteral(".pdfclowne-user-backup.pdf"));
        QFile::remove(backupPath);
        QFile::copy(sourceInfo.absoluteFilePath(), backupPath);
    }

    QString error;
    if (!replaceFileWithBackup(sourceInfo.absoluteFilePath(), tempPath, &error)) {
        QFile::remove(tempPath);
        m_errorMessage = error;
        emit errorMessageChanged();
        return false;
    }

    return true;
}

bool PdfDocument::saveEditedCopy(const QString &source,
                                 const QString &target,
                                 const QString &pageOrderJson,
                                 const QString &rotationsJson,
                                 const QString &password,
                                 const QString &annotationsJson)
{
    qInfo().noquote() << QStringLiteral("[pdf-save] start source=\"%1\" target=\"%2\"")
                             .arg(displayNameForPath(source))
                             .arg(displayNameForPath(target));

    const QString sourcePath = toLocalPath(source);
    const QFileInfo sourceInfo(sourcePath);
    m_errorMessage.clear();
    emit errorMessageChanged();

    if (!sourceInfo.exists() || !sourceInfo.isFile() ||
        sourceInfo.suffix().compare(QLatin1String("pdf"), Qt::CaseInsensitive) != 0) {
        m_errorMessage = tr("Select a valid PDF file.");
        emit errorMessageChanged();
        return false;
    }

    const QString sourceCanonical = sourceInfo.canonicalFilePath();
    if (sourceCanonical.isEmpty()) {
        m_errorMessage = tr("The PDF path could not be resolved.");
        emit errorMessageChanged();
        return false;
    }

    const QString targetPath = ensurePdfSuffix(toLocalPath(target));
    if (targetPath.isEmpty()) {
        m_errorMessage = tr("Choose a valid output PDF path.");
        emit errorMessageChanged();
        return false;
    }

    const QFileInfo targetInfo(targetPath);
    const QDir targetDir = targetInfo.absoluteDir();
    if (!targetDir.exists()) {
        m_errorMessage = tr("The output folder does not exist.");
        emit errorMessageChanged();
        return false;
    }

    const QString targetCanonical = targetInfo.exists()
        ? targetInfo.canonicalFilePath()
        : targetDir.canonicalPath() + QLatin1Char('/') + targetInfo.fileName();

    const bool overwriteOriginal =
        QDir::cleanPath(sourceCanonical).compare(QDir::cleanPath(targetCanonical), Qt::CaseInsensitive) == 0;

    fz_context *ctx = nullptr;
    pdf_document *doc = nullptr;
    pdf_document *editedDoc = nullptr;
    pdf_graft_map *map = nullptr;
    QString error;
    const QString savePath = overwriteOriginal ? tempPdfPathFor(sourceCanonical) : targetPath;
    if (savePath.isEmpty()) {
        m_errorMessage = tr("Could not create a temporary PDF path.");
        emit errorMessageChanged();
        return false;
    }

    const QByteArray sourceBytes = sourceCanonical.toUtf8();
    const QByteArray targetBytes = QDir::toNativeSeparators(savePath).toUtf8();
    const QByteArray passwordBytes = (password.isNull() ? m_password : password).toUtf8();

    ctx = fz_new_context(nullptr, nullptr, FZ_STORE_UNLIMITED);
    if (!ctx) {
        m_errorMessage = tr("MuPDF could not create a saving context.");
        emit errorMessageChanged();
        return false;
    }

    fz_try(ctx)
    {
        fz_register_document_handlers(ctx);
        doc = pdf_open_document(ctx, sourceBytes.constData());

        if (pdf_needs_password(ctx, doc)) {
            if (passwordBytes.isEmpty() || !pdf_authenticate_password(ctx, doc, passwordBytes.constData()))
                fz_throw(ctx, FZ_ERROR_GENERIC, "Incorrect password for password-protected PDF");
        }

        const int pageCount = pdf_count_pages(ctx, doc);
        QVector<int> rotations = parseRotations(rotationsJson);
        while (rotations.size() < pageCount)
            rotations.append(0);

        QVector<int> pageOrder = parsePageOrder(pageOrderJson);
        if (pageOrder.isEmpty()) {
            pageOrder.reserve(pageCount);
            for (int page = 0; page < pageCount; ++page)
                pageOrder.append(page);
        }

        const bool hasRotation = hasRotationChanges(rotations);
        const bool hasStructuralChanges = hasStructuralPageChanges(pageOrder, pageCount);
        const QJsonArray annotationEdits = parseAnnotationEdits(annotationsJson);
        const bool hasAnnotationChanges = !annotationEdits.isEmpty();

        if (!hasRotation && !hasStructuralChanges && !hasAnnotationChanges)
            fz_throw(ctx, FZ_ERROR_GENERIC, "There are no document changes to save.");

        if (hasAnnotationChanges)
            applyAnnotationEdits(ctx, doc, pageCount, annotationEdits);

        pdf_write_options options = pdf_default_write_options;
        options.do_garbage = 1;
        options.do_compress = 1;
        if (!hasStructuralChanges) {
            applyInPlaceRotations(ctx, doc, rotations);
            pdf_save_document(ctx, doc, targetBytes.constData(), &options);
        } else {
            editedDoc = pdf_create_document(ctx);
            if (!editedDoc)
                fz_throw(ctx, FZ_ERROR_GENERIC, "MuPDF could not create an edited PDF document.");

            map = pdf_new_graft_map(ctx, editedDoc);
            if (!map)
                fz_throw(ctx, FZ_ERROR_GENERIC, "MuPDF could not create a page graft map.");

            graftEditedPages(ctx, doc, editedDoc, map, pageOrder, rotations, pageCount);
            pdf_save_document(ctx, editedDoc, targetBytes.constData(), &options);
        }
    }
    fz_catch(ctx)
    {
        error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (map)
        pdf_drop_graft_map(ctx, map);
    if (editedDoc)
        pdf_drop_document(ctx, editedDoc);
    if (doc)
        pdf_drop_document(ctx, doc);
    fz_drop_context(ctx);

    if (!error.isEmpty()) {
        if (overwriteOriginal)
            QFile::remove(savePath);
        if (error.compare(QStringLiteral("There are no document changes to save."), Qt::CaseInsensitive) == 0)
            m_errorMessage = tr("There are no document changes to save.");
        else
            m_errorMessage = tr("MuPDF failed to save this PDF: %1").arg(error);
        emit errorMessageChanged();
        qWarning().noquote() << QStringLiteral("[pdf-save] failed source=\"%1\" target=\"%2\" overwrite=%3 error=\"%4\"")
                                    .arg(displayNameForPath(sourceCanonical))
                                    .arg(displayNameForPath(targetPath))
                                    .arg(overwriteOriginal ? QStringLiteral("true") : QStringLiteral("false"))
                                    .arg(error);
        return false;
    }

    if (overwriteOriginal) {
        if (QDir::cleanPath(m_filePath).compare(QDir::cleanPath(sourceCanonical), Qt::CaseInsensitive) == 0)
            m_engine->close();

        QString replaceError;
        if (!replaceFileWithBackup(sourceCanonical, savePath, &replaceError)) {
            QFile::remove(savePath);
            m_errorMessage = replaceError;
            emit errorMessageChanged();
            return false;
        }
    }

    qInfo().noquote() << QStringLiteral("[pdf-save] done source=\"%1\" target=\"%2\" overwrite=%3")
                             .arg(displayNameForPath(sourceCanonical))
                             .arg(displayNameForPath(targetPath))
                             .arg(overwriteOriginal ? QStringLiteral("true") : QStringLiteral("false"));
    return true;
}
