#include "PdfSaveCoordinator.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QUrl>

#include <mupdf/fitz.h>

namespace PDFClowne::Editing {
namespace {

QString toLocalPath(const QString &source)
{
    if (source.startsWith(QLatin1String("file://"), Qt::CaseInsensitive))
        return QUrl(source).toLocalFile();
    return source;
}

QString ensurePdfSuffix(const QString &path)
{
    const QFileInfo info(path);
    if (info.suffix().compare(QLatin1String("pdf"), Qt::CaseInsensitive) == 0)
        return path;
    return path + QStringLiteral(".pdf");
}

bool saveTraceEnabled()
{
    static const bool enabled = qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_SAVE")
        || qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_EDIT_INPUT");
    return enabled;
}

} // namespace

QString PdfSaveCoordinator::tempPdfPathFor(const QString &targetPath)
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

bool PdfSaveCoordinator::canOpenAsPdf(const QString &path, QString *error)
{
    const QString localPath = toLocalPath(path);
    if (!QFileInfo::exists(localPath)) {
        if (error)
            *error = QStringLiteral("Temporary PDF was not written.");
        return false;
    }

    fz_context *ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) {
        if (error)
            *error = QStringLiteral("MuPDF could not create a validation context.");
        return false;
    }

    fz_document *doc = nullptr;
    QString caught;
    const QByteArray pathBytes = localPath.toUtf8();
    fz_try(ctx)
    {
        fz_register_document_handlers(ctx);
        doc = fz_open_document(ctx, pathBytes.constData());
        if (fz_count_pages(ctx, doc) <= 0)
            fz_throw(ctx, FZ_ERROR_GENERIC, "PDF contains no pages.");
    }
    fz_catch(ctx)
    {
        caught = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (doc)
        fz_drop_document(ctx, doc);
    fz_drop_context(ctx);

    if (!caught.isEmpty()) {
        if (error)
            *error = caught;
        return false;
    }

    return true;
}

bool PdfSaveCoordinator::replaceFileWithBackup(const QString &sourcePath,
                                               const QString &replacementPath,
                                               QString *backupPath,
                                               QString *error)
{
    const QFileInfo sourceInfo(sourcePath);
    const QString backup = sourceInfo.absoluteDir().absoluteFilePath(
        sourceInfo.fileName() + QStringLiteral(".pdfclowne-backup"));

    QFile::remove(backup);
    if (!QFile::rename(sourcePath, backup)) {
        if (error)
            *error = QStringLiteral("Could not prepare original PDF backup.");
        return false;
    }

    if (!QFile::rename(replacementPath, sourcePath)) {
        QFile::rename(backup, sourcePath);
        if (error)
            *error = QStringLiteral("Could not replace original PDF.");
        return false;
    }

    if (backupPath)
        *backupPath = backup;
    QFile::remove(backup);
    return true;
}

PdfSaveCoordinator::SaveResult PdfSaveCoordinator::saveAsCopy(const QString &targetPath,
                                                              const WriteCallback &writer) const
{
    SaveResult result;
    result.finalPath = ensurePdfSuffix(toLocalPath(targetPath));
    if (result.finalPath.isEmpty() || !writer) {
        result.error = QStringLiteral("Invalid save-as-copy request.");
        return result;
    }

    const QString tempPath = tempPdfPathFor(result.finalPath);
    if (tempPath.isEmpty()) {
        result.error = QStringLiteral("Could not create temporary PDF path.");
        return result;
    }

    if (!writer(tempPath, &result.error)) {
        QFile::remove(tempPath);
        return result;
    }
    if (saveTraceEnabled())
        qInfo().noquote() << QStringLiteral("[PDF_SAVE_EXPORT] tempPath=\"%1\" editsWritten=true overwriteCurrent=false").arg(tempPath);

    if (!canOpenAsPdf(tempPath, &result.error)) {
        QFile::remove(tempPath);
        return result;
    }

    QFile::remove(result.finalPath);
    if (!QFile::rename(tempPath, result.finalPath)) {
        QFile::remove(tempPath);
        result.error = QStringLiteral("Could not move validated PDF copy into place.");
        return result;
    }

    result.ok = true;
    if (saveTraceEnabled())
        qInfo().noquote() << QStringLiteral("[PDF_SAVE_DONE] ok=true currentFilePath=\"%1\" documentDirty=false").arg(result.finalPath);
    return result;
}

PdfSaveCoordinator::SaveResult PdfSaveCoordinator::replaceOriginalTransaction(
    const QString &originalPath,
    const WriteCallback &writer,
    bool keepUserBackup) const
{
    SaveResult result;
    result.finalPath = toLocalPath(originalPath);
    if (result.finalPath.isEmpty() || !writer) {
        result.error = QStringLiteral("Invalid original replacement request.");
        return result;
    }

    const QString tempPath = tempPdfPathFor(result.finalPath);
    if (tempPath.isEmpty()) {
        result.error = QStringLiteral("Could not create temporary PDF path.");
        return result;
    }

    if (!writer(tempPath, &result.error)) {
        QFile::remove(tempPath);
        return result;
    }
    if (saveTraceEnabled())
        qInfo().noquote() << QStringLiteral("[PDF_SAVE_EXPORT] tempPath=\"%1\" editsWritten=true overwriteCurrent=true").arg(tempPath);

    if (!canOpenAsPdf(tempPath, &result.error)) {
        QFile::remove(tempPath);
        return result;
    }

    if (keepUserBackup) {
        const QFileInfo sourceInfo(result.finalPath);
        const QString userBackup = sourceInfo.absoluteDir().absoluteFilePath(
            sourceInfo.completeBaseName() + QStringLiteral(".pdfclowne-user-backup.pdf"));
        QFile::remove(userBackup);
        QFile::copy(result.finalPath, userBackup);
    }

    if (!replaceFileWithBackup(result.finalPath, tempPath, &result.backupPath, &result.error)) {
        QFile::remove(tempPath);
        if (saveTraceEnabled())
            qWarning().noquote() << QStringLiteral("[PDF_SAVE_ERROR] message=\"%1\"").arg(result.error);
        return result;
    }

    result.ok = true;
    if (saveTraceEnabled())
        qInfo().noquote() << QStringLiteral("[PDF_SAVE_REPLACE] tempCreated=true backupCreated=true replaced=true reloaded=pending");
    return result;
}

} // namespace PDFClowne::Editing
