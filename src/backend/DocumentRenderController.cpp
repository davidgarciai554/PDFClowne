#include "DocumentRenderController.h"
#include "PdfRenderImageProvider.h"

#include <QDateTime>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QHash>
#include <QImage>
#include <QList>
#include <QMetaObject>
#include <QSharedPointer>
#include <QThread>
#include <QUrl>

#include <mupdf/fitz.h>

#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <psapi.h>
#endif

#include <algorithm>
#include <cstddef>
#include <utility>

namespace {
constexpr float kThumbnailScale = 0.30f;
constexpr std::size_t kMuPdfStoreLimitBytes = FZ_STORE_DEFAULT;
constexpr int kMaxDisplayListCachePages = 18;

QString toLocalPath(const QString &source)
{
    if (source.startsWith(QLatin1String("file://"), Qt::CaseInsensitive))
        return QUrl(source).toLocalFile();
    return source;
}

QString displayNameForPath(const QString &path)
{
    const QFileInfo info(path);
    return info.fileName().isEmpty() ? path : info.fileName();
}

QImage pixmapToImage(fz_pixmap *pix)
{
    if (!pix || pix->w <= 0 || pix->h <= 0)
        return {};

    QImage::Format format = QImage::Format_Invalid;
    if (pix->n == 3)
        format = QImage::Format_RGB888;
    else if (pix->n == 4)
        format = QImage::Format_RGBA8888;
    else
        return {};

    const QImage image(pix->samples, pix->w, pix->h, pix->stride, format);
    return image.copy();
}

QImage renderPageToImage(fz_context *ctx, fz_document *doc, int pageIndex, float scale)
{
    if (!ctx || !doc || pageIndex < 0)
        return {};

    fz_pixmap *pix = nullptr;
    QImage image;

    fz_try(ctx)
    {
        const fz_matrix matrix = fz_scale(scale, scale);
        pix = fz_new_pixmap_from_page_number(ctx, doc, pageIndex, matrix, fz_device_rgb(ctx), 0);
        image = pixmapToImage(pix);
    }
    fz_always(ctx)
    {
        if (pix)
            fz_drop_pixmap(ctx, pix);
    }
    fz_catch(ctx)
    {
        image = QImage();
    }

    return image;
}

qint64 currentProcessMemoryBytes()
{
#ifdef Q_OS_WIN
    PROCESS_MEMORY_COUNTERS_EX counters = {};
    if (GetProcessMemoryInfo(GetCurrentProcess(),
                             reinterpret_cast<PROCESS_MEMORY_COUNTERS *>(&counters),
                             sizeof(counters))) {
        return static_cast<qint64>(counters.WorkingSetSize);
    }
#endif
    return 0;
}
}

class DocumentRenderWorker : public QObject
{
    Q_OBJECT

public:
    explicit DocumentRenderWorker(PdfRenderImageProvider *imageProvider)
        : m_imageProvider(imageProvider)
    {
    }

    enum class RenderKind {
        Page,
        Thumbnail
    };

    struct RenderRequest {
        QString filePath;
        int pageIndex = -1;
        qreal scale = 1.0;
        int sessionId = 0;
        RenderKind kind = RenderKind::Page;
        qint64 enqueuedAtMs = 0;
    };

    struct CacheEntry {
        QString source;
        qint64 bytes = 0;
    };

    struct DisplayListEntry {
        fz_display_list *list = nullptr;
        qint64 lastUsedMs = 0;
    };

    class RenderEngine {
    public:
        ~RenderEngine()
        {
            close();
        }

        bool open(const QString &filePath)
        {
            close();

            m_ctx = fz_new_context(nullptr, nullptr, kMuPdfStoreLimitBytes);
            if (!m_ctx)
                return false;

            const QByteArray pathBytes = filePath.toUtf8();
            bool ok = true;
            fz_try(m_ctx)
            {
                fz_register_document_handlers(m_ctx);
                m_doc = fz_open_document(m_ctx, pathBytes.constData());
                if (fz_needs_password(m_ctx, m_doc))
                    fz_throw(m_ctx, FZ_ERROR_GENERIC, "password-protected PDFs are not enabled in this build");
            }
            fz_catch(m_ctx)
            {
                ok = false;
            }

            if (!ok)
                close();
            return ok;
        }

