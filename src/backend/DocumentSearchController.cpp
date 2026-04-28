#include "DocumentSearchController.h"

#include <QAtomicInteger>
#include <QByteArray>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QThread>
#include <QUrl>

#include <algorithm>

#include <mupdf/fitz.h>

namespace {
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

QString normalizedSearchText(const QString &text)
{
    QString normalized = text;
    normalized.replace(QRegularExpression(QStringLiteral("\\s+")), QStringLiteral(" "));
    return normalized.trimmed();
}

QString snippetForMatch(const QString &pageText, const QString &query, int occurrenceIndex)
{
    const QString text = normalizedSearchText(pageText);
    const QString needle = normalizedSearchText(query);
    if (text.isEmpty() || needle.isEmpty())
        return {};

    const QString haystackFolded = text.toCaseFolded();
    const QString needleFolded = needle.toCaseFolded();

    int from = 0;
    int matchIndex = -1;
    for (int i = 0; i <= occurrenceIndex; ++i) {
        matchIndex = haystackFolded.indexOf(needleFolded, from);
        if (matchIndex < 0)
            break;
        from = matchIndex + needleFolded.size();
    }

    if (matchIndex < 0)
        matchIndex = haystackFolded.indexOf(needleFolded);
    if (matchIndex < 0)
        return text.left(160);

    const int snippetRadius = 54;
    const int start = std::max(0, matchIndex - snippetRadius);
    const int end = std::min(text.size(), matchIndex + needle.size() + snippetRadius);
    QString snippet = text.mid(start, end - start).trimmed();

    if (start > 0)
        snippet.prepend(QStringLiteral("..."));
    if (end < text.size())
        snippet.append(QStringLiteral("..."));

    return snippet;
}

QJsonObject rectToJson(const fz_rect &rect)
{
    QJsonObject object;
    object.insert(QStringLiteral("x"), rect.x0);
    object.insert(QStringLiteral("y"), rect.y0);
    object.insert(QStringLiteral("width"), rect.x1 - rect.x0);
    object.insert(QStringLiteral("height"), rect.y1 - rect.y0);
    return object;
}

QJsonObject quadToJson(const fz_quad &quad)
{
    return rectToJson(fz_rect_from_quad(quad));
}
}

