#include "PdfTextExtractor.h"

#include <QColor>
#include <QFileInfo>
#include <QRegularExpression>
#include <QUrl>

#include <mupdf/fitz.h>
#include <mupdf/pdf.h>

#include <algorithm>
#include <cmath>

namespace PDFClowne::Editing {
namespace {

QString toLocalPath(const QString &source)
{
    if (source.startsWith(QLatin1String("file://"), Qt::CaseInsensitive))
        return QUrl(source).toLocalFile();
    return source;
}

QString cleanedFontName(QString name)
{
    const int subsetMarker = name.indexOf(QLatin1Char('+'));
    if (subsetMarker > 0)
        name = name.mid(subsetMarker + 1);
    return name;
}

QPointF toPoint(const fz_point &point)
{
    return QPointF(point.x, point.y);
}

QRectF toRect(const fz_rect &rect)
{
    return QRectF(QPointF(rect.x0, rect.y0), QPointF(rect.x1, rect.y1)).normalized();
}

QPolygonF toQuad(const fz_quad &quad)
{
    QPolygonF polygon;
    polygon << toPoint(quad.ul)
            << toPoint(quad.ur)
            << toPoint(quad.lr)
            << toPoint(quad.ll);
    return polygon;
}

QTransform textMatrixFor(const fz_stext_line *line, const fz_stext_char *ch)
{
    if (!line || !ch)
        return {};

    const qreal size = std::max(0.0f, ch->size);
    const qreal dirX = line->dir.x;
    const qreal dirY = line->dir.y;
    return QTransform(size * dirX,
                      size * dirY,
                      -size * dirY,
                      size * dirX,
                      ch->origin.x,
                      ch->origin.y);
}

QPointF glyphAdvance(fz_context *ctx, const fz_stext_line *line, const fz_stext_char *ch, int gid)
{
    if (!ctx || !line || !ch || !ch->font)
        return {};

    float advance = 0.0f;
    fz_try(ctx)
    {
        advance = fz_advance_glyph(ctx, ch->font, gid, line->wmode) * ch->size;
    }
    fz_catch(ctx)
    {
        const fz_rect bbox = fz_rect_from_quad(ch->quad);
        advance = line->wmode == 0 ? bbox.x1 - bbox.x0 : bbox.y1 - bbox.y0;
    }

    if (line->wmode == 0)
        return QPointF(line->dir.x * advance, line->dir.y * advance);

    return QPointF(-line->dir.y * advance, line->dir.x * advance);
}

void addFontResourceAlias(PdfTextExtractor::FontResourceMap *resources,
                          const QString &name,
                          const PdfTextExtractor::FontResource &font)
{
    if (!resources || name.isEmpty() || font.key.isEmpty())
        return;

    resources->insert(name, font);
    resources->insert(cleanedFontName(name), font);
}

PdfTextExtractor::FontResourceMap collectFontResources(fz_context *ctx,
                                                       pdf_document *doc,
                                                       int pageIndex)
{
    PdfTextExtractor::FontResourceMap resources;
    if (!ctx || !doc || pageIndex < 0)
        return resources;

    pdf_page *page = nullptr;

    fz_try(ctx)
    {
        page = pdf_load_page(ctx, doc, pageIndex);
        pdf_obj *pageObj = pdf_lookup_page_obj(ctx, doc, pageIndex);
        const int pageObjectRef = pageObj ? pdf_to_num(ctx, pageObj) : pageIndex;
        pdf_obj *pageResources = pdf_page_resources(ctx, page);
        pdf_obj *fonts = pdf_dict_get(ctx, pageResources, PDF_NAME(Font));
        const int count = fonts ? pdf_dict_len(ctx, fonts) : 0;

        for (int i = 0; i < count; ++i) {
            pdf_obj *resourceNameObj = pdf_dict_get_key(ctx, fonts, i);
            pdf_obj *fontObject = pdf_dict_get_val(ctx, fonts, i);
            const QString resourceName = QString::fromUtf8(pdf_to_name(ctx, resourceNameObj));
            const int fontXref = pdf_to_num(ctx, fontObject);

            pdf_obj *baseFont = pdf_dict_get(ctx, fontObject, PDF_NAME(BaseFont));
            QString baseFontName;
            if (pdf_is_name(ctx, baseFont))
                baseFontName = QString::fromUtf8(pdf_to_name(ctx, baseFont));

            PdfTextExtractor::FontResource font;
            font.resourceName = resourceName;
            font.baseFont = baseFontName;
            font.xref = fontXref;
            font.key = PdfTextExtractor::resourceKey(pageObjectRef, resourceName, fontXref);

            addFontResourceAlias(&resources, resourceName, font);
            addFontResourceAlias(&resources, baseFontName, font);
        }
    }
    fz_always(ctx)
    {
        if (page)
            pdf_drop_page(ctx, page);
    }
    fz_catch(ctx)
    {
        resources.clear();
    }

    return resources;
}

PdfTextExtractor::FontResource resourceForFont(const PdfTextExtractor::FontResourceMap &resources,
                                               const QString &fontName)
{
    auto it = resources.constFind(fontName);
    if (it != resources.constEnd())
        return it.value();

    it = resources.constFind(cleanedFontName(fontName));
    if (it != resources.constEnd())
        return it.value();

    return {};
}

QString scriptForGlyph(uint unicode)
{
    if ((unicode >= 0x0590 && unicode <= 0x08FF) || (unicode >= 0xFB1D && unicode <= 0xFEFC))
        return QStringLiteral("Arab");
    if (unicode >= 0x3040 && unicode <= 0x9FFF)
        return QStringLiteral("Hani");
    return QStringLiteral("Latn");
}

QString languageForScript(const QString &script)
{
    if (script == QLatin1String("Arab"))
        return QStringLiteral("ar");
    if (script == QLatin1String("Hani"))
        return QStringLiteral("zh");
    return QStringLiteral("und");
}

} // namespace

int PdfTextExtractor::structuredTextFlags()
{
    return FZ_STEXT_PRESERVE_SPANS |
           FZ_STEXT_PRESERVE_LIGATURES |
           FZ_STEXT_ACCURATE_BBOXES |
           FZ_STEXT_ACCURATE_ASCENDERS |
           FZ_STEXT_ACCURATE_SIDE_BEARINGS |
           FZ_STEXT_COLLECT_STYLES;
}

QString PdfTextExtractor::resourceKey(int pageObjectRef, const QString &fontResourceName, int fontXref)
{
    return QStringLiteral("page:%1/font:%2/xref:%3")
        .arg(pageObjectRef)
        .arg(fontResourceName)
        .arg(fontXref);
}

PdfTextExtractor::PageText PdfTextExtractor::extractPage(const QString &filePath,
                                                         const QString &password,
                                                         int pageIndex) const
{
    PageText result;
    const QString localPath = toLocalPath(filePath);
    if (localPath.isEmpty() || pageIndex < 0) {
        result.error = QStringLiteral("Invalid page extraction request.");
        return result;
    }

    fz_context *ctx = nullptr;
    fz_document *doc = nullptr;
    pdf_document *pdfDoc = nullptr;
    fz_page *page = nullptr;
    fz_stext_page *textPage = nullptr;

    ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) {
        result.error = QStringLiteral("MuPDF could not create a text extraction context.");
        return result;
    }