        void close()
        {
            if (m_doc) {
                fz_drop_document(m_ctx, m_doc);
                m_doc = nullptr;
            }

            if (m_ctx) {
                fz_drop_context(m_ctx);
                m_ctx = nullptr;
            }
        }

        fz_context *context() const { return m_ctx; }
        fz_document *document() const { return m_doc; }

    private:
        fz_context *m_ctx = nullptr;
        fz_document *m_doc = nullptr;
    };

    struct DocumentState {
        ~DocumentState()
        {
            clearDisplayListCache();
        }

        void clearDisplayListCache()
        {
            fz_context *ctx = engine.context();
            if (ctx) {
                for (auto it = displayLists.begin(); it != displayLists.end(); ++it) {
                    if (it.value().list)
                        fz_drop_display_list(ctx, it.value().list);
                }
            }

            displayLists.clear();
            displayListOrder.clear();
        }

        RenderEngine engine;
        QElapsedTimer openTimer;
        QHash<int, DisplayListEntry> displayLists;
        QList<int> displayListOrder;
        bool firstPageReported = false;
        int activeSessionId = 0;
    };

public slots:
    void markDocumentOpened(const QString &filePath, int sessionId)
    {
        const QString localPath = toLocalPath(filePath);
        DocumentState &state = ensureDocumentState(localPath);
        state.activeSessionId = sessionId;
        state.openTimer.restart();
        state.firstPageReported = false;
        qInfo().noquote() << QStringLiteral("[render-doc] opened file=\"%1\" session=%2")
                                 .arg(displayNameForPath(localPath))
                                 .arg(sessionId);
        emit metricsUpdated(m_cacheBytes, currentProcessMemoryBytes(), m_peakProcessMemoryBytes, pendingCount(), m_rendering);
    }

    void enqueuePageRender(const QString &filePath, int pageIndex, qreal scale, int sessionId)
    {
        enqueueRender({toLocalPath(filePath), pageIndex, scale, sessionId, RenderKind::Page});
    }

    void enqueueThumbnailRender(const QString &filePath, int pageIndex, int sessionId)
    {
        enqueueRender({toLocalPath(filePath), pageIndex, kThumbnailScale, sessionId, RenderKind::Thumbnail});
    }

    void prunePageCache(const QString &filePath, int centerPage, int radius, int sessionId)
    {
        const QString localPath = toLocalPath(filePath);
        auto docIt = m_documents.find(localPath);
        if (docIt == m_documents.end() || docIt.value().isNull())
            return;

        if (sessionId != docIt.value()->activeSessionId)
            return;

        const int minimumPage = std::max(0, centerPage - std::max(0, radius));
        const int maximumPage = centerPage + std::max(0, radius);

        for (int i = m_pendingOrder.size() - 1; i >= 0; --i) {
            const QString key = m_pendingOrder.at(i);
            auto pendingIt = m_pending.find(key);
            if (pendingIt == m_pending.end())
                continue;

            const RenderRequest &request = pendingIt.value();
            if (request.filePath != localPath ||
                request.sessionId != sessionId ||
                request.kind != RenderKind::Page)
                continue;

            if (request.pageIndex >= minimumPage && request.pageIndex <= maximumPage)
                continue;

            m_pendingOrder.removeAt(i);
            m_pending.erase(pendingIt);
        }

        const QString prefix = localPath + QLatin1Char('|') + QStringLiteral("page|");
        for (auto it = m_cache.begin(); it != m_cache.end();) {
            if (!it.key().startsWith(prefix)) {
                ++it;
                continue;
            }

            const QStringList parts = it.key().split(QLatin1Char('|'));
            if (parts.size() < 4) {
                ++it;
                continue;
            }

            bool ok = false;
            const int pageIndex = parts.at(2).toInt(&ok);
            if (!ok || (pageIndex >= minimumPage && pageIndex <= maximumPage)) {
                ++it;
                continue;
            }

            if (m_imageProvider)
                m_imageProvider->removeImageForKey(it.key());
            m_cacheBytes -= it.value().bytes;
            it = m_cache.erase(it);
        }

        pruneDisplayListCache(*docIt.value(), minimumPage, maximumPage);

        const qint64 processBytes = currentProcessMemoryBytes();
        m_peakProcessMemoryBytes = std::max(m_peakProcessMemoryBytes, processBytes);
        emit metricsUpdated(m_cacheBytes, processBytes, m_peakProcessMemoryBytes, pendingCount(), m_rendering);
    }

