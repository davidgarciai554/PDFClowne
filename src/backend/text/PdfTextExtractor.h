#pragma once

#include "PdfGlyphRunModel.h"

#include <QHash>
#include <QString>

namespace PDFClowne::Editing {

class PdfTextExtractor {
public:
    struct PageText {
        QVector<PdfGlyph> glyphs;
        QVector<PdfRun> runs;
        QVector<PdfEditableRegion> regions;
        QString error;
    };

    PageText extractPage(const QString &filePath,
                         const QString &password,
                         int pageIndex) const;

    static int structuredTextFlags();
    static QString resourceKey(int pageObjectRef, const QString &fontResourceName, int fontXref);

    struct FontResource {
        QString resourceName;
        QString baseFont;
        QString key;
        int xref = 0;
    };

    using FontResourceMap = QHash<QString, FontResource>;

private:
    static QVector<PdfRun> buildRuns(const QVector<PdfGlyph> &glyphs);
    static QVector<PdfEditableRegion> buildEditableRegions(const QVector<PdfGlyph> &glyphs);
};

} // namespace PDFClowne::Editing