    const QByteArray pathBytes = localPath.toUtf8();
    const QByteArray passwordBytes = password.toUtf8();

    fz_try(ctx)
    {
        fz_register_document_handlers(ctx);
        doc = fz_open_document(ctx, pathBytes.constData());
        if (fz_needs_password(ctx, doc)) {
            if (passwordBytes.isEmpty() || !fz_authenticate_password(ctx, doc, passwordBytes.constData()))
                fz_throw(ctx, FZ_ERROR_GENERIC, "Incorrect password for text extraction.");
        }

        pdfDoc = pdf_specifics(ctx, doc);
        if (!pdfDoc)
            fz_throw(ctx, FZ_ERROR_GENERIC, "PdfTextExtractor only supports PDF documents.");

        const FontResourceMap resources = collectFontResources(ctx, pdfDoc, pageIndex);

        fz_stext_options options = {};
        options.flags = structuredTextFlags();
        page = fz_load_page(ctx, doc, pageIndex);
        textPage = fz_new_stext_page_from_page(ctx, page, &options);

        int blockIndex = 0;
        for (fz_stext_block *block = textPage ? textPage->first_block : nullptr; block; block = block->next) {
            if (block->type != FZ_STEXT_BLOCK_TEXT)
                continue;

            int lineIndex = 0;
            for (fz_stext_line *line = block->u.t.first_line; line; line = line->next, ++lineIndex) {
                int spanIndex = 0;
                PdfRun currentRun;

                for (fz_stext_char *ch = line->first_char; ch; ch = ch->next) {
                    const char32_t scalar = static_cast<char32_t>(ch->c);
                    const QString text = ch->c ? QString::fromUcs4(&scalar, 1) : QString();
                    if (text.isEmpty())
                        continue;

                    PdfGlyph glyph;
                    glyph.pageIndex = pageIndex;
                    glyph.blockIndex = blockIndex;
                    glyph.lineIndex = lineIndex;
                    glyph.unicode = static_cast<uint>(ch->c);
                    glyph.fontName = ch->font ? QString::fromUtf8(fz_font_name(ctx, ch->font)) : QStringLiteral("Helvetica");
                    const PdfTextExtractor::FontResource fontResource = resourceForFont(resources, glyph.fontName);
                    glyph.fontResourceKey = fontResource.key.isEmpty() ? glyph.fontName : fontResource.key;
                    glyph.originalGid = ch->font ? fz_encode_character(ctx, ch->font, ch->c) : 0;
                    glyph.origin = toPoint(ch->origin);
                    glyph.quad = toQuad(ch->quad);
                    glyph.bbox = toRect(fz_rect_from_quad(ch->quad));
                    glyph.advance = glyphAdvance(ctx, line, ch, glyph.originalGid);
                    glyph.fontSize = ch->size;
                    glyph.fillColor = QColor::fromRgba(ch->argb);
                    glyph.wmode = line->wmode;
                    glyph.bidiLevel = ch->bidi;
                    glyph.direction = toPoint(line->dir);
                    glyph.trm = textMatrixFor(line, ch);

                    if (!currentRun.glyphs.isEmpty() && !runCanAppendGlyph(currentRun, glyph)) {
                        ++spanIndex;
                        currentRun = {};
                    }
                    glyph.spanIndex = spanIndex;

                    result.glyphs.append(glyph);

                    const bool firstInSpan = currentRun.glyphs.isEmpty();
                    currentRun.fontResourceKey = glyph.fontResourceKey;
                    currentRun.fillColor = glyph.fillColor;
                    currentRun.wmode = glyph.wmode;
                    currentRun.bidiLevel = glyph.bidiLevel;
                    currentRun.direction = glyph.direction;
                    if (firstInSpan)
                        currentRun.trm = glyph.trm;
                    currentRun.glyphs.append(glyph);
                    currentRun.plainText.append(text);
                }
            }

            ++blockIndex;
        }

        result.runs = buildRuns(result.glyphs);
        result.regions = buildEditableRegions(result.glyphs);
    }
    fz_catch(ctx)
    {
        result.error = QString::fromUtf8(fz_caught_message(ctx));
        result.glyphs.clear();
        result.runs.clear();
        result.regions.clear();
    }