    void releaseDocument(const QString &filePath, int sessionId)
    {
        const QString localPath = toLocalPath(filePath);

        for (int i = m_pendingOrder.size() - 1; i >= 0; --i) {
            const QString key = m_pendingOrder.at(i);
            if (key.startsWith(localPath + QLatin1Char('|'))) {
                m_pendingOrder.removeAt(i);
                m_pending.remove(key);
            }
        }

        removeCacheForPath(localPath);

        auto it = m_documents.find(localPath);
        if (it != m_documents.end() && !it.value().isNull()) {
            if (sessionId >= it.value()->activeSessionId)
                it.value()->activeSessionId = sessionId + 1;
            it.value()->clearDisplayListCache();
            it.value()->engine.close();
            m_documents.erase(it);
        }

        const qint64 processBytes = currentProcessMemoryBytes();
        m_peakProcessMemoryBytes = std::max(m_peakProcessMemoryBytes, processBytes);
        qInfo().noquote() << QStringLiteral("[render-doc] released file=\"%1\" session=%2 cache_bytes=%3 pending=%4 process_mem_bytes=%5")
                                 .arg(displayNameForPath(localPath))
                                 .arg(sessionId)
                                 .arg(m_cacheBytes)
                                 .arg(pendingCount())
                                 .arg(processBytes);
        emit metricsUpdated(m_cacheBytes, processBytes, m_peakProcessMemoryBytes, pendingCount(), m_rendering);
    }

    void clear()
    {
        m_pending.clear();
        m_pendingOrder.clear();
        if (m_imageProvider)
            m_imageProvider->clear();
        m_cache.clear();
        m_cacheBytes = 0;
        m_documents.clear();
        const qint64 processBytes = currentProcessMemoryBytes();
        m_peakProcessMemoryBytes = std::max(m_peakProcessMemoryBytes, processBytes);
        emit metricsUpdated(m_cacheBytes, processBytes, m_peakProcessMemoryBytes, pendingCount(), m_rendering);
    }

signals:
    void renderCompleted(const QString &filePath,
                         int sessionId,
                         int pageIndex,
                         bool thumbnail,
                         qreal scale,
                         const QString &source,
                         bool canceled,
                         bool fromCache,
                         int firstPageVisibleMs,
                         qint64 cacheBytes,
                         qint64 processMemoryBytes,
                         qint64 peakProcessMemoryBytes,
                         int pendingCount);
    void metricsUpdated(qint64 cacheBytes,
                        qint64 processMemoryBytes,
                        qint64 peakProcessMemoryBytes,
                        int pendingCount,
                        bool busy);

private:
    void enqueueRender(const RenderRequest &request)
    {
        if (request.filePath.isEmpty() || request.pageIndex < 0)
            return;

        RenderRequest preparedRequest = request;
        preparedRequest.enqueuedAtMs = QDateTime::currentMSecsSinceEpoch();

        DocumentState &state = ensureDocumentState(preparedRequest.filePath);
        if (preparedRequest.sessionId > state.activeSessionId) {
            state.activeSessionId = preparedRequest.sessionId;
            state.openTimer.restart();
            state.firstPageReported = false;
        }

        const QString key = cacheKeyFor(preparedRequest);
        if (m_cache.contains(key)) {
            completeFromCache(preparedRequest, m_cache.value(key));
            return;
        }

        if (!m_pending.contains(key)) {
            if (preparedRequest.kind == RenderKind::Page) {
                int insertIndex = 0;
                while (insertIndex < m_pendingOrder.size()) {
                    const auto existingIt = m_pending.constFind(m_pendingOrder.at(insertIndex));
                    if (existingIt == m_pending.constEnd()) {
                        ++insertIndex;
                        continue;
                    }

                    if (existingIt.value().kind == RenderKind::Thumbnail)
                        break;

                    ++insertIndex;
                }
                m_pendingOrder.insert(insertIndex, key);
            } else {
                m_pendingOrder.append(key);
            }
        }
        m_pending.insert(key, preparedRequest);
        trimPendingRequests(preparedRequest);

        const qint64 processBytes = currentProcessMemoryBytes();
        m_peakProcessMemoryBytes = std::max(m_peakProcessMemoryBytes, processBytes);
        emit metricsUpdated(m_cacheBytes, processBytes, m_peakProcessMemoryBytes, pendingCount(), true);

        if (!m_rendering)
            QMetaObject::invokeMethod(this, &DocumentRenderWorker::processNext, Qt::QueuedConnection);
    }

