#pragma once

#include "../../src/backend/text/PdfEditSessionController.h"
#include "../../src/backend/text/PdfTextExtractor.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointF>
#include <QString>

#include <algorithm>
#include <iostream>

namespace PdfTextEditSaveTestUtils {

inline int fail(const QString &message)
{
    std::cerr << message.toStdString() << '\n';
    return 1;
}

inline QString pagePlainText(const PDFClowne::Editing::PdfTextExtractor::PageText &page)
{
    QString output;
    output.reserve(page.glyphs.size());
    for (const PDFClowne::Editing::PdfGlyph &glyph : page.glyphs) {
        const char32_t scalar = static_cast<char32_t>(glyph.unicode);
        if (scalar)
            output.append(QString::fromUcs4(&scalar, 1));
    }
    return output;
}

inline QString regionText(const PDFClowne::Editing::PdfTextExtractor::PageText &page, int regionIndex)
{
    if (regionIndex < 0 || regionIndex >= page.regions.size())
        return {};

    const PDFClowne::Editing::PdfEditableRegion &region = page.regions.at(regionIndex);
    QString output;
    const int first = std::max(0, region.glyphRange.first);
    const int end = std::min<int>(static_cast<int>(page.glyphs.size()), first + region.glyphRange.second);
    for (int i = first; i < end; ++i) {
        const char32_t scalar = static_cast<char32_t>(page.glyphs.at(i).unicode);
        if (scalar)
            output.append(QString::fromUcs4(&scalar, 1));
    }
    return output;
}

inline int findRegion(const PDFClowne::Editing::PdfTextExtractor::PageText &page,
                      const QString &needle = QString())
{
    if (!needle.isEmpty()) {
        for (int i = 0; i < page.regions.size(); ++i) {
            if (regionText(page, i).contains(needle, Qt::CaseInsensitive))
                return i;
        }
    }
    return page.regions.isEmpty() ? -1 : 0;
}

inline QPointF regionCenter(const PDFClowne::Editing::PdfTextExtractor::PageText &page, int regionIndex)
{
    const QRectF box = page.regions.at(regionIndex).box;
    return QPointF(box.center().x(), box.center().y());
}

inline bool beginRegionEdit(PDFClowne::Editing::PdfEditSessionController &controller,
                            const PDFClowne::Editing::PdfTextExtractor::PageText &page,
                            int regionIndex)
{
    const QPointF center = regionCenter(page, regionIndex);
    return controller.beginSession(0, center.x(), center.y(), 1200, 1600, 1.0);
}

inline QString outputPath(const QString &name)
{
    return QDir(QCoreApplication::applicationDirPath()).absoluteFilePath(name);
}

inline int saveOneEdit(const QString &sourcePath,
                       const QString &needle,
                       const QString &replacement,
                       const QString &targetName,
                       QString *targetPath,
                       QString *originalText)
{
    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText page =
        extractor.extractPage(sourcePath, QString(), 0);
    if (!page.error.isEmpty())
        return fail(page.error);

    const int regionIndex = findRegion(page, needle);
    if (regionIndex < 0)
        return fail(QStringLiteral("Fixture PDF did not expose editable regions."));

    PDFClowne::Editing::PdfEditSessionController controller;
    if (!controller.loadDocument(sourcePath))
        return fail(QStringLiteral("Could not load fixture into edit controller."));
    if (!beginRegionEdit(controller, page, regionIndex))
        return fail(QStringLiteral("Could not begin edit session for selected region."));

    if (originalText)
        *originalText = controller.activeText();

    controller.updateActiveText(replacement);
    if (!controller.commitActiveText())
        return fail(QStringLiteral("Could not commit active text edit."));
    if (!controller.hasPendingEdits())
        return fail(QStringLiteral("Committed text edit did not mark pending operations."));

    const QString out = outputPath(targetName);
    QFile::remove(out);
    if (!controller.saveDocument(out, false))
        return fail(QStringLiteral("Could not save edited PDF copy."));

    if (targetPath)
        *targetPath = out;
    return 0;
}

inline int assertSavedText(const QString &targetPath,
                           const QString &replacement,
                           const QString &originalText,
                           bool requireOriginalRemoved = true)
{
    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText saved =
        extractor.extractPage(targetPath, QString(), 0);
    if (!saved.error.isEmpty())
        return fail(saved.error);

    const QString text = pagePlainText(saved);
    if (!text.contains(replacement))
        return fail(QStringLiteral("Saved PDF text does not contain replacement: %1").arg(replacement));

    if (requireOriginalRemoved && !originalText.isEmpty() && text.contains(originalText))
        return fail(QStringLiteral("Saved PDF text still contains original text: %1").arg(originalText));

    return 0;
}

} // namespace PdfTextEditSaveTestUtils
