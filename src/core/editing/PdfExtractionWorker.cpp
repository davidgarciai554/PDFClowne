#include "PdfExtractionWorker.h"

#include "PdfPageObjectExtractor.h"
#include "TextBlockBuilder.h"

#include <spdlog/spdlog.h>

namespace PDFClowne::Editing {

PdfExtractionWorker::PdfExtractionWorker(FPDF_DOCUMENT doc, int pageNumber, QObject* parent)
    : QObject(parent)
    , m_doc(doc)
    , m_pageNumber(pageNumber)
{
}

void PdfExtractionWorker::run()
{
    if (!m_doc || m_pageNumber < 0) {
        emit failed(tr("No hay un documento PDF cargado para extraer texto."));
        return;
    }

    spdlog::info("PdfExtractionWorker: extracting page {}", m_pageNumber);
    emit progressChanged(10, tr("Preparando extracción de texto"));

    PdfPageObjectExtractor extractor(m_doc);
    const QList<PdfTextRun> runs = extractor.extractTextRunsFromPage(m_pageNumber);

    emit progressChanged(60, tr("Agrupando bloques de texto"));

    TextBlockBuilder builder;
    const QList<PdfTextBlock> blocks = builder.buildBlocks(runs, m_pageNumber);
    const bool scannedCandidate = runs.isEmpty() && blocks.isEmpty();

    if (scannedCandidate) {
        spdlog::warn("PdfExtractionWorker: page {} has no editable text runs; OCR may be required",
                     m_pageNumber);
    }

    emit progressChanged(100, tr("Extracción completada"));
    emit finished(m_pageNumber, blocks, scannedCandidate);
}

} // namespace PDFClowne::Editing
