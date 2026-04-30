#include "PdfDocument.h"

#include <QBuffer>
#include <QByteArray>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QIODevice>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QStringList>
#include <QUrl>
#include <QVector>
#include <QRegularExpression>

#include <mupdf/fitz.h>
#include <mupdf/pdf.h>

#include <algorithm>

namespace {
constexpr float kRenderScale = 4.0f;
constexpr float kThumbnailScale = 0.30f;

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

QString ensurePdfSuffix(const QString &path)
{
    const QFileInfo fileInfo(path);
    if (fileInfo.suffix().compare(QLatin1String("pdf"), Qt::CaseInsensitive) == 0)
        return path;

    return path + QStringLiteral(".pdf");
}

QString tempPdfPathFor(const QString &targetPath)
{
    const QFileInfo targetInfo(targetPath);
    const QString basePath = targetInfo.absoluteDir().absoluteFilePath(
        targetInfo.completeBaseName() + QStringLiteral(".pdfclowne-save"));

    for (int attempt = 0; attempt < 1000; ++attempt) {
        const QString suffix = attempt == 0
            ? QStringLiteral(".tmp.pdf")
            : QStringLiteral(".%1.tmp.pdf").arg(attempt);
        const QString tempPath = basePath + suffix;
        if (!QFileInfo::exists(tempPath))
            return tempPath;
    }

    return {};
}

bool replaceFileWithBackup(const QString &sourcePath, const QString &replacementPath, QString *error)
{
    const QFileInfo sourceInfo(sourcePath);
    const QString backupPath = sourceInfo.absoluteDir().absoluteFilePath(
        sourceInfo.fileName() + QStringLiteral(".pdfclowne-backup"));

    QFile::remove(backupPath);
    if (!QFile::rename(sourcePath, backupPath)) {
        if (error)
            *error = QObject::tr("Could not prepare the original PDF for overwrite.");
        return false;
    }

    if (!QFile::rename(replacementPath, sourcePath)) {
        QFile::rename(backupPath, sourcePath);
        if (error)
            *error = QObject::tr("Could not replace the original PDF.");
        return false;
    }

    QFile::remove(backupPath);
    return true;
}

QVector<int> parseRotations(const QString &rotationsJson)
{
    QVector<int> rotations;
    const QJsonDocument document = QJsonDocument::fromJson(rotationsJson.toUtf8());
    if (!document.isArray())
        return rotations;

    const QJsonArray array = document.array();
    rotations.reserve(array.size());
    for (const QJsonValue &value : array) {
        int rotation = value.toInt(0) % 360;
        if (rotation < 0)
            rotation += 360;
        rotations.append(rotation);
    }

    return rotations;
}

QString pixmapToDataUrl(fz_pixmap *pix)
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
    const QImage owned = image.copy();

    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    owned.save(&buffer, "PNG");

    return QStringLiteral("data:image/png;base64,") + QString::fromLatin1(png.toBase64());
}

void dropOpenDocument(fz_context *&ctx, fz_document *&doc)
{
    if (doc) {
        fz_drop_document(ctx, doc);
        doc = nullptr;
    }

    if (ctx) {
        fz_drop_context(ctx);
        ctx = nullptr;
    }
}

