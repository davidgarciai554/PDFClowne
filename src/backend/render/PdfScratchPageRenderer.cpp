#include "PdfScratchPageRenderer.h"

#include "../text/PdfEditTextLayout.h"

#include <QColor>
#include <QDebug>
#include <QUrl>

#include <mupdf/fitz.h>
#include <mupdf/pdf.h>

#include <algorithm>
#include <cmath>

namespace PDFClowne::Render {
namespace {

bool editTraceEnabled()
{
    static const bool enabled = qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_EDIT_INPUT");
    return enabled;
}

void editTrace(const char *prefix, const QString &message)
{
    if (editTraceEnabled())
        qInfo().noquote() << prefix << message;
}

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

QString matrixToString(const QTransform &transform)
{
    return QStringLiteral("(%1,%2,%3,%4,%5,%6)")
        .arg(transform.m11())
        .arg(transform.m12())
        .arg(transform.m21())
        .arg(transform.m22())
        .arg(transform.dx())
        .arg(transform.dy());
}

QString rectToString(const QRectF &rect)
{
    return QStringLiteral("(%1,%2,%3,%4)")
        .arg(rect.x())
        .arg(rect.y())
        .arg(rect.width())
        .arg(rect.height());
}

QPointF normalizedDirection(QPointF direction)
{
    const qreal length = std::hypot(direction.x(), direction.y());
    if (length <= 0.0001)
        return QPointF(1.0, 0.0);
    return direction / length;
}

QTransform textMatrixFromVisualSpace(const PDFClowne::Editing::PdfRun &run,
                                     const QPointF &visualPen,
                                     const PDFClowne::Editing::PdfShapedGlyph &shapedGlyph,
                                     qreal fontSize,
                                     qreal pageHeight)
{
    const PDFClowne::Editing::PdfGlyph &anchor = run.glyphs.constFirst();
    const QPointF visualDirection = normalizedDirection(run.direction);
    const QPointF pdfDirection(visualDirection.x(), -visualDirection.y());
    const QPointF visualDelta = visualPen - anchor.origin;

    const qreal x = anchor.origin.x() + visualDelta.x() + shapedGlyph.offset.x() * fontSize;
    const qreal visualY = anchor.origin.y() + visualDelta.y() + shapedGlyph.offset.y() * fontSize;
    const qreal y = pageHeight - visualY;

    return QTransform(fontSize * pdfDirection.x(),
                      fontSize * pdfDirection.y(),
                      -fontSize * pdfDirection.y(),
                      fontSize * pdfDirection.x(),
                      x,
                      y);
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
    Q_UNUSED(runs)
    Q_UNUSED(fontResolver)
    Q_UNUSED(filePath)
    Q_UNUSED(password)
    return renderGlyphOverlayFromLayouts({}, pixelSize, scale, error);
}

QTransform PdfScratchPageRenderer::textMatrixFromLayoutGlyph(
    const PDFClowne::Editing::PdfEditTextLayoutResult &layout,
    const PDFClowne::Editing::PdfEditLaidOutGlyph &glyph,
    qreal pageHeight)
{
    const QPointF visualDirection = normalizedDirection(layout.style.direction);
    const QPointF pdfDirection(visualDirection.x(), -visualDirection.y());
    const qreal fontSize = std::max<qreal>(1.0, layout.style.effectiveFontSize);
    const qreal horizontalScale = std::max<qreal>(0.01, layout.horizontalScale);
    const qreal x = glyph.origin.x();
    const qreal y = pageHeight - glyph.origin.y();

    return QTransform(fontSize * pdfDirection.x() * horizontalScale,
                      fontSize * pdfDirection.y(),
                      -fontSize * pdfDirection.y(),
                      fontSize * pdfDirection.x(),
                      x,
                      y);
}

QImage PdfScratchPageRenderer::renderGlyphOverlayFromLayouts(
    const QVector<PDFClowne::Editing::PdfEditTextLayoutResult> &layouts,
    const QSize &pixelSize,
    qreal scale,
    QString *error) const
{
    QImage empty(pixelSize, QImage::Format_RGBA8888);
    empty.fill(Qt::transparent);
    if (layouts.isEmpty() || pixelSize.isEmpty() || scale <= 0.0)
        return empty;

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
        const qreal pageHeight = pixelSize.height() / scale;
        const fz_matrix overlayDeviceMatrix = fz_make_matrix(static_cast<float>(scale),
                                                             0.0f,
                                                             0.0f,
                                                             static_cast<float>(-scale),
                                                             0.0f,
                                                             static_cast<float>(pixelSize.height()));
        pix = fz_new_pixmap_with_bbox(ctx, fz_device_rgb(ctx), bbox, nullptr, 1);
        fz_clear_pixmap(ctx, pix);
        device = fz_new_draw_device(ctx, overlayDeviceMatrix, pix);

        for (const PDFClowne::Editing::PdfEditTextLayoutResult &layout : layouts) {
            if (!layout.valid || layout.glyphs.isEmpty())
                continue;

            if (qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_EDIT_METRICS")) {
                qInfo().noquote()
                    << QStringLiteral("[PDF_EDIT_FONT] resourceKey=%1 embedded=%2 fallback=%3 fontName=\"%4\" text=\"%5\"")
                           .arg(layout.style.fontResourceKey)
                           .arg(layout.usedEmbeddedFont)
                           .arg(layout.usedFallbackFont)
                           .arg(layout.debugFontName)
                           .arg(layout.text.left(80));
                qInfo().noquote()
                    << QStringLiteral("[PDF_EDIT_FONT_DECISION] preview text=\"%1\" original=\"\" selected=\"%2\" embeddedOriginal=%3 bundledFallback=%4 subsetRejected=%5 reason=%6")
                           .arg(layout.text.left(60))
                           .arg(layout.fontName)
                           .arg(layout.usedEmbeddedFont)
                           .arg(layout.usedFallbackFont)
                           .arg(layout.debugReason.contains(QStringLiteral("subset-original-rejected")))
                           .arg(layout.debugReason);
            }

            fz_font *font = nullptr;
            if (!layout.fontProgram.isEmpty()) {
                font = fz_new_font_from_memory(ctx,
                                               layout.fontName.toUtf8().constData(),
                                               reinterpret_cast<const unsigned char *>(layout.fontProgram.constData()),
                                               layout.fontProgram.size(),
                                               0,
                                               1);
            } else {
                font = fz_new_base14_font(ctx, "Helvetica");
            }

            fz_text *text = fz_new_text(ctx);
            editTrace("[PDF_EDIT_TRANSFORM]",
                      QStringLiteral("pageHeight=%1 zoom=%2 visualRect=%3 baselineStart=(%4,%5) baselineEnd=(%6,%7) renderMatrix=(%8,%9,%10,%11,%12,%13) finalTransform=layout yInversion=true rotation=false translatePageHeight=true scaleYMinusOne=false")
                          .arg(pageHeight)
                          .arg(scale)
                          .arg(rectToString(layout.visualBox))
                          .arg(layout.baselineStart.x())
                          .arg(layout.baselineStart.y())
                          .arg(layout.baselineEnd.x())
                          .arg(layout.baselineEnd.y())
                          .arg(overlayDeviceMatrix.a)
                          .arg(overlayDeviceMatrix.b)
                          .arg(overlayDeviceMatrix.c)
                          .arg(overlayDeviceMatrix.d)
                          .arg(overlayDeviceMatrix.e)
                          .arg(overlayDeviceMatrix.f));

            for (int i = 0; i < layout.glyphs.size(); ++i) {
                const auto &laidOutGlyph = layout.glyphs.at(i);
                if (laidOutGlyph.glyphId <= 0)
                    continue;
                const QTransform trm = textMatrixFromLayoutGlyph(layout, laidOutGlyph, pageHeight);
                if (editTraceEnabled()) {
                    editTrace("[PDF_EDIT_PAINT_TEXT]",
                              QStringLiteral("editId=%1 text=\"%2\" text.length=%3 visualRect=%4 baseline=(%5,%6) painter.transform=(1,0,0,1,0,0) finalTransform=%7 usingScaleYMinusOne=false usingScaleXMinusOne=false drawMode=MuPDF::fz_show_glyph fontPixelSize=%8")
                                  .arg(layout.style.fontResourceKey)
                                  .arg(layout.text.left(80))
                                  .arg(layout.text.size())
                                  .arg(rectToString(layout.visualBox.normalized()))
                                  .arg(laidOutGlyph.origin.x())
                                  .arg(laidOutGlyph.origin.y())
                                  .arg(matrixToString(trm))
                                  .arg(layout.style.effectiveFontSize));
                    if (trm.m11() < 0.0 || trm.m22() < 0.0)
                        editTrace("[PDF_EDIT_TRANSFORM_ERROR]",
                                  QStringLiteral("negative transform while painting editable text m11=%1 m22=%2")
                                      .arg(trm.m11())
                                      .arg(trm.m22()));
                }
                fz_show_glyph(ctx,
                              text,
                              font,
                              toFzMatrix(trm),
                              static_cast<int>(laidOutGlyph.glyphId),
                              laidOutGlyph.unicode ? static_cast<int>(laidOutGlyph.unicode) : -1,
                              layout.style.wmode,
                              layout.style.bidiLevel,
                              layout.style.bidiLevel % 2 ? FZ_BIDI_RTL : FZ_BIDI_LTR,
                              FZ_LANG_UNSET);
            }

            const QColor color = layout.style.fillColor.isValid() ? layout.style.fillColor : Qt::black;
            editTrace("[PDF_EDIT_PAINT]",
                      QStringLiteral("layout textLength=%1 glyphs=%2 fontSize=%3 fallback=%4")
                          .arg(layout.text.size())
                          .arg(layout.glyphs.size())
                          .arg(layout.style.effectiveFontSize)
                          .arg(layout.usedFallbackFont));
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