    if (textPage)
        fz_drop_stext_page(ctx, textPage);
    if (page)
        fz_drop_page(ctx, page);
    if (doc)
        fz_drop_document(ctx, doc);
    fz_drop_context(ctx);

    return result;
}

QVector<PdfRun> PdfTextExtractor::buildRuns(const QVector<PdfGlyph> &glyphs)
{
    QVector<PdfRun> runs;
    PdfRun currentRun;

    for (const PdfGlyph &glyph : glyphs) {
        const char32_t scalar = static_cast<char32_t>(glyph.unicode);
        const QString text = glyph.unicode ? QString::fromUcs4(&scalar, 1) : QString();

        if (!currentRun.glyphs.isEmpty() && !runCanAppendGlyph(currentRun, glyph)) {
            runs.append(currentRun);
            currentRun = {};
        }

        const bool firstInRun = currentRun.glyphs.isEmpty();
        currentRun.fontResourceKey = glyph.fontResourceKey;
        currentRun.fillColor = glyph.fillColor;
        currentRun.wmode = glyph.wmode;
        currentRun.bidiLevel = glyph.bidiLevel;
        currentRun.direction = glyph.direction;
        if (firstInRun)
            currentRun.trm = glyph.trm;
        currentRun.glyphs.append(glyph);
        currentRun.plainText.append(text);
    }

    if (!currentRun.glyphs.isEmpty())
        runs.append(currentRun);

    return runs;
}

QVector<PdfEditableRegion> PdfTextExtractor::buildEditableRegions(const QVector<PdfGlyph> &glyphs)
{
    QVector<PdfEditableRegion> regions;
    if (glyphs.isEmpty())
        return regions;

    int start = 0;
    while (start < glyphs.size()) {
        const PdfGlyph &first = glyphs.at(start);
        int end = start + 1;
        while (end < glyphs.size()) {
            const PdfGlyph &next = glyphs.at(end);
            if (next.pageIndex != first.pageIndex ||
                next.blockIndex != first.blockIndex ||
                next.lineIndex != first.lineIndex)
                break;
            ++end;
        }

        PdfEditableRegion region;
        region.glyphRange = {start, end - start};
        region.box = unionGlyphBoxes(glyphs, start, end - start);
        region.baselineStart = first.origin;
        const PdfGlyph &last = glyphs.at(end - 1);
        region.baselineEnd = last.origin + last.advance;
        region.unionQuad = QPolygonF()
                           << region.box.topLeft()
                           << region.box.topRight()
                           << region.box.bottomRight()
                           << region.box.bottomLeft();
        region.script = scriptForGlyph(first.unicode);
        region.language = languageForScript(region.script);
        regions.append(region);
        start = end;
    }

    return regions;
}

} // namespace PDFClowne::Editing