    QString cacheKeyFor(const RenderRequest &request) const
    {
        const int scaleKey = qRound(request.scale * 1000.0);
        return QStringLiteral("%1|%2|%3|%4")
            .arg(request.filePath,
                 request.kind == RenderKind::Thumbnail ? QStringLiteral("thumb") : QStringLiteral("page"))
            .arg(request.pageIndex)
            .arg(scaleKey);
    }

    void completeFromCache(const RenderRequest &request, const CacheEntry &entry)
    {
        DocumentState &state = ensureDocumentState(request.filePath);
        const bool canceled = request.sessionId != state.activeSessionId;
        int firstPageVisibleMs = -1;
        const qint64 totalElapsedMs = request.enqueuedAtMs > 0
            ? std::max<qint64>(0, QDateTime::currentMSecsSinceEpoch() - request.enqueuedAtMs)
            : 0;
        if (!canceled && request.kind == RenderKind::Page && request.pageIndex == 0 && !state.firstPageReported) {
            state.firstPageReported = true;
            firstPageVisibleMs = state.openTimer.isValid() ? static_cast<int>(state.openTimer.elapsed()) : 0;
            qInfo().noquote() << QStringLiteral("[render-first-page] file=\"%1\" session=%2 elapsed_ms=%3 source=cache")
                                     .arg(displayNameForPath(request.filePath))
                                     .arg(request.sessionId)
                                     .arg(firstPageVisibleMs);
        }

        const qint64 processBytes = currentProcessMemoryBytes();
        m_peakProcessMemoryBytes = std::max(m_peakProcessMemoryBytes, processBytes);
        qInfo().noquote() << QStringLiteral("[render] done file=\"%1\" session=%2 kind=%3 page=%4 scale=%5 from_cache=true canceled=%6 total_ms=%7 cache_bytes=%8 pending=%9 process_mem_bytes=%10")
                                 .arg(displayNameForPath(request.filePath))
                                 .arg(request.sessionId)
                                 .arg(request.kind == RenderKind::Thumbnail ? QStringLiteral("thumbnail") : QStringLiteral("page"))
                                 .arg(request.pageIndex)
                                 .arg(request.scale, 0, 'f', 2)
                                 .arg(canceled ? QStringLiteral("true") : QStringLiteral("false"))
                                 .arg(totalElapsedMs)
                                 .arg(m_cacheBytes)
                                 .arg(pendingCount())
                                 .arg(processBytes);
        emit renderCompleted(request.filePath,
                             request.sessionId,
                             request.pageIndex,
                             request.kind == RenderKind::Thumbnail,
                             request.scale,
                             entry.source,
                             canceled,
                             true,
                             firstPageVisibleMs,
                             m_cacheBytes,
                             processBytes,
                             m_peakProcessMemoryBytes,
                             pendingCount());
        emit metricsUpdated(m_cacheBytes, processBytes, m_peakProcessMemoryBytes, pendingCount(), m_rendering);
    }