QString renderPageToDataUrl(fz_context *ctx, fz_document *doc, int pageIndex, float scale, QString *error)
{
    if (!ctx || !doc || pageIndex < 0)
        return {};

    fz_pixmap *pix = nullptr;
    QString source;

    fz_try(ctx)
    {
        const fz_matrix matrix = fz_scale(scale, scale);
        pix = fz_new_pixmap_from_page_number(ctx, doc, pageIndex, matrix, fz_device_rgb(ctx), 0);
        source = pixmapToDataUrl(pix);
    }
    fz_catch(ctx)
    {
        if (error)
            *error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (pix)
        fz_drop_pixmap(ctx, pix);

    return source;
}

int resolveUriPageNumber(fz_context *ctx, fz_document *doc, const char *uri, float *x = nullptr, float *y = nullptr)
{
    if (!ctx || !doc || !uri || !*uri)
        return -1;

    int pageNumber = -1;
    fz_try(ctx)
    {
        float resolvedX = 0.0f;
        float resolvedY = 0.0f;
        const fz_location location = fz_resolve_link(ctx, doc, uri, &resolvedX, &resolvedY);
        pageNumber = fz_page_number_from_location(ctx, doc, location);
        if (x)
            *x = resolvedX;
        if (y)
            *y = resolvedY;
    }
    fz_catch(ctx)
    {
        pageNumber = -1;
    }

    return pageNumber;
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

QJsonArray pointToJson(const fz_point &point)
{
    return QJsonArray{ point.x, point.y };
}

QJsonArray quadPathToJson(const fz_quad &quad)
{
    return QJsonArray{
        pointToJson(quad.ul),
        pointToJson(quad.ur),
        pointToJson(quad.lr),
        pointToJson(quad.ll)
    };
}

QString selectionGeometryToJson(const QVector<fz_quad> &quads, int count)
{
    QJsonArray geometry;
    const int safeCount = std::clamp(count, 0, static_cast<int>(quads.size()));
    for (int i = 0; i < safeCount; ++i)
        geometry.append(quadPathToJson(quads.at(i)));
    return QString::fromUtf8(QJsonDocument(geometry).toJson(QJsonDocument::Compact));
}

QJsonArray outlineToJson(fz_context *ctx, fz_document *doc, fz_outline *outline)
{
    QJsonArray items;

    for (fz_outline *node = outline; node; node = node->next) {
        QJsonObject entry;
        entry.insert(QStringLiteral("title"), QString::fromUtf8(node->title ? node->title : ""));
        entry.insert(QStringLiteral("uri"), QString::fromUtf8(node->uri ? node->uri : ""));
        entry.insert(QStringLiteral("isOpen"), node->is_open != 0);
        entry.insert(QStringLiteral("x"), node->x);
        entry.insert(QStringLiteral("y"), node->y);

        int pageIndex = -1;
        if (ctx && doc)
            pageIndex = fz_page_number_from_location(ctx, doc, node->page);
        entry.insert(QStringLiteral("pageIndex"), pageIndex);
        entry.insert(QStringLiteral("children"), outlineToJson(ctx, doc, node->down));
        items.append(entry);
    }

    return items;
}

QString extractPageTextInternal(fz_context *ctx, fz_document *doc, int pageIndex, QString *error)
{
    if (!ctx || !doc || pageIndex < 0)
        return {};

    fz_page *page = nullptr;
    fz_stext_page *textPage = nullptr;
    fz_buffer *buffer = nullptr;
    fz_output *output = nullptr;
    QString extracted;

    fz_try(ctx)
    {
        fz_stext_options options = {};
        page = fz_load_page(ctx, doc, pageIndex);
        textPage = fz_new_stext_page_from_page(ctx, page, &options);
        buffer = fz_new_buffer(ctx, 256);
        output = fz_new_output_with_buffer(ctx, buffer);
        fz_print_stext_page_as_text(ctx, output, textPage);
        fz_close_output(ctx, output);
        extracted = QString::fromUtf8(fz_string_from_buffer(ctx, buffer)).trimmed();
    }
    fz_catch(ctx)
    {
        if (error)
            *error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (output)
        fz_drop_output(ctx, output);
    if (buffer)
        fz_drop_buffer(ctx, buffer);
    if (textPage)
        fz_drop_stext_page(ctx, textPage);
    if (page)
        fz_drop_page(ctx, page);

    return extracted;
}

QString pageLinksJsonForPage(fz_context *ctx, fz_document *doc, int pageIndex)
{
    if (!ctx || !doc || pageIndex < 0)
        return QStringLiteral("[]");

    fz_page *page = nullptr;
    fz_link *links = nullptr;
    QJsonArray linksJson;

    fz_try(ctx)
    {
        page = fz_load_page(ctx, doc, pageIndex);
        links = fz_load_links(ctx, page);
        for (fz_link *link = links; link; link = link->next) {
            float targetX = 0.0f;
            float targetY = 0.0f;
            const int targetPage = resolveUriPageNumber(ctx, doc, link->uri, &targetX, &targetY);

            QJsonObject item;
            item.insert(QStringLiteral("uri"), QString::fromUtf8(link->uri ? link->uri : ""));
            item.insert(QStringLiteral("external"), link->uri ? fz_is_external_link(ctx, link->uri) != 0 : false);
            item.insert(QStringLiteral("pageIndex"), targetPage);
            item.insert(QStringLiteral("targetX"), targetX);
            item.insert(QStringLiteral("targetY"), targetY);
            item.insert(QStringLiteral("rect"), rectToJson(link->rect));
            linksJson.append(item);
        }
    }
    fz_catch(ctx)
    {
        linksJson = QJsonArray();
    }

    if (links)
        fz_drop_link(ctx, links);
    if (page)
        fz_drop_page(ctx, page);

    return QString::fromUtf8(QJsonDocument(linksJson).toJson(QJsonDocument::Compact));
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
}

class PdfDocument::PdfEngine {
public:
    ~PdfEngine()
    {
        close();
    }

    bool open(const QByteArray &pathBytes, const QString &password, QString *error, bool *passwordRequired)
    {
        close();

        m_ctx = fz_new_context(nullptr, nullptr, FZ_STORE_UNLIMITED);
        if (!m_ctx) {
            if (error)
                *error = PdfDocument::tr("MuPDF could not create a rendering context.");
            return false;
        }

        QString openError;
        const QByteArray passwordBytes = password.toUtf8();
        fz_try(m_ctx)
        {
            fz_register_document_handlers(m_ctx);
            m_doc = fz_open_document(m_ctx, pathBytes.constData());

            if (fz_needs_password(m_ctx, m_doc)) {
                if (passwordRequired)
                    *passwordRequired = true;

                if (passwordBytes.isEmpty()) {
                    openError = QStringLiteral("password-protected PDF requires a password");
                } else if (!fz_authenticate_password(m_ctx, m_doc, passwordBytes.constData())) {
                    openError = QStringLiteral("Incorrect password for password-protected PDF");
                }
            }
        }
        fz_catch(m_ctx)
        {
            openError = QString::fromUtf8(fz_caught_message(m_ctx));
        }

        if (!openError.isEmpty()) {
            if (error)
                *error = openError;
            close();
            return false;
        }

        return true;
    }

    void close()
    {
        clearSelectionCache();
        dropOpenDocument(m_ctx, m_doc);
    }

    bool isOpen() const
    {
        return m_ctx && m_doc;
    }

    fz_context *context() const
    {
        return m_ctx;
    }

    fz_document *document() const
    {
        return m_doc;
    }

    fz_stext_page *selectionTextPage(int pageIndex, QString *error)
    {
        if (!m_ctx || !m_doc || pageIndex < 0)
            return nullptr;

        if (m_selectionTextPage && m_selectionPageIndex == pageIndex)
            return m_selectionTextPage;

        clearSelectionCache();

        QString selectionError;
        fz_try(m_ctx)
        {
            fz_stext_options options = {};
            m_selectionPage = fz_load_page(m_ctx, m_doc, pageIndex);
            m_selectionTextPage = fz_new_stext_page_from_page(m_ctx, m_selectionPage, &options);
            m_selectionPageIndex = pageIndex;
        }
        fz_catch(m_ctx)
        {
            selectionError = QString::fromUtf8(fz_caught_message(m_ctx));
        }

        if (!selectionError.isEmpty()) {
            clearSelectionCache();
            if (error)
                *error = selectionError;
            return nullptr;
        }

        return m_selectionTextPage;
    }

    void clearSelectionCache()
    {
        if (m_selectionTextPage) {
            fz_drop_stext_page(m_ctx, m_selectionTextPage);
            m_selectionTextPage = nullptr;
        }
        if (m_selectionPage) {
            fz_drop_page(m_ctx, m_selectionPage);
            m_selectionPage = nullptr;
        }
        m_selectionPageIndex = -1;
    }

private:
    fz_context *m_ctx = nullptr;
    fz_document *m_doc = nullptr;
    fz_page *m_selectionPage = nullptr;
    fz_stext_page *m_selectionTextPage = nullptr;
    int m_selectionPageIndex = -1;
};

PdfDocument::PdfDocument(QObject *parent)
    : QObject(parent)
    , m_engine(std::make_unique<PdfEngine>())
{
}

PdfDocument::~PdfDocument()
= default;

void PdfDocument::setPassword(const QString &password)
{
    if (m_password == password)
        return;

    m_password = password;
    emit passwordChanged();
}

void PdfDocument::setSelectionState(const QString &text, const QString &geometryJson, int pageIndex)
{
    const QString nextGeometry = geometryJson.isEmpty() ? QStringLiteral("[]") : geometryJson;
    if (m_selectionText == text && m_selectionGeometryJson == nextGeometry && m_selectionPage == pageIndex)
        return;

    m_selectionText = text;
    m_selectionGeometryJson = nextGeometry;
    m_selectionPage = pageIndex;
    emit selectionChanged();
}

void PdfDocument::beginSelection(int pageIndex, const QPointF &point)
{
    m_selectionInProgress = true;
    m_selectionAnchor = point;
    updateSelection(pageIndex, point);
}

void PdfDocument::updateSelection(int pageIndex, const QPointF &point)
{
    fz_context *ctx = m_engine->context();
    if (!ctx || !m_engine->document() || pageIndex < 0 || pageIndex >= m_pageCount) {
        setSelectionState(QString(), QStringLiteral("[]"), -1);
        return;
    }

    if (!m_selectionInProgress)
        m_selectionAnchor = point;

    QString error;
    fz_stext_page *textPage = m_engine->selectionTextPage(pageIndex, &error);
    if (!textPage) {
        setSelectionState(QString(), QStringLiteral("[]"), -1);
        return;
    }

    fz_point anchor = { static_cast<float>(m_selectionAnchor.x()), static_cast<float>(m_selectionAnchor.y()) };
    fz_point cursor = { static_cast<float>(point.x()), static_cast<float>(point.y()) };
    QVector<fz_quad> quads(2048);
    QString selectionText;
    QString geometryJson = QStringLiteral("[]");
    int selectionPageIndex = -1;

    fz_try(ctx)
    {
        fz_snap_selection(ctx, textPage, &anchor, &cursor, FZ_SELECT_WORDS);
        const int quadCount = fz_highlight_selection(ctx, textPage, anchor, cursor, quads.data(), quads.size());
        geometryJson = selectionGeometryToJson(quads, quadCount);
        char *copied = fz_copy_selection(ctx, textPage, anchor, cursor, 0);
        if (copied) {
            selectionText = QString::fromUtf8(copied).trimmed();
            fz_free(ctx, copied);
        }
        if (!selectionText.isEmpty() && quadCount > 0)
            selectionPageIndex = pageIndex;
    }
    fz_catch(ctx)
    {
        selectionText.clear();
        geometryJson = QStringLiteral("[]");
        selectionPageIndex = -1;
    }

    setSelectionState(selectionText, geometryJson, selectionPageIndex);
}

void PdfDocument::endSelection()
{
    m_selectionInProgress = false;
}

void PdfDocument::clearSelection()
{
    m_selectionInProgress = false;
    m_selectionAnchor = QPointF();
    setSelectionState(QString(), QStringLiteral("[]"), -1);
}

void PdfDocument::clear()
{
    if (m_filePath.isEmpty() && m_previewSource.isEmpty() && m_pageSources.isEmpty() &&
        m_thumbnailSources.isEmpty() && m_pageSizesJson.isEmpty() && m_outlineJson.isEmpty() &&
        m_pageLinksJson.isEmpty() && m_pageCount == 0 && m_title.isEmpty() &&
        m_errorMessage.isEmpty() && m_fileSizeBytes == 0 && !m_isLoaded && !m_engine->isOpen())
        return;

    m_engine->close();

    m_filePath.clear();
    m_previewSource.clear();
    m_pageSources.clear();
    m_thumbnailSources.clear();
    m_pageSizesJson.clear();
    m_outlineJson = QStringLiteral("[]");
    m_pageLinksJson = QStringLiteral("[]");
    m_title.clear();
    m_password.clear();
    m_errorMessage.clear();
    m_pageCount = 0;
    m_fileSizeBytes = 0;
    m_isLoaded = false;
    m_passwordRequired = false;
    m_selectionInProgress = false;
    m_selectionAnchor = QPointF();

    emit filePathChanged();
    emit previewSourceChanged();
    emit pageSourcesChanged();
    emit thumbnailSourcesChanged();
    emit pageSizesJsonChanged();
    emit outlineJsonChanged();
    emit pageLinksJsonChanged();
    emit pageCountChanged();
    emit fileSizeBytesChanged();
    emit titleChanged();
    emit passwordChanged();
    emit errorMessageChanged();
    emit isLoadedChanged();
    emit passwordRequiredChanged();
    setSelectionState(QString(), QStringLiteral("[]"), -1);
}

bool PdfDocument::load(const QString &source, const QString &password)
{
    QElapsedTimer timer;
    timer.start();
    const QString localPath = toLocalPath(source);
    const QFileInfo fileInfo(localPath);

    m_previewSource.clear();
    m_pageSources.clear();
    m_thumbnailSources.clear();
    m_pageSizesJson.clear();
    m_outlineJson = QStringLiteral("[]");
    m_pageLinksJson = QStringLiteral("[]");
    const bool hadPasswordRequired = m_passwordRequired;
    m_passwordRequired = false;
    m_errorMessage.clear();
    m_pageCount = 0;
    m_fileSizeBytes = 0;
    m_isLoaded = false;
    m_selectionInProgress = false;
    m_selectionAnchor = QPointF();
    setPassword(QString());
    m_engine->close();
    emit previewSourceChanged();
    emit pageSourcesChanged();
    emit thumbnailSourcesChanged();
    emit pageSizesJsonChanged();
    emit outlineJsonChanged();
    emit pageLinksJsonChanged();
    if (hadPasswordRequired)
        emit passwordRequiredChanged();
    emit errorMessageChanged();
    emit pageCountChanged();
    emit fileSizeBytesChanged();
    emit isLoadedChanged();
    setSelectionState(QString(), QStringLiteral("[]"), -1);

    if (!fileInfo.exists() || !fileInfo.isFile() ||
        fileInfo.suffix().compare(QLatin1String("pdf"), Qt::CaseInsensitive) != 0) {
        m_errorMessage = tr("Select a valid PDF file.");
        emit errorMessageChanged();
        emit loadFailed(m_errorMessage);
        return false;
    }

    const QString canonical = fileInfo.canonicalFilePath();
    if (canonical.isEmpty()) {
        m_errorMessage = tr("The PDF path could not be resolved.");
        emit errorMessageChanged();
        emit loadFailed(m_errorMessage);
        return false;
    }

    m_filePath = canonical;
    m_fileSizeBytes = fileInfo.size();
    m_title = QFileInfo(canonical).fileName();
    emit filePathChanged();
    emit fileSizeBytesChanged();
    emit titleChanged();
    qInfo().noquote() << QStringLiteral("[pdf-load] start file=\"%1\"").arg(displayNameForPath(canonical));

    QString error;
    bool passwordRequired = false;
    const QByteArray pathBytes = canonical.toUtf8();

    if (!m_engine->open(pathBytes, password, &error, &passwordRequired)) {
        m_passwordRequired = passwordRequired;
        m_errorMessage = error.startsWith(QStringLiteral("MuPDF could not create"))
            ? error
            : tr("MuPDF failed to open this PDF: %1").arg(error);
        if (m_passwordRequired)
            emit passwordRequiredChanged();
        emit errorMessageChanged();
        emit loadFailed(m_errorMessage);
        return false;
    }

    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();

    fz_try(ctx)
    {
        m_pageCount = fz_count_pages(ctx, doc);
        if (m_pageCount <= 0)
            fz_throw(ctx, FZ_ERROR_GENERIC, "PDF has no pages");

        QJsonArray pageSizes;
        m_pageSources = QStringList();
        m_thumbnailSources = QStringList();
        m_pageSources.reserve(m_pageCount);
        m_thumbnailSources.reserve(m_pageCount);
        for (int page = 0; page < m_pageCount; ++page) {
            fz_page *loadedPage = fz_load_page(ctx, doc, page);
            const fz_rect bounds = fz_bound_page(ctx, loadedPage);
            fz_drop_page(ctx, loadedPage);

            QJsonObject size;
            size.insert(QStringLiteral("width"), bounds.x1 - bounds.x0);
            size.insert(QStringLiteral("height"), bounds.y1 - bounds.y0);
            pageSizes.append(size);

            m_pageSources.append(QString());
            m_thumbnailSources.append(QString());
        }

        m_pageSizesJson = QString::fromUtf8(QJsonDocument(pageSizes).toJson(QJsonDocument::Compact));

        m_previewSource.clear();
        rebuildNavigationData();
        m_isLoaded = true;
        setPassword(password);
    }
    fz_catch(ctx)
    {
        error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (!error.isEmpty()) {
        m_engine->close();
        m_previewSource.clear();
        m_pageSources.clear();
        m_thumbnailSources.clear();
        m_pageSizesJson.clear();
        m_outlineJson = QStringLiteral("[]");
        m_pageLinksJson = QStringLiteral("[]");
        m_pageCount = 0;
        m_fileSizeBytes = 0;
        m_isLoaded = false;
        m_passwordRequired = false;
        m_errorMessage = tr("MuPDF failed to open this PDF: %1").arg(error);
        emit previewSourceChanged();
        emit pageSourcesChanged();
        emit thumbnailSourcesChanged();
        emit pageSizesJsonChanged();
        emit outlineJsonChanged();
        emit pageLinksJsonChanged();
        emit pageCountChanged();
        emit fileSizeBytesChanged();
        emit errorMessageChanged();
        emit isLoadedChanged();
        emit passwordRequiredChanged();
        emit loadFailed(m_errorMessage);
        qWarning().noquote() << QStringLiteral("[pdf-load] failed file=\"%1\" elapsed_ms=%2 error=\"%3\"")
                                    .arg(displayNameForPath(canonical))
                                    .arg(timer.elapsed())
                                    .arg(error);
        return false;
    }

    emit previewSourceChanged();
    emit pageSourcesChanged();
    emit thumbnailSourcesChanged();
    emit pageSizesJsonChanged();
    emit outlineJsonChanged();
    emit pageLinksJsonChanged();
    emit pageCountChanged();
    emit isLoadedChanged();
    emit loaded();
    qInfo().noquote() << QStringLiteral("[pdf-load] done file=\"%1\" pages=%2 elapsed_ms=%3")
                             .arg(displayNameForPath(canonical))
                             .arg(m_pageCount)
                             .arg(timer.elapsed());
    return true;
}

bool PdfDocument::retryWithPassword(const QString &password)
{
    if (m_filePath.isEmpty())
        return false;

    return load(m_filePath, password);
}

QString PdfDocument::renderPage(int pageIndex, qreal scale)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return {};

    const float safeScale = std::clamp(static_cast<float>(scale), 0.25f, kRenderScale);
    QString error;
    const QString source = renderPageToDataUrl(ctx, doc, pageIndex, safeScale, &error);
    if (source.isEmpty())
        return {};

    if (pageIndex >= 0 && pageIndex < m_pageSources.size() && safeScale >= kRenderScale * 0.95f) {
        m_pageSources[pageIndex] = source;
        emit pageSourcesChanged();
    }

    return source;
}

QString PdfDocument::renderThumbnail(int pageIndex)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return {};

    QString error;
    const QString source = renderPageToDataUrl(ctx, doc, pageIndex, kThumbnailScale, &error);
    if (source.isEmpty())
        return {};

    if (pageIndex >= 0 && pageIndex < m_thumbnailSources.size()) {
        m_thumbnailSources[pageIndex] = source;
        emit thumbnailSourcesChanged();
    }

    return source;
}

QString PdfDocument::searchPage(int pageIndex, const QString &query)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return QStringLiteral("[]");

    const QString trimmed = query.trimmed();
    if (trimmed.isEmpty())
        return QStringLiteral("[]");

    fz_page *page = nullptr;
    fz_stext_page *textPage = nullptr;
    QJsonArray hitsJson;

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
        for (int i = 0; i < limit; ++i)
            hitsJson.append(quadToJson(quads[i]));
    }
    fz_catch(ctx)
    {
        hitsJson = QJsonArray();
    }

    if (textPage)
        fz_drop_stext_page(ctx, textPage);
    if (page)
        fz_drop_page(ctx, page);

    return QString::fromUtf8(QJsonDocument(hitsJson).toJson(QJsonDocument::Compact));
}

