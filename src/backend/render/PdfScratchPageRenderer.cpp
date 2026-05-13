#include "PdfScratchPageRenderer.h"

#include <QColor>
#include <QUrl>

#include <hb.h>

#include <mupdf/fitz.h>
#include <mupdf/pdf.h>

#include <algorithm>

namespace PDFClowne::Render {
namespace {

QString toLocalPath(const QString &source)
{
    if (source.startsWith(QLatin1String("file://"), Qt::CaseInsensitive))
        return QUrl(source).toLocalFile();
    return source;
}

fz_matrix toFzMatrix(const QTransform &transform)
{
    return fz_make_matrix(static_cast<float>(transform.m11()),
                          static_cast<float>(transform.m12()),
                          static_cast<float>(transform.m21()),
                          static_cast<float>(transform.m22()),
                          static_cast<float>(transform.dx()),
                          static_cast<float>(transform.dy()));
}

fz_quad toFzQuad(const QPolygonF &quad)
{
    fz_quad value;
    const QPointF ul = quad.value(0);
    const QPointF ur = quad.value(1);
    const QPointF lr = quad.value(2);
    const QPointF ll = quad.value(3);
    value.ul = fz_make_point(static_cast<float>(ul.x()), static_cast<float>(ul.y()));
    value.ur = fz_make_point(static_cast<float>(ur.x()), static_cast<float>(ur.y()));
    value.lr = fz_make_point(static_cast<float>(lr.x()), static_cast<float>(lr.y()));
    value.ll = fz_make_point(static_cast<float>(ll.x()), static_cast<float>(ll.y()));
    return value;
}

fz_rect toFzRect(const QRectF &rect)
{
    return fz_make_rect(static_cast<float>(rect.left()),
                        static_cast<float>(rect.top()),
                        static_cast<float>(rect.right()),
                        static_cast<float>(rect.bottom()));
}

QImage renderPage(fz_context *ctx, fz_document *doc, int pageIndex, qreal scale)
{
    fz_pixmap *pix = nullptr;
    QImage image;

    fz_try(ctx)
    {
        pix = fz_new_pixmap_from_page_number(ctx,
                                             doc,
                                             pageIndex,
                                             fz_scale(static_cast<float>(scale), static_cast<float>(scale)),
                                             fz_device_rgb(ctx),
                                             0);
        image = PdfScratchPageRenderer::pixmapToImage(pix);
    }
    fz_always(ctx)
    {
        if (pix)
            fz_drop_pixmap(ctx, pix);
    }
    fz_catch(ctx)
    {
        image = {};
    }

    return image;
}

QByteArray runTextUtf8(const PDFClowne::Editing::PdfRun &run)
{
    return run.plainText.toUtf8();
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

} // namespace

QImage PdfScratchPageRenderer::pixmapToImage(fz_pixmap *pixmap)
{
    if (!pixmap || pixmap->w <= 0 || pixmap->h <= 0)
        return {};

    QImage::Format format = QImage::Format_Invalid;
    if (pixmap->n == 3)
        format = QImage::Format_RGB888;
    else if (pixmap->n == 4)
        format = QImage::Format_RGBA8888;
    else
        return {};

    return QImage(pixmap->samples, pixmap->w, pixmap->h, pixmap->stride, format).copy();
}

QVector<PDFClowne::Editing::PdfShapedGlyph> PdfScratchPageRenderer::shapeRun(
    const PDFClowne::Editing::PdfRun &run,
    const QByteArray &fontProgram)
{
    QVector<PDFClowne::Editing::PdfShapedGlyph> shaped;
    if (run.plainText.isEmpty() || fontProgram.isEmpty())
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
    const QByteArray utf8 = runTextUtf8(run);
    hb_buffer_add_utf8(buffer, utf8.constData(), utf8.size(), 0, utf8.size());
    const uint firstUnicode = run.plainText.isEmpty()
        ? (run.glyphs.isEmpty() ? 0u : run.glyphs.constFirst().unicode)
        : static_cast<uint>(run.plainText.at(0).unicode());
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
        PDFClowne::Editing::PdfShapedGlyph glyph;
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

QImage PdfScratchPageRenderer::renderRedactedBase(const QString &filePath,
                                                  const QString &password,
                                                  int pageIndex,
                                                  const QVector<QPolygonF> &redactionQuads,
                                                  qreal scale,
                                                  QString *error) const
{
    fz_context *ctx = nullptr;
    fz_document *doc = nullptr;
    pdf_document *pdfDoc = nullptr;
    pdf_page *page = nullptr;
    QString caught;
    QImage image;

    ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) {
        if (error)
            *error = QStringLiteral("MuPDF could not create a scratch render context.");
        return {};
    }

    const QByteArray pathBytes = toLocalPath(filePath).toUtf8();
    const QByteArray passwordBytes = password.toUtf8();

    fz_try(ctx)
    {
        fz_register_document_handlers(ctx);
        doc = fz_open_document(ctx, pathBytes.constData());
        if (fz_needs_password(ctx, doc)) {
            if (passwordBytes.isEmpty() || !fz_authenticate_password(ctx, doc, passwordBytes.constData()))
                fz_throw(ctx, FZ_ERROR_GENERIC, "Incorrect password for scratch rendering.");
        }

        pdfDoc = pdf_specifics(ctx, doc);
        if (pdfDoc && !redactionQuads.isEmpty()) {
            page = pdf_load_page(ctx, pdfDoc, pageIndex);
            for (const QPolygonF &quad : redactionQuads) {
                const fz_quad fzQuad = toFzQuad(quad);
                pdf_annot *annot = pdf_create_annot(ctx, page, PDF_ANNOT_REDACT);
                pdf_set_annot_rect(ctx, annot, fz_rect_from_quad(fzQuad));
                pdf_set_annot_quad_points(ctx, annot, 1, &fzQuad);
            }

            pdf_redact_options options = {};
            options.black_boxes = 0;
            options.image_method = PDF_REDACT_IMAGE_NONE;
            options.line_art = PDF_REDACT_LINE_ART_NONE;
            options.text = PDF_REDACT_TEXT_REMOVE;
            pdf_redact_page(ctx, pdfDoc, page, &options);
        }

        image = renderPage(ctx, doc, pageIndex, scale);
    }
    fz_catch(ctx)
    {
        caught = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (page)
        pdf_drop_page(ctx, page);
    if (doc)
        fz_drop_document(ctx, doc);
    fz_drop_context(ctx);

    if (!caught.isEmpty() && error)
        *error = caught;
    return caught.isEmpty() ? image : QImage();
}

QImage PdfScratchPageRenderer::renderGlyphOverlay(
    const QVector<PDFClowne::Editing::PdfRun> &runs,
    const PDFClowne::Editing::PdfFontResolver &fontResolver,
    const QString &filePath,
    const QString &password,
    const QSize &pixelSize,
    qreal scale,
    QString *error) const
{
    if (runs.isEmpty() || pixelSize.isEmpty() || scale <= 0.0)
        return QImage(pixelSize, QImage::Format_RGBA8888);

    fz_context *ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) {
        if (error)
            *error = QStringLiteral("MuPDF could not create a glyph overlay context.");
        return {};
    }

    fz_pixmap *pix = nullptr;
    fz_device *device = nullptr;
    QImage image;
    QString caught;

    fz_try(ctx)
    {
        const fz_irect bbox = fz_make_irect(0, 0, pixelSize.width(), pixelSize.height());
        pix = fz_new_pixmap_with_bbox(ctx, fz_device_rgb(ctx), bbox, nullptr, 1);
        fz_clear_pixmap(ctx, pix);
        device = fz_new_draw_device(ctx, fz_scale(static_cast<float>(scale), static_cast<float>(scale)), pix);

        for (const PDFClowne::Editing::PdfRun &run : runs) {
            if (run.glyphs.isEmpty())
                continue;

            const PDFClowne::Editing::PdfFontResolver::ResolvedFont resolved =
                fontResolver.resolveEmbeddedFont(filePath, password, run.fontResourceKey);
            bool forceFallbackFont = false;

            QString originalFromGlyphs;
            for (const PDFClowne::Editing::PdfGlyph &glyph : run.glyphs) {
                const char32_t scalar = static_cast<char32_t>(glyph.unicode);
                if (scalar)
                    originalFromGlyphs.append(QString::fromUcs4(&scalar, 1));
            }

            if (run.plainText != originalFromGlyphs)
                forceFallbackFont = true;

            fz_font *font = nullptr;
            if (!forceFallbackFont && !resolved.fontProgram.isEmpty()) {
                font = fz_new_font_from_memory(ctx,
                                               resolved.originalSubsetName.toUtf8().constData(),
                                               reinterpret_cast<const unsigned char *>(resolved.fontProgram.constData()),
                                               resolved.fontProgram.size(),
                                               0,
                                               1);
            } else {
                font = fz_new_base14_font(ctx, "Helvetica");
            }

            QVector<PDFClowne::Editing::PdfShapedGlyph> shaped;
            if (!forceFallbackFont && !resolved.fontProgram.isEmpty())
                shaped = shapeRun(run, resolved.fontProgram);

            if (shaped.isEmpty() || forceFallbackFont) {
                shaped.clear();
                shaped.reserve(run.plainText.size());

                for (const QChar &ch : run.plainText) {
                    const int unicode = ch.unicode();
                    int gid = fz_encode_character(ctx, font, unicode);
                    if (gid <= 0)
                        gid = fz_encode_character(ctx, font, '?');

                    PDFClowne::Editing::PdfShapedGlyph shapedGlyph;
                    shapedGlyph.glyphId = static_cast<uint>(std::max(0, gid));
                    shapedGlyph.cluster = static_cast<uint>(shaped.size());
                    const float advance = fz_advance_glyph(ctx,
                                                           font,
                                                           static_cast<int>(shapedGlyph.glyphId),
                                                           run.wmode);
                    shapedGlyph.advance = QPointF(advance, 0.0);
                    shaped.append(shapedGlyph);
                }
            }

            fz_text *text = fz_new_text(ctx);
            QPointF pen = run.glyphs.constFirst().origin;
            const qreal fontSize = std::max<qreal>(1.0, run.glyphs.constFirst().fontSize);
            for (int i = 0; i < shaped.size(); ++i) {
                const auto &shapedGlyph = shaped.at(i);
                QTransform trm = run.glyphs.constFirst().trm;
                trm.translate((pen.x() - run.glyphs.constFirst().origin.x()) / fontSize + shapedGlyph.offset.x(),
                              (pen.y() - run.glyphs.constFirst().origin.y()) / fontSize + shapedGlyph.offset.y());
                fz_show_glyph(ctx,
                              text,
                              font,
                              toFzMatrix(trm),
                              static_cast<int>(shapedGlyph.glyphId),
                              i < run.plainText.size() ? run.plainText.at(i).unicode() : -1,
                              run.wmode,
                              run.bidiLevel,
                              run.bidiLevel % 2 ? FZ_BIDI_RTL : FZ_BIDI_LTR,
                              FZ_LANG_UNSET);
                pen += shapedGlyph.advance * fontSize;
            }

            const QColor color = run.fillColor.isValid() ? run.fillColor : Qt::black;
            float components[3] = {
                static_cast<float>(color.redF()),
                static_cast<float>(color.greenF()),
                static_cast<float>(color.blueF())
            };
            fz_fill_text(ctx,
                         device,
                         text,
                         fz_identity,
                         fz_device_rgb(ctx),
                         components,
                         static_cast<float>(color.alphaF()),
                         fz_default_color_params);
            fz_drop_text(ctx, text);
            fz_drop_font(ctx, font);
        }

        fz_close_device(ctx, device);
        image = pixmapToImage(pix);
    }
    fz_catch(ctx)
    {
        caught = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (device)
        fz_drop_device(ctx, device);
    if (pix)
        fz_drop_pixmap(ctx, pix);
    fz_drop_context(ctx);

    if (!caught.isEmpty() && error)
        *error = caught;
    return caught.isEmpty() ? image : QImage();
}

} // namespace PDFClowne::Render
