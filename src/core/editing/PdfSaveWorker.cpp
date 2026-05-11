#include "PdfSaveWorker.h"

#include "PdfPageObjectExtractor.h"
#include "TextBlockBuilder.h"

#include <QSet>

#include <spdlog/spdlog.h>

namespace PDFClowne::Editing {

PdfSaveWorker::PdfSaveWorker(FPDF_DOCUMENT doc,
                             QString outputPath,
                             PdfWriteBackEngine::SaveMode mode,
                             QHash<QString, QString> editedTexts,
                             QHash<QString, int> editedPages,
                             QHash<int, QList<PdfTextBlock>> pageBlockCache,
                             QObject* parent)
    : QObject(parent)
    , m_doc(doc)
    , m_outputPath(std::move(outputPath))
    , m_mode(mode)
    , m_editedTexts(std::move(editedTexts))
    , m_editedPages(std::move(editedPages))
    , m_pageBlockCache(std::move(pageBlockCache))
{
}

void PdfSaveWorker::run()
{
    if (!m_doc) {
        emit failed(tr("No hay un documento PDF cargado para guardar."));
        return;
    }

    spdlog::info("PdfSaveWorker: saving {} edited block(s) to '{}'",
                 m_editedTexts.size(), m_outputPath.toStdString());
    emit progressChanged(5, tr("Preparando guardado seguro"));

    const QSet<int> dirtyPages(m_editedPages.cbegin(), m_editedPages.cend());
    TextBlockBuilder builder;
    PdfPageObjectExtractor extractor(m_doc);
    int completedPages = 0;
    for (int page : dirtyPages) {
        const QList<PdfTextRun> runs = extractor.extractTextRunsFromPage(page);
        m_pageBlockCache.insert(page, builder.buildBlocks(runs, page));
        ++completedPages;
        const int progress = 10 + (dirtyPages.isEmpty() ? 0 : (completedPages * 30 / dirtyPages.size()));
        emit progressChanged(progress, tr("Actualizando índices de página"));
    }

    int completedBlocks = 0;
    for (auto it = m_editedTexts.cbegin(); it != m_editedTexts.cend(); ++it) {
        const QString& blockId = it.key();
        const QString& newText = it.value();
        const PdfTextBlock* block = findBlock(blockId);
        if (!block) {
            spdlog::warn("PdfSaveWorker: block '{}' not found, skipping", blockId.toStdString());
            continue;
        }
        if (!block->isEditable) {
            spdlog::warn("PdfSaveWorker: block '{}' is not editable, skipping", blockId.toStdString());
            continue;
        }

        const FontFallbackResult fontResult = m_fontFallback.selectFontForText(
            block->dominantFontName,
            block->dominantFontSize,
            newText);

        if (!m_writeBack.writeBackBlock(m_doc, block->pageNumber, *block, newText, fontResult)) {
            const QString msg = tr("No se pudo escribir el bloque '%1'.").arg(blockId);
            spdlog::error("PdfSaveWorker: {}", msg.toStdString());
            emit failed(msg);
            return;
        }

        ++completedBlocks;
        const int progress = 45 + (m_editedTexts.isEmpty() ? 0 : (completedBlocks * 35 / m_editedTexts.size()));
        emit progressChanged(progress, tr("Escribiendo cambios en el PDF"));
    }

    emit progressChanged(85, tr("Validando PDF temporal"));
    if (!m_writeBack.saveTo(m_doc, m_outputPath, m_mode)) {
        const QString msg = tr("No se pudo guardar en '%1'.").arg(m_outputPath);
        spdlog::error("PdfSaveWorker: {}", msg.toStdString());
        emit failed(msg);
        return;
    }

    emit progressChanged(100, tr("Guardado completado"));
    emit finished(m_outputPath);
}

const PdfTextBlock* PdfSaveWorker::findBlock(const QString& blockId) const
{
    for (auto pageIt = m_pageBlockCache.cbegin(); pageIt != m_pageBlockCache.cend(); ++pageIt) {
        for (const PdfTextBlock& block : pageIt.value()) {
            if (block.blockId == blockId)
                return &block;
        }
    }
    return nullptr;
}

} // namespace PDFClowne::Editing
