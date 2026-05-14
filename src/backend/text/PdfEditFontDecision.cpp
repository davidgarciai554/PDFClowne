#include "PdfEditFontDecision.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>

namespace PDFClowne::Editing {
namespace {

bool containsCodepointInRange(const QString &text, uint first, uint last)
{
    const QVector<uint> codepoints = text.toUcs4();
    for (uint codepoint : codepoints) {
        if (codepoint >= first && codepoint <= last)
            return true;
    }
    return false;
}

QString fallbackFontFileForStyle(bool bold, bool italic, const QString &text)
{
    if (containsCodepointInRange(text, 0x0590, 0x08FF)
        || containsCodepointInRange(text, 0xFB1D, 0xFEFC)) {
        return QStringLiteral("NotoSansArabic-Regular.ttf");
    }

    if (containsCodepointInRange(text, 0x3040, 0x9FFF))
        return QStringLiteral("NotoSansCJK-Regular.otf");

    if (bold || italic)
        return QStringLiteral("DejaVuSans.ttf");

    return QStringLiteral("DejaVuSans.ttf");
}

QString bundledFontNameForFileName(const QString &fileName)
{
    if (fileName == QLatin1String("NotoSansArabic-Regular.ttf"))
        return QStringLiteral("NotoSansArabic");
    if (fileName == QLatin1String("NotoSansCJK-Regular.otf"))
        return QStringLiteral("NotoSansCJK");
    return QStringLiteral("DejaVuSans");
}

QByteArray loadBundledFontProgram(const QString &fileName)
{
    QFile resourceFont(QStringLiteral(":/fonts/%1").arg(fileName));
    if (resourceFont.open(QIODevice::ReadOnly))
        return resourceFont.readAll();

    QDir dir(QCoreApplication::applicationDirPath());
    for (int i = 0; i < 8; ++i) {
        QFile fontFile(dir.absoluteFilePath(QStringLiteral("resources/fonts/%1").arg(fileName)));
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

} // namespace

PdfEditFontDecision PdfEditFontDecisionService::decideFontForEditedText(
    const PdfFontResolver::ResolvedFont &resolved,
    const QString &replacementText,
    bool bold,
    bool italic) const
{
    PdfEditFontDecision decision;
    const bool subsetOriginal = resolved.originalSubsetName.contains(QLatin1Char('+'));

    if (!resolved.fontProgram.isEmpty() && !subsetOriginal) {
        const PdfFontResolver resolver;
        const PdfFontResolver::FontValidationResult validation =
            resolver.validateFontProgramForText(resolved.fontProgram,
                                                resolved.originalSubsetName,
                                                replacementText);
        if (validation.usableForEditedText) {
            decision.fontName = resolved.originalSubsetName.isEmpty()
                ? resolved.debugFamilyName
                : resolved.originalSubsetName;
            decision.fontProgram = resolved.fontProgram;
            decision.useEmbeddedOriginal = true;
            decision.reason = QStringLiteral("embedded-original-safe");
            return decision;
        }
        decision.reason = validation.reason;
    }

    decision.subsetOriginalRejected = subsetOriginal;
    decision.useBundledFallback = true;
    decision.fontFileName = fallbackFontFileForStyle(bold, italic, replacementText);
    decision.fontProgram = loadBundledFontProgram(decision.fontFileName);
    decision.fontName = bundledFontNameForFileName(decision.fontFileName);
    decision.reason = decision.subsetOriginalRejected
        ? QStringLiteral("subset-original-rejected-using-style-compatible-fallback")
        : QStringLiteral("embedded-original-unusable-using-style-compatible-fallback");
    if (decision.fontProgram.isEmpty())
        decision.reason += QStringLiteral("-font-program-missing");

    return decision;
}

} // namespace PDFClowne::Editing
