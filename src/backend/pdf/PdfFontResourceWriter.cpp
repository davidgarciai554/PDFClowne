#include "PdfFontResourceWriter.h"

namespace PDFClowne::Editing {

bool PdfFontResourceWriter::canUseWinAnsi(const QString &text)
{
    for (const QChar &ch : text) {
        const ushort u = ch.unicode();
        if (u < 32 && u != '\n' && u != '\r' && u != '\t')
            return false;
        if (u > 255)
            return false;
    }
    return true;
}

QByteArray PdfFontResourceWriter::encodeWinAnsi(const QString &text)
{
    QByteArray output;
    output.reserve(text.size());
    for (const QChar &ch : text)
        output.append(static_cast<char>(ch.unicode() & 0xFF));
    return output;
}

QByteArray PdfFontResourceWriter::encodeUtf16Be(const QString &text)
{
    QByteArray output;
    output.reserve(2 + text.size() * 2);
    output.append(char(0xFE));
    output.append(char(0xFF));

    for (const QChar &ch : text) {
        const ushort u = ch.unicode();
        output.append(char((u >> 8) & 0xFF));
        output.append(char(u & 0xFF));
    }

    return output;
}

PdfFontWritePlan PdfFontResourceWriter::ensureFontForText(fz_context *ctx,
                                                          pdf_document *doc,
                                                          pdf_page *page,
                                                          const PdfRun &run,
                                                          const QString &newText,
                                                          QString *error) const
{
    Q_UNUSED(run)

    PdfFontWritePlan plan;

    pdf_obj *resources = pdf_page_resources(ctx, page);
    if (!resources) {
        resources = pdf_new_dict(ctx, doc, 4);
        pdf_dict_put_drop(ctx, page->obj, PDF_NAME(Resources), resources);
        resources = pdf_page_resources(ctx, page);
    }

    pdf_obj *fonts = pdf_dict_get(ctx, resources, PDF_NAME(Font));
    if (!fonts)
        fonts = pdf_dict_put_dict(ctx, resources, PDF_NAME(Font), 4);

    fz_font *font = nullptr;
    fz_try(ctx)
    {
        font = fz_new_base14_font(ctx, "Helvetica");
        pdf_obj *fontRef = pdf_add_simple_font(ctx, doc, font, PDF_SIMPLE_ENCODING_LATIN);

        QString resourceName;
        for (int i = 0; i < 1000; ++i) {
            const QString candidate = i == 0
                ? QStringLiteral("PclEditF")
                : QStringLiteral("PclEditF%1").arg(i);

            if (!pdf_dict_gets(ctx, fonts, candidate.toUtf8().constData())) {
                pdf_dict_puts(ctx, fonts, candidate.toUtf8().constData(), fontRef);
                resourceName = candidate;
                break;
            }
        }

        if (resourceName.isEmpty())
            fz_throw(ctx, FZ_ERROR_GENERIC, "No free font resource name available.");

        plan.resourceName = resourceName;
        plan.debugFontName = QStringLiteral("Helvetica");
        plan.winAnsi = canUseWinAnsi(newText);
        plan.hexString = !plan.winAnsi;
        plan.fallbackFont = true;

        if (plan.winAnsi)
            plan.encodedText = encodeWinAnsi(newText);
        else
            plan.encodedText = encodeUtf16Be(newText);
    }
    fz_always(ctx)
    {
        if (font)
            fz_drop_font(ctx, font);
    }
    fz_catch(ctx)
    {
        if (error)
            *error = QString::fromUtf8(fz_caught_message(ctx));
        plan = {};
    }

    return plan;
}

} // namespace PDFClowne::Editing
