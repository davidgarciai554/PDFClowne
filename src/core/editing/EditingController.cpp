#include "EditingController.h"

#include "PdfPageObjectExtractor.h"
#include "PdfiumInitializer.h"

#include <QFont>
#include <QFontMetricsF>
#include <QRectF>
#include <Qt>

#include <spdlog/spdlog.h>

#include <fpdf_edit.h>

namespace PDFClowne::Editing {

EditingController::EditingController(QObject* parent)
    : QObject(parent)
    , m_model(this)
{
}

EditingController::~EditingController()
{
    closeDocument();
}

bool EditingController::isReady() const
{
    return m_ready;
}

QString EditingController::selectedBlockId() const
{
    return m_selectedBlockId;
}

void EditingController::setSelectedBlockId(const QString& id)
{
    if (m_selectedBlockId == id) return;
    m_selectedBlockId = id;
    emit selectedBlockIdChanged();
}

TextBlockModel* EditingController::currentPageBlocks()
{
    return &m_model;
}

bool EditingController::loadDocument(const QString& filePath)
{
    return loadDocumentWithPassword(filePath, {});
}

bool EditingController::loadDocumentWithPassword(const QString& filePath, const QString& password)
{
    closeDocument();
    m_loadedFilePath = filePath;

    const QByteArray path = filePath.toUtf8();
    const QByteArray pwd = password.toUtf8();

    FPDF_DOCUMENT doc = nullptr;
    {
        PDFIUM_LOCK();
        doc = FPDF_LoadDocument(path.constData(), password.isEmpty() ? nullptr : pwd.constData());
    }

    if (!doc) {
        spdlog::error("EditingController: failed to open '{}'", path.toStdString());
        emit extractionError(QStringLiteral("No se pudo abrir el documento PDF"));
        return false;
    }

    m_doc = doc;
    setReady(true);
    return true;
}

void EditingController::extractBlocksForPage(int pageNumber)
{
    if (!m_doc) {
        spdlog::warn("EditingController::extractBlocksForPage called without loaded document");
        return;
    }

    PdfPageObjectExtractor extractor(m_doc);
    const QList<PdfTextRun> runs = extractor.extractTextRunsFromPage(pageNumber);
    const QList<PdfTextBlock> blocks = m_builder.buildBlocks(runs, pageNumber);
    m_model.setBlocks(blocks);

    spdlog::debug("EditingController: {} blocks extracted from page {}", blocks.size(), pageNumber);
    emit pageBlocksChanged();
}

void EditingController::selectBlock(const QString& blockId)
{
    setSelectedBlockId(blockId);
}

void EditingController::closeDocument()
{
    if (!m_doc) return;

    m_model.clear();
    m_selectedBlockId.clear();
    m_editedTexts.clear();
    m_editedPages.clear();
    m_loadedFilePath.clear();

    {
        PDFIUM_LOCK();
        FPDF_CloseDocument(m_doc);
    }
    m_doc = nullptr;
    setReady(false);
}

void EditingController::setReady(bool ready)
{
    if (m_ready == ready) return;
    m_ready = ready;
    emit readyChanged();
}

const PdfTextBlock* EditingController::findBlock(const QString& blockId) const
{
    for (const PdfTextBlock& b : m_model.blocks())
        if (b.blockId == blockId) return &b;
    return nullptr;
}

qreal EditingController::reflowText(const QString& blockId, const QString& newText)
{
    const PdfTextBlock* block = findBlock(blockId);
    if (!block || block->bboxPdf.width() <= 0.0)
        return 0.0;

    QFont font(block->dominantFontName);
    font.setPointSizeF(block->dominantFontSize > 0.0 ? block->dominantFontSize : 12.0);
    QFontMetricsF fm(font);

    // Scale factor: font point size → fm pixel units
    const qreal ascent = fm.ascent();
    const qreal pixToPoint = (ascent > 0.0) ? block->dominantFontSize / ascent : 1.0;
    const qreal widthPx = block->bboxPdf.width() / pixToPoint;

    const QRectF wrapped = fm.boundingRect(
        QRectF(0, 0, widthPx, 1e6),
        Qt::TextWordWrap | Qt::AlignLeft,
        newText.isEmpty() ? QStringLiteral(" ") : newText);

    return wrapped.height() * pixToPoint;
}

void EditingController::updateBlockText(const QString& blockId, const QString& newText)
{
    m_editedTexts[blockId] = newText;
    const PdfTextBlock* block = findBlock(blockId);
    if (block)
        m_editedPages[blockId] = block->pageNumber;
}

QString EditingController::blockText(const QString& blockId) const
{
    if (m_editedTexts.contains(blockId))
        return m_editedTexts.value(blockId);
    const PdfTextBlock* block = findBlock(blockId);
    if (!block) return {};
    QStringList parts;
    for (const PdfTextLine& line : block->lines)
        for (const PdfTextRun& run : line.runs)
            parts.append(run.text);
    return parts.join(QLatin1Char(' '));
}

QString EditingController::resolveFont(const QString& blockId,
                                       const QString& newText,
                                       bool&          fallbackUsed) const
{
    const PdfTextBlock* block = findBlock(blockId);
    const QString preferred = block ? block->dominantFontName : QStringLiteral("Helvetica");
    const double  size      = block ? block->dominantFontSize  : 12.0;

    const FontFallbackResult r = m_fontFallback.selectFontForText(preferred, size, newText);
    fallbackUsed = r.usedFallback;
    return r.resolvedFontName;
}

QString EditingController::fallbackFontFor(const QString& blockId,
                                            const QString& newText) const
{
    bool used = false;
    const QString resolved = resolveFont(blockId, newText, used);
    return used ? resolved : QString{};
}

bool EditingController::saveDocument(const QString& outputPath, bool incremental)
{
    if (!m_doc) {
        emit saveError(QStringLiteral("No document loaded"));
        return false;
    }

    // Re-extract blocks for each dirty page so we have fresh pageObjectIndex data
    const QSet<int> dirtyPages(m_editedPages.cbegin(), m_editedPages.cend());
    for (int page : dirtyPages)
        extractBlocksForPage(page);

    // Write back each edited block
    const PdfWriteBackEngine::SaveMode mode = incremental
        ? PdfWriteBackEngine::SaveMode::Incremental
        : PdfWriteBackEngine::SaveMode::FullRewrite;

    for (auto it = m_editedTexts.cbegin(); it != m_editedTexts.cend(); ++it) {
        const QString& blockId = it.key();
        const QString& newText = it.value();
        const PdfTextBlock* block = findBlock(blockId);
        if (!block) {
            spdlog::warn("EditingController::saveDocument: block '{}' not found,"
                         " skipping", blockId.toStdString());
            continue;
        }

        bool fallbackUsed = false;
        const QString resolvedFont = resolveFont(blockId, newText, fallbackUsed);
        const FontFallbackResult fontResult{
            resolvedFont,
            block->dominantFontSize,
            fallbackUsed,
            {}
        };

        if (!m_writeBack.writeBackBlock(m_doc, block->pageNumber, *block, newText, fontResult)) {
            const QString msg = QStringLiteral("Failed to write back block '%1'").arg(blockId);
            spdlog::error("EditingController::saveDocument: {}", msg.toStdString());
            emit saveError(msg);
            return false;
        }
    }

    // Determine output path (default: overwrite original if none given)
    const QString target = outputPath.isEmpty() ? m_loadedFilePath : outputPath;
    if (!m_writeBack.saveTo(m_doc, target, mode)) {
        const QString msg = QStringLiteral("Failed to save to '%1'").arg(target);
        emit saveError(msg);
        return false;
    }

    spdlog::info("EditingController::saveDocument: saved {} block(s) to '{}'",
                 m_editedTexts.size(), target.toStdString());
    m_editedTexts.clear();
    m_editedPages.clear();
    emit saveCompleted(target);
    return true;
}

} // namespace PDFClowne::Editing