QString PdfDocument::searchDocument(const QString &query)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || m_pageCount <= 0)
        return QStringLiteral("[]");

    const QString trimmed = query.trimmed();
    if (trimmed.isEmpty())
        return QStringLiteral("[]");

    QJsonArray resultsJson;

    for (int pageIndex = 0; pageIndex < m_pageCount; ++pageIndex) {
        fz_page *page = nullptr;
        fz_stext_page *textPage = nullptr;
        fz_buffer *buffer = nullptr;
        fz_output *output = nullptr;
        QJsonArray pageHits;
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
                fz_drop_output(ctx, output);
                fz_drop_buffer(ctx, buffer);
                output = nullptr;
                buffer = nullptr;
            }

            for (int i = 0; i < limit; ++i) {
                QJsonObject item;
                item.insert(QStringLiteral("pageIndex"), pageIndex);
                item.insert(QStringLiteral("pageLabel"), pageIndex + 1);
                item.insert(QStringLiteral("snippet"), snippetForMatch(pageText, trimmed, i));
                item.insert(QStringLiteral("rect"), quadToJson(quads[i]));
                pageHits.append(item);
            }
        }
        fz_catch(ctx)
        {
            pageHits = QJsonArray();
        }

        if (textPage)
            fz_drop_stext_page(ctx, textPage);
        if (page)
            fz_drop_page(ctx, page);
        if (output)
            fz_drop_output(ctx, output);
        if (buffer)
            fz_drop_buffer(ctx, buffer);

        for (const QJsonValue &hit : pageHits)
            resultsJson.append(hit);
    }

    return QString::fromUtf8(QJsonDocument(resultsJson).toJson(QJsonDocument::Compact));
}

