#include "PdfDocument.h"

#include <QBuffer>
#include <QByteArray>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QIODevice>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QUrl>
#include <QVector>

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
}

PdfDocument::PdfDocument(QObject *parent)
    : QObject(parent)
{
}

PdfDocument::~PdfDocument()
{
    dropOpenDocument(m_ctx, m_doc);
}

void PdfDocument::clear()
{
    if (m_filePath.isEmpty() && m_previewSource.isEmpty() && m_pageSources.isEmpty() &&
        m_thumbnailSources.isEmpty() && m_pageSizesJson.isEmpty() && m_pageCount == 0 &&
        m_title.isEmpty() && m_errorMessage.isEmpty() && !m_isLoaded && !m_ctx && !m_doc)
        return;

    dropOpenDocument(m_ctx, m_doc);

    m_filePath.clear();
    m_previewSource.clear();
    m_pageSources.clear();
    m_thumbnailSources.clear();
    m_pageSizesJson.clear();
    m_title.clear();
    m_errorMessage.clear();
    m_pageCount = 0;
    m_isLoaded = false;

    emit filePathChanged();
    emit previewSourceChanged();
    emit pageSourcesChanged();
    emit thumbnailSourcesChanged();
    emit pageSizesJsonChanged();
    emit pageCountChanged();
    emit titleChanged();
    emit errorMessageChanged();
    emit isLoadedChanged();
}

bool PdfDocument::load(const QString &source)
{
    const QString localPath = toLocalPath(source);
    const QFileInfo fileInfo(localPath);

    m_previewSource.clear();
    m_pageSources.clear();
    m_thumbnailSources.clear();
    m_pageSizesJson.clear();
    m_errorMessage.clear();
    m_pageCount = 0;
    m_isLoaded = false;
    dropOpenDocument(m_ctx, m_doc);
    emit previewSourceChanged();
    emit pageSourcesChanged();
    emit thumbnailSourcesChanged();
    emit pageSizesJsonChanged();
    emit errorMessageChanged();
    emit pageCountChanged();
    emit isLoadedChanged();

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
    m_title = QFileInfo(canonical).fileName();
    emit filePathChanged();
    emit titleChanged();

    QString error;
    const QByteArray pathBytes = canonical.toUtf8();

    m_ctx = fz_new_context(nullptr, nullptr, FZ_STORE_UNLIMITED);
    if (!m_ctx) {
        m_errorMessage = tr("MuPDF could not create a rendering context.");
        emit errorMessageChanged();
        emit loadFailed(m_errorMessage);
        return false;
    }

    fz_try(m_ctx)
    {
        fz_register_document_handlers(m_ctx);
        m_doc = fz_open_document(m_ctx, pathBytes.constData());

        if (fz_needs_password(m_ctx, m_doc))
            fz_throw(m_ctx, FZ_ERROR_GENERIC, "password-protected PDFs are not enabled in this reset build");

        m_pageCount = fz_count_pages(m_ctx, m_doc);
        if (m_pageCount <= 0)
            fz_throw(m_ctx, FZ_ERROR_GENERIC, "PDF has no pages");

        QJsonArray pageSizes;
        m_pageSources = QStringList();
        m_thumbnailSources = QStringList();
        m_pageSources.reserve(m_pageCount);
        m_thumbnailSources.reserve(m_pageCount);
        for (int page = 0; page < m_pageCount; ++page) {
            fz_page *loadedPage = fz_load_page(m_ctx, m_doc, page);
            const fz_rect bounds = fz_bound_page(m_ctx, loadedPage);
            fz_drop_page(m_ctx, loadedPage);

            QJsonObject size;
            size.insert(QStringLiteral("width"), bounds.x1 - bounds.x0);
            size.insert(QStringLiteral("height"), bounds.y1 - bounds.y0);
            pageSizes.append(size);

            m_pageSources.append(QString());
            m_thumbnailSources.append(QString());
        }

        m_pageSizesJson = QString::fromUtf8(QJsonDocument(pageSizes).toJson(QJsonDocument::Compact));

        m_previewSource = renderPageToDataUrl(m_ctx, m_doc, 0, kRenderScale, &error);
        if (!error.isEmpty() || m_previewSource.isEmpty())
            fz_throw(m_ctx, FZ_ERROR_GENERIC, "first page could not be rendered");

        m_pageSources[0] = m_previewSource;
        m_thumbnailSources[0] = renderPageToDataUrl(m_ctx, m_doc, 0, kThumbnailScale, nullptr);
        m_isLoaded = true;
    }
    fz_catch(m_ctx)
    {
        error = QString::fromUtf8(fz_caught_message(m_ctx));
    }

    if (!error.isEmpty()) {
        dropOpenDocument(m_ctx, m_doc);
        m_previewSource.clear();
        m_pageSources.clear();
        m_thumbnailSources.clear();
        m_pageSizesJson.clear();
        m_pageCount = 0;
        m_isLoaded = false;
        m_errorMessage = tr("MuPDF failed to open this PDF: %1").arg(error);
        emit previewSourceChanged();
        emit pageSourcesChanged();
        emit thumbnailSourcesChanged();
        emit pageSizesJsonChanged();
        emit pageCountChanged();
        emit errorMessageChanged();
        emit isLoadedChanged();
        emit loadFailed(m_errorMessage);
        return false;
    }

    emit previewSourceChanged();
    emit pageSourcesChanged();
    emit thumbnailSourcesChanged();
    emit pageSizesJsonChanged();
    emit pageCountChanged();
    emit isLoadedChanged();
    emit loaded();
    return true;
}

QString PdfDocument::renderPage(int pageIndex, qreal scale)
{
    if (!m_ctx || !m_doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return {};

    const float safeScale = std::clamp(static_cast<float>(scale), 0.25f, kRenderScale);
    QString error;
    const QString source = renderPageToDataUrl(m_ctx, m_doc, pageIndex, safeScale, &error);
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
    if (!m_ctx || !m_doc || pageIndex < 0 || pageIndex >= m_pageCount)
        return {};

    QString error;
    const QString source = renderPageToDataUrl(m_ctx, m_doc, pageIndex, kThumbnailScale, &error);
    if (source.isEmpty())
        return {};

    if (pageIndex >= 0 && pageIndex < m_thumbnailSources.size()) {
        m_thumbnailSources[pageIndex] = source;
        emit thumbnailSourcesChanged();
    }

    return source;
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

        if (pdf_needs_password(ctx, doc))
            fz_throw(ctx, FZ_ERROR_GENERIC, "password-protected PDFs are not enabled in this reset build");

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
            dropOpenDocument(m_ctx, m_doc);

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
