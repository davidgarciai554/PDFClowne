#include "PdfFontResourceWriter.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>

namespace PDFClowne::Editing {
namespace {

QString resourceNameFromKey(const QString &key)
{
    const QString marker = QStringLiteral("/font:");
    const int start = key.indexOf(marker);
    if (start < 0)
        return {};

    const int nameStart = start + marker.size();
    const int end = key.indexOf(QLatin1Char('/'), nameStart);
    return end < 0 ? key.mid(nameStart) : key.mid(nameStart, end - nameStart);
}

bool containsCodepointInRange(const QString &text, uint first, uint last)
{
    const QVector<uint> codepoints = text.toUcs4();
    for (uint codepoint : codepoints) {
        if (codepoint >= first && codepoint <= last)
            return true;
    }
    return false;
}

QString bundledFontFileNameForText(const QString &text)
{
    if (containsCodepointInRange(text, 0x0590, 0x08FF)
        || containsCodepointInRange(text, 0xFB1D, 0xFEFC)) {
        return QStringLiteral("NotoSansArabic-Regular.ttf");
    }

    if (containsCodepointInRange(text, 0x3040, 0x9FFF))
        return QStringLiteral("NotoSansCJK-Regular.otf");

    return QStringLiteral("DejaVuSans.ttf");
}

const char *bundledFontNameForFileName(const QString &fileName)
{
    if (fileName == QLatin1String("NotoSansArabic-Regular.ttf"))
        return "NotoSansArabic";
    if (fileName == QLatin1String("NotoSansCJK-Regular.otf"))
        return "NotoSansCJK";
    return "DejaVuSans";
}

QByteArray loadBundledFontProgram(const QString &fileName)
{
    QFile resourceFont(QStringLiteral(":/fonts/%1").arg(fileName));
    if (resourceFont.open(QIODevice::ReadOnly))
        return resourceFont.readAll();

    QDir dir(QCoreApplication::applicationDirPath());
    for (int i = 0; i < 8; ++i) {
        const QString candidate = dir.absoluteFilePath(
            QStringLiteral("resources/fonts/%1").arg(fileName));
        QFile fontFile(candidate);
        if (fontFile.open(QIODevice::ReadOnly))
            return fontFile.readAll();
        if (!dir.cdUp())
            break;
    }

    QFile sourceFont(QStringLiteral("resources/fonts/%1").arg(fileName));
    if (sourceFont.open(QIODevice::ReadOnly))
        return sourceFont.readAll();

    return {};
}

const QByteArray &bundledFontProgram(const QString &fileName)
{
    static const QByteArray dejavu = loadBundledFontProgram(QStringLiteral("DejaVuSans.ttf"));
    static const QByteArray arabic = loadBundledFontProgram(QStringLiteral("NotoSansArabic-Regular.ttf"));
    static const QByteArray cjk = loadBundledFontProgram(QStringLiteral("NotoSansCJK-Regular.otf"));

    if (fileName == QLatin1String("NotoSansArabic-Regular.ttf"))
        return arabic;
    if (fileName == QLatin1String("NotoSansCJK-Regular.otf"))
        return cjk;
    return dejavu;
}

QByteArray encodeIdentityHGlyphs(fz_context *ctx, fz_font *font, const QString &text)
{
    QByteArray output;
    const QVector<uint> codepoints = text.toUcs4();
    output.reserve(codepoints.size() * 2);

    for (uint codepoint : codepoints) {
        int gid = fz_encode_character(ctx, font, static_cast<int>(codepoint));
        if (gid <= 0)
            gid = fz_encode_character(ctx, font, '?');
        if (gid <= 0)
            return {};

        output.append(char((gid >> 8) & 0xFF));
        output.append(char(gid & 0xFF));
    }

    return output;
}

} // namespace

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

    const QString originalResourceName = resourceNameFromKey(run.fontResourceKey);
    const bool winAnsi = canUseWinAnsi(newText);
    if (winAnsi && !originalResourceName.isEmpty()
        && pdf_dict_gets(ctx, fonts, originalResourceName.toUtf8().constData())) {
        plan.resourceName = originalResourceName;
        plan.debugFontName = run.glyphs.isEmpty()
            ? originalResourceName
            : run.glyphs.constFirst().fontName;
        plan.winAnsi = true;
        plan.hexString = false;
        plan.fallbackFont = false;
        plan.encodedText = encodeWinAnsi(newText);
        return plan;
    }

    fz_font *font = nullptr;
    fz_try(ctx)
    {
        const QString fallbackFontFileName = bundledFontFileNameForText(newText);
        const QByteArray &fallbackFontProgram = winAnsi ? QByteArray() : bundledFontProgram(fallbackFontFileName);

        if (winAnsi) {
            font = fz_new_base14_font(ctx, "Helvetica");
        } else if (!fallbackFontProgram.isEmpty()) {
            font = fz_new_font_from_memory(ctx,
                                           bundledFontNameForFileName(fallbackFontFileName),
                                           reinterpret_cast<const unsigned char *>(fallbackFontProgram.constData()),
                                           static_cast<int>(fallbackFontProgram.size()),
                                           0,
                                           0);
        } else {
            font = fz_new_base14_font(ctx, "Helvetica");
        }

        pdf_obj *fontRef = winAnsi
            ? pdf_add_simple_font(ctx, doc, font, PDF_SIMPLE_ENCODING_LATIN)
            : pdf_add_cid_font(ctx, doc, font);

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
        plan.debugFontName = winAnsi ? QStringLiteral("Helvetica") : fallbackFontFileName;
        plan.winAnsi = winAnsi;
        plan.identityH = !winAnsi;
        plan.hexString = !plan.winAnsi;
        plan.fallbackFont = true;

        if (plan.winAnsi)
            plan.encodedText = encodeWinAnsi(newText);
        else
            plan.encodedText = encodeIdentityHGlyphs(ctx, font, newText);

        if (plan.encodedText.isEmpty())
            fz_throw(ctx, FZ_ERROR_GENERIC, "Fallback font could not encode replacement text.");
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
