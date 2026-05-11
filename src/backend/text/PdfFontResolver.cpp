#include "PdfFontResolver.h"

#include <QRegularExpression>
#include <QUrl>

#include <mupdf/fitz.h>
#include <mupdf/pdf.h>

namespace PDFClowne::Editing {
namespace {

QString toLocalPath(const QString &source)
{
    if (source.startsWith(QLatin1String("file://"), Qt::CaseInsensitive))
        return QUrl(source).toLocalFile();
    return source;
}

struct ParsedResourceKey {
    int pageObjectRef = -1;
    QString fontResourceName;
    int fontXref = -1;
};

ParsedResourceKey parseResourceKey(const QString &key)
{
    ParsedResourceKey parsed;
    static const QRegularExpression expression(
        QStringLiteral("^page:(\\d+)/font:([^/]+)/xref:(\\d+)$"));
    const QRegularExpressionMatch match = expression.match(key);
    if (!match.hasMatch())
        return parsed;

    parsed.pageObjectRef = match.captured(1).toInt();
    parsed.fontResourceName = match.captured(2);
    parsed.fontXref = match.captured(3).toInt();
    return parsed;
}

QByteArray bufferToByteArray(fz_context *ctx, fz_buffer *buffer)
{
    if (!ctx || !buffer)
        return {};

    unsigned char *data = nullptr;
    const size_t size = fz_buffer_storage(ctx, buffer, &data);
    if (!data || size == 0)
        return {};

    return QByteArray(reinterpret_cast<const char *>(data), static_cast<qsizetype>(size));
}

pdf_obj *embeddedFontStream(fz_context *ctx, pdf_obj *fontObject)
{
    if (!ctx || !fontObject)
        return nullptr;

    pdf_obj *descriptor = pdf_dict_get(ctx, fontObject, PDF_NAME(FontDescriptor));
    if (!descriptor)
        return nullptr;

    pdf_obj *stream = pdf_dict_get(ctx, descriptor, PDF_NAME(FontFile));
    if (!stream)
        stream = pdf_dict_get(ctx, descriptor, PDF_NAME(FontFile2));
    if (!stream)
        stream = pdf_dict_get(ctx, descriptor, PDF_NAME(FontFile3));

    return stream;
}

QString baseFontName(fz_context *ctx, pdf_obj *fontObject)
{
    if (!ctx || !fontObject)
        return {};

    pdf_obj *baseFont = pdf_dict_get(ctx, fontObject, PDF_NAME(BaseFont));
    return pdf_is_name(ctx, baseFont) ? QString::fromUtf8(pdf_to_name(ctx, baseFont)) : QString();
}

} // namespace

QString PdfFontResolver::debugFamilyName(const QString &pdfFontName)
{
    const int subsetMarker = pdfFontName.indexOf(QLatin1Char('+'));
    if (subsetMarker > 0)
        return pdfFontName.mid(subsetMarker + 1);
    return pdfFontName;
}

PdfFontResolver::ResolvedFont PdfFontResolver::resolveEmbeddedFont(const QString &filePath,
                                                                    const QString &password,
                                                                    const QString &fontResourceKey) const
{
    ResolvedFont result;
    result.fontResourceKey = fontResourceKey;

    const ParsedResourceKey parsedKey = parseResourceKey(fontResourceKey);
    if (parsedKey.fontXref < 0 || parsedKey.fontResourceName.isEmpty()) {
        result.error = QStringLiteral("Font resource key is not a PDF resource identity.");
        return result;
    }

    fz_context *ctx = nullptr;
    fz_document *doc = nullptr;
    pdf_document *pdfDoc = nullptr;
    pdf_page *page = nullptr;
    fz_buffer *fontBuffer = nullptr;

    ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) {
        result.error = QStringLiteral("MuPDF could not create a font resolver context.");
        return result;
    }

    const QByteArray pathBytes = toLocalPath(filePath).toUtf8();
    const QByteArray passwordBytes = password.toUtf8();

    fz_try(ctx)
    {
        fz_register_document_handlers(ctx);
        doc = fz_open_document(ctx, pathBytes.constData());
        if (fz_needs_password(ctx, doc)) {
            if (passwordBytes.isEmpty() || !fz_authenticate_password(ctx, doc, passwordBytes.constData()))
                fz_throw(ctx, FZ_ERROR_GENERIC, "Incorrect password for embedded font resolution.");
        }

        pdfDoc = pdf_specifics(ctx, doc);
        if (!pdfDoc)
            fz_throw(ctx, FZ_ERROR_GENERIC, "Font resolution requires a PDF document.");

        const int pageCount = pdf_count_pages(ctx, pdfDoc);
        for (int pageIndex = 0; pageIndex < pageCount; ++pageIndex) {
            pdf_obj *pageObj = pdf_lookup_page_obj(ctx, pdfDoc, pageIndex);
            if (!pageObj || pdf_to_num(ctx, pageObj) != parsedKey.pageObjectRef)
                continue;

            page = pdf_load_page(ctx, pdfDoc, pageIndex);
            pdf_obj *resources = pdf_page_resources(ctx, page);
            pdf_obj *fonts = pdf_dict_get(ctx, resources, PDF_NAME(Font));
            pdf_obj *fontObject = fonts
                ? pdf_dict_gets(ctx, fonts, parsedKey.fontResourceName.toUtf8().constData())
                : nullptr;
            if (!fontObject || pdf_to_num(ctx, fontObject) != parsedKey.fontXref)
                break;

            result.originalSubsetName = baseFontName(ctx, fontObject);
            result.debugFamilyName = debugFamilyName(result.originalSubsetName);
            pdf_obj *stream = embeddedFontStream(ctx, fontObject);
            if (!stream) {
                result.requiresSubstitute = true;
                result.error = QStringLiteral("PDF font resource has no embedded font stream.");
                break;
            }

            fontBuffer = pdf_load_stream(ctx, stream);
            result.fontProgram = bufferToByteArray(ctx, fontBuffer);
            result.requiresSubstitute = result.fontProgram.isEmpty();
            if (result.requiresSubstitute)
                result.error = QStringLiteral("Embedded font stream is empty.");
            break;
        }
    }
    fz_catch(ctx)
    {
        result.requiresSubstitute = true;
        result.error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (fontBuffer)
        fz_drop_buffer(ctx, fontBuffer);
    if (page)
        pdf_drop_page(ctx, page);
    if (doc)
        fz_drop_document(ctx, doc);
    fz_drop_context(ctx);

    return result;
}

} // namespace PDFClowne::Editing