    void processNext()
    {
        if (m_rendering)
            return;

        while (!m_pendingOrder.isEmpty()) {
            const QString key = m_pendingOrder.takeFirst();
            if (!m_pending.contains(key))
                continue;

            const RenderRequest request = m_pending.take(key);
            auto docIt = m_documents.find(request.filePath);
            if (docIt == m_documents.end() || docIt.value().isNull() || request.sessionId != docIt.value()->activeSessionId)
                continue;

            QElapsedTimer renderTimer;
            renderTimer.start();
            m_rendering = true;
            emit metricsUpdated(m_cacheBytes,
                                currentProcessMemoryBytes(),
                                m_peakProcessMemoryBytes,
                                pendingCount(),
                                true);

            QString source;
            bool canceled = false;
            int firstPageVisibleMs = -1;
            int displayListCachePages = 0;

            if (ensureEngine(request.filePath)) {
                DocumentState &state = ensureDocumentState(request.filePath);
                DisplayListEntry *displayListEntry = ensureDisplayList(state, request.pageIndex);
                const QImage image = displayListEntry
                    ? renderDisplayListToImage(state.engine.context(),
                                               displayListEntry,
                                               static_cast<float>(request.scale))
                    : renderPageToImage(state.engine.context(),
                                        state.engine.document(),
                                        request.pageIndex,
                                        static_cast<float>(request.scale));
                displayListCachePages = state.displayLists.size();
                canceled = request.sessionId != state.activeSessionId;

                if (!canceled && !image.isNull() && m_imageProvider) {
                    CacheEntry entry;
                    entry.source = m_imageProvider->storeImage(key, image);
                    entry.bytes = static_cast<qint64>(image.sizeInBytes());
                    source = entry.source;
                    if (!entry.source.isEmpty())
                        insertCache(key, entry);

                    if (request.kind == RenderKind::Page && request.pageIndex == 0 && !state.firstPageReported) {
                        state.firstPageReported = true;
                        firstPageVisibleMs = state.openTimer.isValid()
                            ? static_cast<int>(state.openTimer.elapsed())
                            : -1;
                        qInfo().noquote() << QStringLiteral("[render-first-page] file=\"%1\" session=%2 elapsed_ms=%3 source=worker")
                                                 .arg(displayNameForPath(request.filePath))
                                                 .arg(request.sessionId)
                                                 .arg(firstPageVisibleMs);
                    }
                }
            }

            const qint64 processBytes = currentProcessMemoryBytes();
            const qint64 totalElapsedMs = request.enqueuedAtMs > 0
                ? std::max<qint64>(0, QDateTime::currentMSecsSinceEpoch() - request.enqueuedAtMs)
                : renderTimer.elapsed();
            m_peakProcessMemoryBytes = std::max(m_peakProcessMemoryBytes, processBytes);
            m_rendering = false;
            qInfo().noquote() << QStringLiteral("[render] done file=\"%1\" session=%2 kind=%3 page=%4 scale=%5 from_cache=false canceled=%6 render_ms=%7 total_ms=%8 cache_bytes=%9 pending=%10 process_mem_bytes=%11 display_lists=%12")
                                     .arg(displayNameForPath(request.filePath))
                                     .arg(request.sessionId)
                                     .arg(request.kind == RenderKind::Thumbnail ? QStringLiteral("thumbnail") : QStringLiteral("page"))
                                     .arg(request.pageIndex)
                                     .arg(request.scale, 0, 'f', 2)
                                     .arg(canceled ? QStringLiteral("true") : QStringLiteral("false"))
                                     .arg(renderTimer.elapsed())
                                     .arg(totalElapsedMs)
                                     .arg(m_cacheBytes)
                                     .arg(pendingCount())
                                     .arg(processBytes)
                                     .arg(displayListCachePages);

            emit renderCompleted(request.filePath,
                                 request.sessionId,
                                 request.pageIndex,
                                 request.kind == RenderKind::Thumbnail,
                                 request.scale,
                                 canceled ? QString() : source,
                                 canceled,
                                 false,
                                 firstPageVisibleMs,
                                 m_cacheBytes,
                                 processBytes,
                                 m_peakProcessMemoryBytes,
                                 pendingCount());
            emit metricsUpdated(m_cacheBytes, processBytes, m_peakProcessMemoryBytes, pendingCount(), !m_pending.isEmpty());
            QMetaObject::invokeMethod(this, &DocumentRenderWorker::processNext, Qt::QueuedConnection);
            return;
        }

        m_rendering = false;
        const qint64 processBytes = currentProcessMemoryBytes();
        m_peakProcessMemoryBytes = std::max(m_peakProcessMemoryBytes, processBytes);
        emit metricsUpdated(m_cacheBytes, processBytes, m_peakProcessMemoryBytes, pendingCount(), false);
    }

    bool ensureEngine(const QString &filePath)
    {
        DocumentState &state = ensureDocumentState(filePath);
        if (state.engine.context() && state.engine.document())
            return true;
        state.clearDisplayListCache();
        return state.engine.open(filePath);
    }

