#pragma once

#include "../../src/backend/text/PdfEditSessionController.h"
#include "../../src/backend/text/PdfTextExtractor.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointF>
#include <QString>

#include <algorithm>
#include <cmath>
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
        return -1;
    }
    return page.regions.isEmpty() ? -1 : 0;
}

inline int findRegionNearBox(const PDFClowne::Editing::PdfTextExtractor::PageText &page,
                             const QString &needle,
                             const QRectF &box)
{
    const QRectF expandedBox = box.adjusted(-8.0, -8.0, 8.0, 8.0);
    for (int i = 0; i < page.regions.size(); ++i) {
        if (!regionText(page, i).contains(needle, Qt::CaseInsensitive))
            continue;
        if (expandedBox.intersects(page.regions.at(i).box) || expandedBox.contains(page.regions.at(i).box.center()))
            return i;
    }
    return -1;
}

inline QPointF regionCenter(const PDFClowne::Editing::PdfTextExtractor::PageText &page, int regionIndex)
{
    const QRectF box = page.regions.at(regionIndex).box;
    return QPointF(box.center().x(), box.center().y());
}

inline PDFClowne::Editing::PdfGlyph firstGlyphForRegion(
    const PDFClowne::Editing::PdfTextExtractor::PageText &page,
    int regionIndex)
{
    const PDFClowne::Editing::PdfEditableRegion &region = page.regions.at(regionIndex);
    const int first = std::max(0, region.glyphRange.first);
    if (first >= 0 && first < page.glyphs.size())
        return page.glyphs.at(first);
    return {};
}

inline PDFClowne::Editing::PdfGlyph firstGlyphForNeedleInRegion(
    const PDFClowne::Editing::PdfTextExtractor::PageText &page,
    int regionIndex,
    const QString &needle)
{
    if (regionIndex < 0 || regionIndex >= page.regions.size())
        return {};

    const PDFClowne::Editing::PdfEditableRegion &region = page.regions.at(regionIndex);
    const QString text = regionText(page, regionIndex);
    const int textOffset = needle.isEmpty() ? 0 : text.indexOf(needle, 0, Qt::CaseInsensitive);
    const int glyphOffset = textOffset < 0 ? 0 : textOffset;
    const int first = std::max(0, region.glyphRange.first) + glyphOffset;
    if (first >= 0 && first < page.glyphs.size())
        return page.glyphs.at(first);
    return firstGlyphForRegion(page, regionIndex);
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
    const QFileInfo info(name);
    const QString uniqueName = QStringLiteral("%1.%2.%3")
        .arg(info.completeBaseName())
        .arg(QCoreApplication::applicationPid())
        .arg(info.suffix().isEmpty() ? QStringLiteral("pdf") : info.suffix());
    return QDir(QCoreApplication::applicationDirPath()).absoluteFilePath(uniqueName);
}