class DocumentSearchWorker : public QObject
{
    Q_OBJECT

public slots:
    void search(const QString &filePath, const QString &query, int requestId)
    {
        QElapsedTimer timer;
        timer.start();
        const int sequence = ++m_sequence;
        const QString localPath = toLocalPath(filePath);
        const QString trimmed = query.trimmed();
        int scannedPages = 0;

        if (trimmed.isEmpty()) {
            emit searchCompleted(localPath, requestId, trimmed, QStringLiteral("[]"), false);
            return;
        }

        qInfo().noquote() << QStringLiteral("[search] start file=\"%1\" request=%2 query=\"%3\"")
                                 .arg(displayNameForPath(localPath))
                                 .arg(requestId)
                                 .arg(trimmed);

        fz_context *ctx = nullptr;
        fz_document *doc = nullptr;
        QJsonArray resultsJson;
        bool canceled = false;

        ctx = fz_new_context(nullptr, nullptr, FZ_STORE_UNLIMITED);
        if (!ctx) {
            emit searchCompleted(localPath, requestId, trimmed, QStringLiteral("[]"), false);
            return;
        }

        const QByteArray pathBytes = localPath.toUtf8();

        fz_try(ctx)
        {
            fz_register_document_handlers(ctx);
            doc = fz_open_document(ctx, pathBytes.constData());

            if (fz_needs_password(ctx, doc))
                fz_throw(ctx, FZ_ERROR_GENERIC, "password-protected PDFs are not enabled in this build");

            const int pageCount = fz_count_pages(ctx, doc);
            for (int pageIndex = 0; pageIndex < pageCount; ++pageIndex) {
                if (sequence != m_sequence.loadAcquire()) {
                    canceled = true;
                    break;
                }
                ++scannedPages;

                fz_page *page = nullptr;
                fz_stext_page *textPage = nullptr;
                fz_buffer *buffer = nullptr;
                fz_output *output = nullptr;
                QString pageText;

                fz_try(ctx)
                {
                    fz_stext_options options = {};
                    page = fz_load_page(ctx, doc, pageIndex);
                    textPage = fz_new_stext_page_from_page(ctx, page, &options);

                    constexpr int kMaxHits = 256;
                    int marks[kMaxHits] = {};
                    fz_quad quads[kMaxHits];
                    const QByteArray needle = trimmed.toUtf8();
                    const int hitCount = fz_search_stext_page(ctx, textPage, needle.constData(), marks, quads, kMaxHits);
                    const int limit = std::max(0, std::min(hitCount, kMaxHits));

                    if (limit > 0) {
                        buffer = fz_new_buffer(ctx, 256);
                        output = fz_new_output_with_buffer(ctx, buffer);
                        fz_print_stext_page_as_text(ctx, output, textPage);
                        fz_close_output(ctx, output);
                        pageText = QString::fromUtf8(fz_string_from_buffer(ctx, buffer)).trimmed();
                    }

                    for (int i = 0; i < limit; ++i) {
                        QJsonObject item;
                        item.insert(QStringLiteral("pageIndex"), pageIndex);
                        item.insert(QStringLiteral("pageLabel"), pageIndex + 1);
                        item.insert(QStringLiteral("snippet"), snippetForMatch(pageText, trimmed, i));
                        item.insert(QStringLiteral("rect"), quadToJson(quads[i]));
                        resultsJson.append(item);
                    }
                }
                fz_always(ctx)
                {
                    if (output)
                        fz_drop_output(ctx, output);
                    if (buffer)
                        fz_drop_buffer(ctx, buffer);
                    if (textPage)
                        fz_drop_stext_page(ctx, textPage);
                    if (page)
                        fz_drop_page(ctx, page);
                }
                fz_catch(ctx)
                {
                }
            }
        }
        fz_always(ctx)
        {
            if (doc)
                fz_drop_document(ctx, doc);
            fz_drop_context(ctx);
        }
        fz_catch(ctx)
        {
            resultsJson = QJsonArray();
        }

        qInfo().noquote() << QStringLiteral("[search] done file=\"%1\" request=%2 query=\"%3\" pages=%4 results=%5 canceled=%6 elapsed_ms=%7")
                                 .arg(displayNameForPath(localPath))
                                 .arg(requestId)
                                 .arg(trimmed)
                                 .arg(scannedPages)
                                 .arg(resultsJson.size())
                                 .arg(canceled || sequence != m_sequence.loadAcquire() ? QStringLiteral("true") : QStringLiteral("false"))
                                 .arg(timer.elapsed());

        emit searchCompleted(
            localPath,
            requestId,
            trimmed,
            QString::fromUtf8(QJsonDocument(resultsJson).toJson(QJsonDocument::Compact)),
            canceled || sequence != m_sequence.loadAcquire());
    }

signals:
    void searchCompleted(const QString &filePath, int requestId, const QString &query, const QString &resultsJson, bool canceled);

private:
    QAtomicInteger<int> m_sequence = 0;
};

DocumentSearchController::DocumentSearchController(QObject *parent)
    : QObject(parent)
    , m_workerThread(new QThread(this))
    , m_worker(new DocumentSearchWorker)
{
    m_worker->moveToThread(m_workerThread);

    connect(m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(this, &DocumentSearchController::requestSearch, m_worker, &DocumentSearchWorker::search, Qt::QueuedConnection);
    connect(m_worker, &DocumentSearchWorker::searchCompleted, this, &DocumentSearchController::handleSearchCompleted, Qt::QueuedConnection);

    m_workerThread->start();
}

DocumentSearchController::~DocumentSearchController()
{
    if (m_workerThread) {
        m_workerThread->quit();
        m_workerThread->wait();
    }
}

void DocumentSearchController::searchDocument(const QString &filePath, const QString &query, int requestId)
{
    setBusy(true);
    emit requestSearch(filePath, query, requestId);
}

void DocumentSearchController::handleSearchCompleted(const QString &filePath, int requestId, const QString &query, const QString &resultsJson, bool canceled)
{
    setBusy(false);
    emit searchCompleted(filePath, requestId, query, resultsJson, canceled);
}

void DocumentSearchController::setBusy(bool busy)
{
    if (m_busy == busy)
        return;

    m_busy = busy;
    emit busyChanged();
}

#include "DocumentSearchController.moc"
