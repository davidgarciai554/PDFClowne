#include "FontFallbackManager.h"

#include <QFont>
#include <QFontDatabase>
#include <QFontMetrics>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>

namespace PDFClowne::Editing {

namespace {

struct BundledFontCandidate {
    const char* family;
    const char* fileName;
};

static constexpr BundledFontCandidate kBundledFonts[] = {
    {"DejaVu Sans", "DejaVuSans.ttf"},
    {"Noto Sans CJK SC", "NotoSansCJK-Regular.otf"},
    {"Noto Sans CJK", "NotoSansCJK-Regular.otf"},
    {"Noto Sans Arabic", "NotoSansArabic-Regular.ttf"},
    {nullptr, nullptr}
};

QString sourceFontsDir()
{
    QDir dir(QCoreApplication::applicationDirPath());
    for (int i = 0; i < 6; ++i) {
        const QString candidate = dir.absoluteFilePath(QStringLiteral("resources/fonts"));
        if (QDir(candidate).exists())
            return candidate;
        if (!dir.cdUp())
            break;
    }
    return {};
}

QString fontPathForFileName(const QString& fileName)
{
    const QString resourcePath = QStringLiteral(":/fonts/%1").arg(fileName);
    if (QFileInfo::exists(resourcePath))
        return resourcePath;

    const QString sourceDir = sourceFontsDir();
    if (!sourceDir.isEmpty()) {
        const QString sourcePath = QDir(sourceDir).absoluteFilePath(fileName);
        if (QFileInfo::exists(sourcePath))
            return sourcePath;
    }
    return {};
}

} // namespace

// Preferred fallback order — wide Unicode coverage first.
static constexpr const char* kCandidates[] = {
    "Arial Unicode MS",
    "Noto Sans",
    "Noto Serif",
    "Noto Sans CJK SC",
    "Noto Sans Arabic",
    "DejaVu Sans",
    "Segoe UI",
    "Tahoma",
    "Arial",
    "Helvetica",
    "Times New Roman",
    nullptr
};

FontFallbackManager::FontFallbackManager()
{
    registerBundledFonts();
    buildChain();
}

bool FontFallbackManager::canFontRenderText(const QString& fontName,
                                             double         fontSize,
                                             const QString& text) const
{
    if (text.isEmpty()) return true;

    QFont font(fontName);
    font.setPointSizeF(fontSize > 0.0 ? fontSize : 12.0);
    QFontMetrics fm(font);

    for (const QChar ch : text) {
        if (ch.isSpace() || ch.isNull() || ch == QLatin1Char('\n')
                || ch == QLatin1Char('\r'))
            continue;
        if (!fm.inFont(ch))
            return false;
    }
    return true;
}

FontFallbackResult FontFallbackManager::selectFontForText(
        const QString& preferredFont,
        double         preferredSize,
        const QString& newText) const
{
    FontFallbackResult result;
    result.resolvedFontSize = preferredSize > 0.0 ? preferredSize : 12.0;

    if (canFontRenderText(preferredFont, preferredSize, newText)) {
        result.resolvedFontName = preferredFont;
        result.fontFilePath     = fontFilePathForFamily(preferredFont);
        result.canEmbed         = !result.fontFilePath.isEmpty();
        result.usedFallback     = false;
        return result;
    }

    for (const QString& family : m_chain) {
        if (family == preferredFont) continue;
        if (canFontRenderText(family, preferredSize, newText)) {
            result.resolvedFontName = family;
            result.fontFilePath     = fontFilePathForFamily(family);
            result.canEmbed         = !result.fontFilePath.isEmpty();
            result.usedFallback     = true;
            result.fallbackReason   =
                QStringLiteral("Font \"%1\" lacks required glyphs; "
                               "using \"%2\" as fallback.")
                    .arg(preferredFont, family);
            return result;
        }
    }

    // Last resort: let Qt pick via font substitution
    result.resolvedFontName = preferredFont;
    result.usedFallback     = true;
    result.fallbackReason   =
        QStringLiteral("No installed font covers all characters in the new "
                       "text; Qt will substitute glyphs automatically.");
    return result;
}

QString FontFallbackManager::fontFilePathForFamily(const QString& family) const
{
    for (int i = 0; kBundledFonts[i].family != nullptr; ++i) {
        if (family.compare(QString::fromLatin1(kBundledFonts[i].family), Qt::CaseInsensitive) == 0)
            return fontPathForFileName(QString::fromLatin1(kBundledFonts[i].fileName));
    }
    return {};
}

void FontFallbackManager::registerBundledFonts()
{
    for (int i = 0; kBundledFonts[i].family != nullptr; ++i) {
        const QString path = fontPathForFileName(QString::fromLatin1(kBundledFonts[i].fileName));
        if (!path.isEmpty())
            QFontDatabase::addApplicationFont(path);
    }
}

void FontFallbackManager::buildChain()
{
    const QStringList installed = QFontDatabase::families();
    for (int i = 0; kCandidates[i] != nullptr; ++i) {
        const QString fam = QString::fromLatin1(kCandidates[i]);
        if (installed.contains(fam, Qt::CaseInsensitive))
            m_chain.append(fam);
    }

    for (int i = 0; kBundledFonts[i].family != nullptr; ++i) {
        const QString family = QString::fromLatin1(kBundledFonts[i].family);
        if (!m_chain.contains(family, Qt::CaseInsensitive) && !fontFilePathForFamily(family).isEmpty())
            m_chain.append(family);
    }
}

} // namespace PDFClowne::Editing
