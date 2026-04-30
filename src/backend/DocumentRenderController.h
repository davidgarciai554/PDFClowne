#pragma once

#include <QObject>

class QThread;

class DocumentRenderWorker;
class PdfRenderImageProvider;

class DocumentRenderController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY metricsChanged)
    Q_PROPERTY(qint64 cacheBytes READ cacheBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 processMemoryBytes READ processMemoryBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 peakProcessMemoryBytes READ peakProcessMemoryBytes NOTIFY metricsChanged)

public:
    explicit DocumentRenderController(PdfRenderImageProvider *imageProvider, QObject *parent = nullptr);
    ~DocumentRenderController() override;

    bool busy() const { return m_busy; }
    int pendingCount() const { return m_pendingCount; }
    qint64 cacheBytes() const { return m_cacheBytes; }
    qint64 processMemoryBytes() const { return m_processMemoryBytes; }
    qint64 peakProcessMemoryBytes() const { return m_peakProcessMemoryBytes; }

    Q_INVOKABLE void markDocumentOpened(const QString &filePath, int sessionId, const QString &password = QString());
    Q_INVOKABLE void requestPageRender(const QString &filePath, int pageIndex, qreal scale, int sessionId);
    Q_INVOKABLE void requestThumbnailRender(const QString &filePath, int pageIndex, int sessionId);
    Q_INVOKABLE void prunePageCache(const QString &filePath, int centerPage, int radius, int sessionId);
    Q_INVOKABLE void releaseDocument(const QString &filePath, int sessionId);
    Q_INVOKABLE void releaseDocumentSync(const QString &filePath, int sessionId);
    Q_INVOKABLE void clear();

signals:
    void requestMarkDocumentOpened(const QString &filePath, int sessionId, const QString &password);
    void requestPageRenderInternal(const QString &filePath, int pageIndex, qreal scale, int sessionId);
    void requestThumbnailRenderInternal(const QString &filePath, int pageIndex, int sessionId);
    void requestPrunePageCache(const QString &filePath, int centerPage, int radius, int sessionId);
    void requestReleaseDocument(const QString &filePath, int sessionId);
    void requestClear();
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
    void metricsChanged();
    void busyChanged();

private slots:
    void handleRenderCompleted(const QString &filePath,
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
    void handleMetricsUpdated(qint64 cacheBytes,
                              qint64 processMemoryBytes,
                              qint64 peakProcessMemoryBytes,
                              int pendingCount,
                              bool busy);

private:
    void setMetrics(qint64 cacheBytes,
                    qint64 processMemoryBytes,
                    qint64 peakProcessMemoryBytes,
                    int pendingCount,
                    bool busy);

    QThread *m_workerThread = nullptr;
    DocumentRenderWorker *m_worker = nullptr;
    bool m_busy = false;
    int m_pendingCount = 0;
    qint64 m_cacheBytes = 0;
    qint64 m_processMemoryBytes = 0;
    qint64 m_peakProcessMemoryBytes = 0;
};