    DisplayListEntry *ensureDisplayList(DocumentState &state, int pageIndex)
    {
        if (pageIndex < 0)
            return nullptr;

        auto cachedIt = state.displayLists.find(pageIndex);
        if (cachedIt != state.displayLists.end()) {
            touchDisplayList(state, pageIndex);
            return &cachedIt.value();
        }

        fz_context *ctx = state.engine.context();
        fz_document *doc = state.engine.document();
        if (!ctx || !doc)
            return nullptr;

        fz_display_list *list = nullptr;
        fz_try(ctx)
        {
            list = fz_new_display_list_from_page_number(ctx, doc, pageIndex);
        }
        fz_catch(ctx)
        {
            list = nullptr;
        }

        if (!list)
            return nullptr;

        DisplayListEntry entry;
        entry.list = list;
        entry.lastUsedMs = QDateTime::currentMSecsSinceEpoch();
        state.displayLists.insert(pageIndex, entry);
        state.displayListOrder.removeAll(pageIndex);
        state.displayListOrder.append(pageIndex);
        pruneDisplayListCache(state);

        auto insertedIt = state.displayLists.find(pageIndex);
        return insertedIt == state.displayLists.end() ? nullptr : &insertedIt.value();
    }

    void touchDisplayList(DocumentState &state, int pageIndex)
    {
        auto it = state.displayLists.find(pageIndex);
        if (it == state.displayLists.end())
            return;

        it.value().lastUsedMs = QDateTime::currentMSecsSinceEpoch();
        state.displayListOrder.removeAll(pageIndex);
        state.displayListOrder.append(pageIndex);
    }

    QImage renderDisplayListToImage(fz_context *ctx, const DisplayListEntry *displayListEntry, float scale)
    {
        if (!ctx || !displayListEntry || !displayListEntry->list || scale <= 0.0f)
            return {};

        fz_pixmap *pix = nullptr;
        QImage image;

        fz_try(ctx)
        {
            const fz_matrix matrix = fz_scale(scale, scale);
            pix = fz_new_pixmap_from_display_list(ctx, displayListEntry->list, matrix, fz_device_rgb(ctx), 0);
            image = pixmapToImage(pix);
        }
        fz_always(ctx)
        {
            if (pix)
                fz_drop_pixmap(ctx, pix);
        }
        fz_catch(ctx)
        {
            image = QImage();
        }

        return image;
    }

    void pruneDisplayListCache(DocumentState &state, int minimumPage = -1, int maximumPage = -1)
    {
        if (minimumPage >= 0 && maximumPage >= minimumPage) {
            for (int i = state.displayListOrder.size() - 1; i >= 0; --i) {
                const int pageIndex = state.displayListOrder.at(i);
                if (pageIndex >= minimumPage && pageIndex <= maximumPage)
                    continue;
                dropDisplayList(state, pageIndex);
            }
        }

        while (state.displayLists.size() > kMaxDisplayListCachePages && !state.displayListOrder.isEmpty()) {
            dropDisplayList(state, state.displayListOrder.constFirst());
        }
    }

    void dropDisplayList(DocumentState &state, int pageIndex)
    {
        auto it = state.displayLists.find(pageIndex);
        if (it == state.displayLists.end()) {
            state.displayListOrder.removeAll(pageIndex);
            return;
        }

        fz_context *ctx = state.engine.context();
        if (ctx && it.value().list)
            fz_drop_display_list(ctx, it.value().list);

        state.displayLists.erase(it);
        state.displayListOrder.removeAll(pageIndex);
    }