QString PdfDocument::extractPageText(int pageIndex)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    QString error;
    const QString extracted = extractPageTextInternal(ctx, doc, pageIndex, &error);
    if (!error.isEmpty())
        return {};
    return extracted;
}

QString PdfDocument::extractDocumentText()
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc || m_pageCount <= 0)
        return {};

    QStringList pages;
    pages.reserve(m_pageCount);
    for (int pageIndex = 0; pageIndex < m_pageCount; ++pageIndex) {
        QString error;
        const QString extracted = extractPageTextInternal(ctx, doc, pageIndex, &error);
        if (!error.isEmpty())
            continue;

        const QString trimmed = extracted.trimmed();
        if (trimmed.isEmpty())
            continue;

        pages.append(QStringLiteral("Page %1\n\n%2").arg(pageIndex + 1).arg(trimmed));
    }

    return pages.join(QStringLiteral("\n\n----------------------------------------\n\n"));
}

int PdfDocument::resolveLinkPage(const QString &uri)
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    const QByteArray utf8 = uri.toUtf8();
    return resolveUriPageNumber(ctx, doc, utf8.constData());
}

void PdfDocument::rebuildNavigationData()
{
    fz_context *ctx = m_engine->context();
    fz_document *doc = m_engine->document();
    if (!ctx || !doc) {
        m_outlineJson = QStringLiteral("[]");
        m_pageLinksJson = QStringLiteral("[]");
        return;
    }

    QStringList pageLinks;
    pageLinks.reserve(m_pageCount);

    fz_outline *outline = nullptr;
    fz_try(ctx)
    {
        outline = fz_load_outline(ctx, doc);
        m_outlineJson = QString::fromUtf8(QJsonDocument(outlineToJson(ctx, doc, outline)).toJson(QJsonDocument::Compact));

        for (int pageIndex = 0; pageIndex < m_pageCount; ++pageIndex) {
            pageLinks.append(pageLinksJsonForPage(ctx, doc, pageIndex));
        }
    }
    fz_always(ctx)
    {
        if (outline)
            fz_drop_outline(ctx, outline);
    }
    fz_catch(ctx)
    {
        m_outlineJson = QStringLiteral("[]");
        pageLinks.clear();
    }

    QJsonArray allLinks;
    for (const QString &pageJson : pageLinks)
        allLinks.append(QJsonDocument::fromJson(pageJson.toUtf8()).array());
    m_pageLinksJson = QString::fromUtf8(QJsonDocument(allLinks).toJson(QJsonDocument::Compact));
}

