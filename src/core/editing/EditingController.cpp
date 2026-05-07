#include "EditingController.h"

#include "PdfPageObjectExtractor.h"
#include "PdfiumInitializer.h"

#include <QFont>
#include <QFontMetricsF>
#include <QRectF>
#include <Qt>

#include <spdlog/spdlog.h>

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

} // namespace PDFClowne::Editing