    void trimPendingRequests(const RenderRequest &latestRequest)
    {
        const int maxPendingForKind = latestRequest.kind == RenderKind::Thumbnail ? 12 : 24;
        int matchingCount = 0;
        int removedCount = 0;
        for (const QString &key : std::as_const(m_pendingOrder)) {
            const auto it = m_pending.constFind(key);
            if (it == m_pending.constEnd())
                continue;

            const RenderRequest &request = it.value();
            if (request.filePath == latestRequest.filePath &&
                request.sessionId == latestRequest.sessionId &&
                request.kind == latestRequest.kind) {
                ++matchingCount;
            }
        }

        if (matchingCount <= maxPendingForKind)
            return;

        const QString latestKey = cacheKeyFor(latestRequest);
        while (matchingCount > maxPendingForKind) {
            int removalIndex = -1;
            int removalScore = -1;

            for (int i = 0; i < m_pendingOrder.size(); ++i) {
                const QString key = m_pendingOrder.at(i);
                auto it = m_pending.find(key);
                if (it == m_pending.end())
                    continue;

                const RenderRequest request = it.value();
                if (request.filePath != latestRequest.filePath ||
                    request.sessionId != latestRequest.sessionId ||
                    request.kind != latestRequest.kind ||
                    key == latestKey) {
                    continue;
                }

                int score = 0;
                if (latestRequest.kind == RenderKind::Page) {
                    const int delta = request.pageIndex - latestRequest.pageIndex;
                    score = delta >= 0 ? delta : -delta;
                }

                if (removalIndex < 0 ||
                    score > removalScore ||
                    (score == removalScore && i < removalIndex)) {
                    removalIndex = i;
                    removalScore = score;
                }
            }

            if (removalIndex < 0)
                break;

            const QString key = m_pendingOrder.at(removalIndex);
            auto it = m_pending.find(key);
            if (it == m_pending.end()) {
                m_pendingOrder.removeAt(removalIndex);
                continue;
            }

            m_pendingOrder.removeAt(removalIndex);
            m_pending.erase(it);
            --matchingCount;
            ++removedCount;
        }

        if (removedCount > 0) {
            qInfo().noquote() << QStringLiteral("[render-queue] trimmed file=\"%1\" kind=%2 removed=%3 kept=%4")
                                     .arg(displayNameForPath(latestRequest.filePath))
                                     .arg(latestRequest.kind == RenderKind::Thumbnail ? QStringLiteral("thumbnail") : QStringLiteral("page"))
                                     .arg(removedCount)
                                     .arg(matchingCount);
        }
    }

    DocumentState &ensureDocumentState(const QString &filePath)
    {
        auto &statePtr = m_documents[filePath];
        if (statePtr.isNull())
            statePtr.reset(new DocumentState);
        return *statePtr;
    }

    void insertCache(const QString &key, const CacheEntry &entry)
    {
        if (m_cache.contains(key)) {
            if (m_imageProvider)
                m_imageProvider->removeImageForKey(key);
            m_cacheBytes -= m_cache.value(key).bytes;
        }

        m_cache.insert(key, entry);
        m_cacheBytes += entry.bytes;
    }

    void removeCacheForPath(const QString &filePath)
    {
        const QString prefix = filePath + QLatin1Char('|');
        for (auto it = m_cache.begin(); it != m_cache.end();) {
            if (it.key().startsWith(prefix)) {
                if (m_imageProvider)
                    m_imageProvider->removeImageForKey(it.key());
                m_cacheBytes -= it.value().bytes;
                it = m_cache.erase(it);
            } else {
                ++it;
            }
        }
    }

    int pendingCount() const
    {
        return m_pending.size() + (m_rendering ? 1 : 0);
    }

    PdfRenderImageProvider *m_imageProvider = nullptr;
    QHash<QString, RenderRequest> m_pending;
    QStringList m_pendingOrder;
    QHash<QString, CacheEntry> m_cache;
    QHash<QString, QSharedPointer<DocumentState>> m_documents;
    qint64 m_cacheBytes = 0;
    qint64 m_peakProcessMemoryBytes = 0;
    bool m_rendering = false;
};