bool PdfDocument::saveRotatedCopy(const QString &source, const QString &target, const QString &rotationsJson)
{
    const QString sourcePath = toLocalPath(source);
    const QFileInfo sourceInfo(sourcePath);
    m_errorMessage.clear();
    emit errorMessageChanged();

    if (!sourceInfo.exists() || !sourceInfo.isFile() ||
        sourceInfo.suffix().compare(QLatin1String("pdf"), Qt::CaseInsensitive) != 0) {
        m_errorMessage = tr("Select a valid PDF file.");
        emit errorMessageChanged();
        return false;
    }

    const QString sourceCanonical = sourceInfo.canonicalFilePath();
    if (sourceCanonical.isEmpty()) {
        m_errorMessage = tr("The PDF path could not be resolved.");
        emit errorMessageChanged();
        return false;
    }

    const QString targetPath = ensurePdfSuffix(toLocalPath(target));
    if (targetPath.isEmpty()) {
        m_errorMessage = tr("Choose a valid output PDF path.");
        emit errorMessageChanged();
        return false;
    }

    const QFileInfo targetInfo(targetPath);
    const QDir targetDir = targetInfo.absoluteDir();
    if (!targetDir.exists()) {
        m_errorMessage = tr("The output folder does not exist.");
        emit errorMessageChanged();
        return false;
    }

    const QString targetCanonical = targetInfo.exists()
        ? targetInfo.canonicalFilePath()
        : targetDir.canonicalPath() + QLatin1Char('/') + targetInfo.fileName();

    const bool overwriteOriginal =
        QDir::cleanPath(sourceCanonical).compare(QDir::cleanPath(targetCanonical), Qt::CaseInsensitive) == 0;

    const QVector<int> rotations = parseRotations(rotationsJson);
    bool hasRotation = false;
    for (int rotation : rotations) {
        if (rotation != 0) {
            hasRotation = true;
            break;
        }
    }

    if (!hasRotation) {
        m_errorMessage = tr("There are no rotation changes to save.");
        emit errorMessageChanged();
        return false;
    }

    fz_context *ctx = nullptr;
    pdf_document *doc = nullptr;
    QString error;
    const QString savePath = overwriteOriginal ? tempPdfPathFor(sourceCanonical) : targetPath;
    if (savePath.isEmpty()) {
        m_errorMessage = tr("Could not create a temporary PDF path.");
        emit errorMessageChanged();
        return false;
    }

    const QByteArray sourceBytes = sourceCanonical.toUtf8();
    const QByteArray targetBytes = QDir::toNativeSeparators(savePath).toUtf8();
    const QByteArray passwordBytes = m_password.toUtf8();

    ctx = fz_new_context(nullptr, nullptr, FZ_STORE_UNLIMITED);
    if (!ctx) {
        m_errorMessage = tr("MuPDF could not create a saving context.");
        emit errorMessageChanged();
        return false;
    }

    fz_try(ctx)
    {
        fz_register_document_handlers(ctx);
        doc = pdf_open_document(ctx, sourceBytes.constData());

        if (pdf_needs_password(ctx, doc)) {
            if (passwordBytes.isEmpty() || !pdf_authenticate_password(ctx, doc, passwordBytes.constData()))
                fz_throw(ctx, FZ_ERROR_GENERIC, "Incorrect password for password-protected PDF");
        }

        const int pageCount = pdf_count_pages(ctx, doc);
        const int limit = std::min(pageCount, static_cast<int>(rotations.size()));
        for (int page = 0; page < limit; ++page) {
            const int rotation = rotations.at(page);
            if (rotation == 0)
                continue;

            pdf_obj *pageObj = pdf_lookup_page_obj(ctx, doc, page);
            const int existingRotation = pdf_to_int_default(
                ctx,
                pdf_dict_get_inheritable(ctx, pageObj, PDF_NAME(Rotate)),
                0);
            int savedRotation = (existingRotation + rotation) % 360;
            if (savedRotation < 0)
                savedRotation += 360;

            pdf_dict_put_int(ctx, pageObj, PDF_NAME(Rotate), savedRotation);
        }

        pdf_write_options options = pdf_default_write_options;
        options.do_garbage = 1;
        options.do_compress = 1;
        pdf_save_document(ctx, doc, targetBytes.constData(), &options);
    }
    fz_catch(ctx)
    {
        error = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (doc)
        pdf_drop_document(ctx, doc);
    fz_drop_context(ctx);

    if (!error.isEmpty()) {
        if (overwriteOriginal)
            QFile::remove(savePath);
        m_errorMessage = tr("MuPDF failed to save this PDF: %1").arg(error);
        emit errorMessageChanged();
        return false;
    }

    if (overwriteOriginal) {
        if (QDir::cleanPath(m_filePath).compare(QDir::cleanPath(sourceCanonical), Qt::CaseInsensitive) == 0)
            m_engine->close();

        QString replaceError;
        if (!replaceFileWithBackup(sourceCanonical, savePath, &replaceError)) {
            QFile::remove(savePath);
            m_errorMessage = replaceError;
            emit errorMessageChanged();
            return false;
        }
    }

    return true;
}
