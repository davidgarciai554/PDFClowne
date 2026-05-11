#include "EditingController.h"

#include "PdfiumInitializer.h"

#include <QFileInfo>
#include <QElapsedTimer>
#include <QFont>
#include <QFontMetricsF>
#include <QMetaType>
#include <QRectF>
#include <Qt>

#include <spdlog/spdlog.h>

#include <fpdf_edit.h>

namespace PDFClowne::Editing {

EditingController::EditingController(QObject* parent)
    : QObject(parent)
    , m_model(this)
{
    qRegisterMetaType<QList<PdfTextBlock>>("QList<PDFClowne::Editing::PdfTextBlock>");
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

bool EditingController::isBusy() const
{
    return m_extractionThread || m_saveThread;
}

bool EditingController::isExtracting() const
{
    return m_extractionThread != nullptr;
}

bool EditingController::isSaving() const
{
    return m_saveThread != nullptr;
}

bool EditingController::hasPendingEdits() const
{
    return !m_editedTexts.isEmpty();
}

int EditingController::progress() const
{
    return m_progress;
}

QString EditingController::statusMessage() const
{
    return m_statusMessage;
}

bool EditingController::scannedDocumentSuspected() const
{
    return m_scannedDocumentSuspected;
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
    setScannedDocumentSuspected(false);
    setProgress(0, tr("Documento listo para edición"));
    setReady(true);
    return true;
}

void EditingController::extractBlocksForPage(int pageNumber)
{
    if (!m_doc) {
        spdlog::warn("EditingController::extractBlocksForPage called without loaded document");
        return;
    }

    if (m_extractionThread) {
        spdlog::warn("EditingController::extractBlocksForPage ignored while extraction is already running");
        emit editWarning(tr("Ya hay una extracción de texto en curso."));
        return;
    }

    if (m_pageBlockCache.contains(pageNumber)) {
        const QList<PdfTextBlock> blocks = m_pageBlockCache.value(pageNumber);
        m_model.setBlocks(blocks);
        setScannedDocumentSuspected(m_scannedPageCache.value(pageNumber, false));
        setProgress(100, tr("Bloques de texto cargados desde caché"));
        spdlog::info("EditingController: cache hit for page {} ({} blocks)", pageNumber, blocks.size());
        emit pageBlocksChanged();
        return;
    }

    auto* elapsed = new QElapsedTimer;
    elapsed->start();
    auto* worker = new PdfExtractionWorker(m_doc, pageNumber);
    auto* thread = new QThread(this);
    m_extractionThread = thread;
    worker->moveToThread(thread);
    setProgress(0, tr("Iniciando extracción de texto"));
    emit busyChanged();

    connect(thread, &QThread::started, worker, &PdfExtractionWorker::run);
    connect(worker, &PdfExtractionWorker::progressChanged, this,
            [this](int progress, const QString& message) {
                setProgress(progress, message);
            });
    connect(worker, &PdfExtractionWorker::finished, this,
            [this, elapsed](int pageNumber, const QList<PdfTextBlock>& blocks, bool scannedCandidate) {
                m_pageBlockCache.insert(pageNumber, blocks);
                m_scannedPageCache.insert(pageNumber, scannedCandidate);
                m_model.setBlocks(blocks);
                setScannedDocumentSuspected(scannedCandidate);
                if (scannedCandidate) {
                    const QString msg = tr("No se ha encontrado texto editable en esta página. Puede requerir OCR.");
                    emit ocrSuggested(msg);
                    setProgress(100, msg);
                }
                spdlog::info("EditingController: {} blocks extracted from page {}",
                             blocks.size(), pageNumber);
                spdlog::info("EditingController: edit extraction page {} completed in {} ms",
                             pageNumber, elapsed ? elapsed->elapsed() : -1);
                delete elapsed;
                emit pageBlocksChanged();
                if (m_extractionThread)
                    m_extractionThread->quit();
            });
    connect(worker, &PdfExtractionWorker::failed, this,
            [this, elapsed](const QString& message) {
                spdlog::error("EditingController extraction failed: {}", message.toStdString());
                spdlog::warn("EditingController: edit extraction failed after {} ms",
                             elapsed ? elapsed->elapsed() : -1);
                delete elapsed;
                emit extractionError(message);
                setProgress(0, message);
                if (m_extractionThread)
                    m_extractionThread->quit();
            });
    connect(thread, &QThread::finished, worker, &QObject::deleteLater);
    connect(thread, &QThread::finished, this, &EditingController::clearExtractionThread);

    thread->start();
}

void EditingController::selectBlock(const QString& blockId)
{
    setSelectedBlockId(blockId);
}

void EditingController::closeDocument()
{
    clearExtractionThread();
    clearSaveThread();

    if (!m_doc) return;

    m_model.clear();
    m_selectedBlockId.clear();
    m_editedTexts.clear();
    m_editedPages.clear();
    m_pageBlockCache.clear();
    m_scannedPageCache.clear();
    m_loadedFilePath.clear();
    setScannedDocumentSuspected(false);
    setProgress(0, {});

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
    for (auto pageIt = m_pageBlockCache.cbegin(); pageIt != m_pageBlockCache.cend(); ++pageIt) {
        for (const PdfTextBlock& b : pageIt.value()) {
            if (b.blockId == blockId)
                return &b;
        }
    }
    return nullptr;
}

void EditingController::setProgress(int progress, const QString& message)
{
    const int bounded = qBound(0, progress, 100);
    const bool progressChangedValue = m_progress != bounded;
    const bool messageChangedValue = m_statusMessage != message;
    m_progress = bounded;
    m_statusMessage = message;
    if (progressChangedValue)
        emit progressChanged();
    if (messageChangedValue)
        emit statusMessageChanged();
}

void EditingController::setScannedDocumentSuspected(bool suspected)
{
    if (m_scannedDocumentSuspected == suspected)
        return;
    m_scannedDocumentSuspected = suspected;
    emit scannedDocumentSuspectedChanged();
}

void EditingController::clearExtractionThread()
{
    if (!m_extractionThread)
        return;
    QThread* thread = m_extractionThread;
    m_extractionThread = nullptr;
    if (thread->isRunning()) {
        thread->quit();
        thread->wait();
    }
    thread->deleteLater();
    emit busyChanged();
}

void EditingController::clearSaveThread()
{
    if (!m_saveThread)
        return;
    QThread* thread = m_saveThread;
    m_saveThread = nullptr;
    if (thread->isRunning()) {
        thread->quit();
        thread->wait();
    }
    thread->deleteLater();
    emit busyChanged();
}

qreal EditingController::reflowText(const QString& blockId, const QString& newText)
{
    const PdfTextBlock* block = findBlock(blockId);
    if (!block || block->bboxPdf.width() <= 0.0)
        return 0.0;
    if (block && !block->isEditable) {
        emit editWarning(block->nonEditableReason.isEmpty()
                             ? tr("Este bloque no es editable.")
                             : block->nonEditableReason);
        return 0.0;
    }

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
    const PdfTextBlock* block = findBlock(blockId);
    if (block && !block->isEditable) {
        emit editWarning(block->nonEditableReason.isEmpty()
                             ? tr("Este bloque no es editable.")
                             : block->nonEditableReason);
        return;
    }

    const bool wasDirty = hasPendingEdits();
    const QString original = blockText(blockId);
    if (newText == original) {
        m_editedTexts.remove(blockId);
        m_editedPages.remove(blockId);
        if (wasDirty != hasPendingEdits())
            emit pendingEditsChanged();
        return;
    }

    m_editedTexts[blockId] = newText;
    if (block)
        m_editedPages[blockId] = block->pageNumber;
    if (!wasDirty)
        emit pendingEditsChanged();
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
    if (outputPath.trimmed().isEmpty()) {
        emit saveError(QStringLiteral("Output path is required for safe PDF editing saves"));
        return false;
    }
    if (m_saveThread || m_extractionThread) {
        emit saveError(tr("Hay una operación de edición en curso."));
        return false;
    }
    if (m_editedTexts.isEmpty()) {
        emit saveError(tr("No hay cambios de texto pendientes para guardar."));
        return false;
    }

    const QString target = outputPath.trimmed();
    if (QFileInfo(target).canonicalFilePath() == QFileInfo(m_loadedFilePath).canonicalFilePath()) {
        emit saveError(QStringLiteral("Refusing to overwrite the loaded PDF without explicit safe replacement"));
        return false;
    }

    const PdfWriteBackEngine::SaveMode mode = incremental
        ? PdfWriteBackEngine::SaveMode::Incremental
        : PdfWriteBackEngine::SaveMode::FullRewrite;

    auto* worker = new PdfSaveWorker(m_doc, target, mode, m_editedTexts, m_editedPages, m_pageBlockCache);
    auto* thread = new QThread(this);
    m_saveThread = thread;
    worker->moveToThread(thread);
    setProgress(0, tr("Iniciando guardado"));
    emit busyChanged();

    connect(thread, &QThread::started, worker, &PdfSaveWorker::run);
    connect(worker, &PdfSaveWorker::progressChanged, this,
            [this](int progress, const QString& message) {
                setProgress(progress, message);
            });
    connect(worker, &PdfSaveWorker::finished, this,
            [this](const QString& savedPath) {
                spdlog::info("EditingController::saveDocument: saved {} block(s) to '{}'",
                             m_editedTexts.size(), savedPath.toStdString());
                clearPendingEdits();
                emit saveCompleted(savedPath);
                if (m_saveThread)
                    m_saveThread->quit();
            });
    connect(worker, &PdfSaveWorker::failed, this,
            [this](const QString& message) {
                emit saveError(message);
                setProgress(0, message);
                if (m_saveThread)
                    m_saveThread->quit();
            });
    connect(thread, &QThread::finished, worker, &QObject::deleteLater);
    connect(thread, &QThread::finished, this, &EditingController::clearSaveThread);

    thread->start();
    return true;
}

void EditingController::clearPendingEdits()
{
    const bool wasDirty = hasPendingEdits();
    m_editedTexts.clear();
    m_editedPages.clear();
    if (wasDirty)
        emit pendingEditsChanged();
}

} // namespace PDFClowne::Editing