DocumentRenderController::DocumentRenderController(PdfRenderImageProvider *imageProvider, QObject *parent)
    : QObject(parent)
    , m_workerThread(new QThread(this))
    , m_worker(new DocumentRenderWorker(imageProvider))
{
    m_worker->moveToThread(m_workerThread);

    connect(m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(this,
            &DocumentRenderController::requestMarkDocumentOpened,
            m_worker,
            &DocumentRenderWorker::markDocumentOpened,
            Qt::QueuedConnection);
    connect(this,
            &DocumentRenderController::requestPageRenderInternal,
            m_worker,
            &DocumentRenderWorker::enqueuePageRender,
            Qt::QueuedConnection);
    connect(this,
            &DocumentRenderController::requestThumbnailRenderInternal,
            m_worker,
            &DocumentRenderWorker::enqueueThumbnailRender,
            Qt::QueuedConnection);
    connect(this,
            &DocumentRenderController::requestPrunePageCache,
            m_worker,
            &DocumentRenderWorker::prunePageCache,
            Qt::QueuedConnection);
    connect(this,
            &DocumentRenderController::requestReleaseDocument,
            m_worker,
            &DocumentRenderWorker::releaseDocument,
            Qt::QueuedConnection);
    connect(this,
            &DocumentRenderController::requestClear,
            m_worker,
            &DocumentRenderWorker::clear,
            Qt::QueuedConnection);
    connect(m_worker,
            &DocumentRenderWorker::renderCompleted,
            this,
            &DocumentRenderController::handleRenderCompleted,
            Qt::QueuedConnection);
    connect(m_worker,
            &DocumentRenderWorker::metricsUpdated,
            this,
            &DocumentRenderController::handleMetricsUpdated,
            Qt::QueuedConnection);

    m_workerThread->start();
}

DocumentRenderController::~DocumentRenderController()
{
    if (m_workerThread) {
        m_workerThread->quit();
        m_workerThread->wait();
    }
}

void DocumentRenderController::markDocumentOpened(const QString &filePath, int sessionId)
{
    emit requestMarkDocumentOpened(filePath, sessionId);
}

void DocumentRenderController::requestPageRender(const QString &filePath, int pageIndex, qreal scale, int sessionId)
{
    emit requestPageRenderInternal(filePath, pageIndex, scale, sessionId);
}

void DocumentRenderController::requestThumbnailRender(const QString &filePath, int pageIndex, int sessionId)
{
    emit requestThumbnailRenderInternal(filePath, pageIndex, sessionId);
}

void DocumentRenderController::releaseDocument(const QString &filePath, int sessionId)
{
    emit requestReleaseDocument(filePath, sessionId);
}

void DocumentRenderController::releaseDocumentSync(const QString &filePath, int sessionId)
{
    if (!m_worker)
        return;

    QMetaObject::invokeMethod(m_worker,
                              [worker = m_worker, filePath, sessionId]() {
                                  worker->releaseDocument(filePath, sessionId);
                              },
                              Qt::BlockingQueuedConnection);
}

void DocumentRenderController::prunePageCache(const QString &filePath, int centerPage, int radius, int sessionId)
{
    emit requestPrunePageCache(filePath, centerPage, radius, sessionId);
}

void DocumentRenderController::clear()
{
    emit requestClear();
}

void DocumentRenderController::handleRenderCompleted(const QString &filePath,
                                                     int sessionId,
                                                     int pageIndex,
                                                     bool thumbnail,
                                                     qreal scale,
                                                     const QString &source,
                                                     bool canceled,
                                                     bool fromCache,
                                                     int firstPageVisibleMs,
                                                     qint64 cacheBytes,
                                                     qint64 processMemoryBytes,
                                                     qint64 peakProcessMemoryBytes,
                                                     int pendingCount)
{
    setMetrics(cacheBytes, processMemoryBytes, peakProcessMemoryBytes, pendingCount, pendingCount > 0);
    emit renderCompleted(filePath,
                         sessionId,
                         pageIndex,
                         thumbnail,
                         scale,
                         source,
                         canceled,
                         fromCache,
                         firstPageVisibleMs,
                         cacheBytes,
                         processMemoryBytes,
                         peakProcessMemoryBytes,
                         pendingCount);
}

void DocumentRenderController::handleMetricsUpdated(qint64 cacheBytes,
                                                    qint64 processMemoryBytes,
                                                    qint64 peakProcessMemoryBytes,
                                                    int pendingCount,
                                                    bool busy)
{
    setMetrics(cacheBytes, processMemoryBytes, peakProcessMemoryBytes, pendingCount, busy);
}

void DocumentRenderController::setMetrics(qint64 cacheBytes,
                                          qint64 processMemoryBytes,
                                          qint64 peakProcessMemoryBytes,
                                          int pendingCount,
                                          bool busy)
{
    const bool metricsChangedNeeded =
        m_cacheBytes != cacheBytes ||
        m_processMemoryBytes != processMemoryBytes ||
        m_peakProcessMemoryBytes != peakProcessMemoryBytes ||
        m_pendingCount != pendingCount;

    if (m_busy != busy) {
        m_busy = busy;
        emit busyChanged();
    }

    if (!metricsChangedNeeded)
        return;

    m_cacheBytes = cacheBytes;
    m_processMemoryBytes = processMemoryBytes;
    m_peakProcessMemoryBytes = peakProcessMemoryBytes;
    m_pendingCount = pendingCount;
    emit metricsChanged();
}

#include "DocumentRenderController.moc"
