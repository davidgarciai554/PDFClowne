#pragma once

#include <QColor>
#include <QStringList>

namespace PDFClowne::Editing {

struct FontFallbackResult {
    QString resolvedFontName;
    double  resolvedFontSize  = 0.0;
    bool    usedFallback      = false;
    QString fallbackReason;
};

// Determines whether a named font can render a given string and, when it
// cannot, picks the best available system fallback.  Qt-only (no PDFium).
class FontFallbackManager {
public:
    FontFallbackManager();

    // True when every non-whitespace codepoint in `text` has a glyph in the
    // named font at `fontSize` points.
    bool canFontRenderText(const QString& fontName, double fontSize,
                           const QString& text) const;

    // Returns the best font for `newText`.  Tries `preferredFont` first,
    // then each entry in fallbackChain() in order.  `preferredFont` is
    // returned unchanged if it covers all characters (usedFallback = false).
    FontFallbackResult selectFontForText(const QString& preferredFont,
                                         double         preferredSize,
                                         const QString& newText) const;

    // Ordered list of fallback families (filtered to those actually installed).
    const QStringList& fallbackChain() const { return m_chain; }

private:
    QStringList m_chain;

    void buildChain();
};

} // namespace PDFClowne::Editing