inline int saveOneEdit(const QString &sourcePath,
                       const QString &needle,
                       const QString &replacement,
                       const QString &targetName,
                       QString *targetPath,
                       QString *originalText,
                       bool overwriteSource = false)
{
    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText page =
        extractor.extractPage(sourcePath, QString(), 0);
    if (!page.error.isEmpty())
        return fail(page.error);

    const int regionIndex = findRegion(page, needle);
    if (regionIndex < 0)
        return fail(needle.isEmpty()
                        ? QStringLiteral("Fixture PDF did not expose editable regions.")
                        : QStringLiteral("Fixture PDF did not contain requested editable text: %1").arg(needle));

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

    const QString out = overwriteSource ? sourcePath : outputPath(targetName);
    if (!overwriteSource)
        QFile::remove(out);
    QString saveError;
    QObject::connect(&controller,
                     &PDFClowne::Editing::PdfEditSessionController::saveError,
                     [&](const QString &message) {
                         saveError = message;
                     });
    if (!controller.saveDocument(out, overwriteSource)) {
        const QString detail = saveError.isEmpty() ? controller.statusMessage() : saveError;
        return fail(detail.isEmpty()
                        ? QStringLiteral("Could not save edited PDF copy for %1 -> %2.")
                              .arg(needle, replacement)
                        : QStringLiteral("Could not save edited PDF copy for %1 -> %2: %3")
                              .arg(needle, replacement, detail));
    }

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

inline int assertSavedReplacementGeometry(const QString &sourcePath,
                                          const QString &targetPath,
                                          const QString &originalNeedle,
                                          const QString &replacement,
                                          qreal baselineTolerance = 2.0)
{
    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText original =
        extractor.extractPage(sourcePath, QString(), 0);
    if (!original.error.isEmpty())
        return fail(original.error);
    const PDFClowne::Editing::PdfTextExtractor::PageText saved =
        extractor.extractPage(targetPath, QString(), 0);
    if (!saved.error.isEmpty())
        return fail(saved.error);

    const int originalRegion = findRegion(original, originalNeedle);
    if (originalRegion < 0)
        return fail(QStringLiteral("Could not find original geometry region: %1").arg(originalNeedle));
    const int savedRegion = findRegionNearBox(saved,
                                              replacement,
                                              original.regions.at(originalRegion).box);
    if (savedRegion < 0)
        return fail(QStringLiteral("Could not find saved replacement geometry region near original: %1").arg(replacement));

    const PDFClowne::Editing::PdfGlyph originalGlyph = firstGlyphForRegion(original, originalRegion);
    const PDFClowne::Editing::PdfGlyph savedGlyph = firstGlyphForRegion(saved, savedRegion);
    if (std::abs(originalGlyph.origin.x() - savedGlyph.origin.x()) > baselineTolerance)
        return fail(QStringLiteral("Saved replacement X moved too far. original=%1 saved=%2")
                        .arg(originalGlyph.origin.x())
                        .arg(savedGlyph.origin.x()));
    if (std::abs(originalGlyph.origin.y() - savedGlyph.origin.y()) > baselineTolerance)
        return fail(QStringLiteral("Saved replacement baseline moved too far. original=%1 saved=%2")
                        .arg(originalGlyph.origin.y())
                        .arg(savedGlyph.origin.y()));

    const qreal minSize = std::max<qreal>(1.0, originalGlyph.fontSize * 0.70);
    const qreal maxSize = std::max<qreal>(minSize + 0.01, originalGlyph.fontSize * 1.30);
    if (savedGlyph.fontSize < minSize || savedGlyph.fontSize > maxSize) {
        return fail(QStringLiteral("Saved replacement font size drifted. original=%1 saved=%2")
                        .arg(originalGlyph.fontSize)
                        .arg(savedGlyph.fontSize));
    }

    return 0;
}

inline int assertOriginalTailRemovedInEditedRegion(const QString &sourcePath,
                                                   const QString &targetPath,
                                                   const QString &originalNeedle,
                                                   const QString &staleNeedle)
{
    PDFClowne::Editing::PdfTextExtractor extractor;
    const PDFClowne::Editing::PdfTextExtractor::PageText original =
        extractor.extractPage(sourcePath, QString(), 0);
    if (!original.error.isEmpty())
        return fail(original.error);
    const PDFClowne::Editing::PdfTextExtractor::PageText saved =
        extractor.extractPage(targetPath, QString(), 0);
    if (!saved.error.isEmpty())
        return fail(saved.error);

    const int originalRegion = findRegion(original, originalNeedle);
    if (originalRegion < 0)
        return fail(QStringLiteral("Could not find original stale-text region: %1").arg(originalNeedle));

    const QRectF editedBox = original.regions.at(originalRegion).box.adjusted(-2.0, -4.0, 2.0, 4.0);
    QString savedTextInEditedBox;
    for (const PDFClowne::Editing::PdfGlyph &glyph : saved.glyphs) {
        if (!editedBox.intersects(glyph.bbox) && !editedBox.contains(glyph.origin))
            continue;

        const char32_t scalar = static_cast<char32_t>(glyph.unicode);
        if (scalar)
            savedTextInEditedBox.append(QString::fromUcs4(&scalar, 1));
    }

    if (savedTextInEditedBox.contains(staleNeedle, Qt::CaseInsensitive)) {
        return fail(QStringLiteral("Edited region still contains stale text '%1': %2")
                        .arg(staleNeedle, savedTextInEditedBox));
    }

    return 0;
}

} // namespace PdfTextEditSaveTestUtils
