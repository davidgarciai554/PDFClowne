#include "FontFallbackManager.h"

#include <QFont>
#include <QFontDatabase>
#include <QFontMetrics>

namespace PDFClowne::Editing {

// Preferred fallback order — wide Unicode coverage first.
static constexpr const char* kCandidates[] = {
    "Arial Unicode MS",
    "Noto Sans",
    "Noto Serif",
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
        result.usedFallback     = false;
        return result;
    }

    for (const QString& family : m_chain) {
        if (family == preferredFont) continue;
        if (canFontRenderText(family, preferredSize, newText)) {
            result.resolvedFontName = family;
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

void FontFallbackManager::buildChain()
{
    const QStringList installed = QFontDatabase::families();
    for (int i = 0; kCandidates[i] != nullptr; ++i) {
        const QString fam = QString::fromLatin1(kCandidates[i]);
        if (installed.contains(fam, Qt::CaseInsensitive))
            m_chain.append(fam);
    }
}

} // namespace PDFClowne::Editing
