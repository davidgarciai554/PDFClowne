#include "PdfEditSessionController.h"

#include "../pdf/PdfContentWriter.h"
#include "../pdf/PdfFontResourceWriter.h"
#include "../pdf/PdfSaveCoordinator.h"
#include "PdfEditTextLayout.h"

#include <QBuffer>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QJsonDocument>
#include <QHash>
#include <QPainter>
#include <QDebug>
#include <QElapsedTimer>
#include <QUrl>

#include <mupdf/fitz.h>
#include <mupdf/pdf.h>

#include <algorithm>
#include <cmath>
#include <limits>

namespace PDFClowne::Editing {
namespace {

bool editTraceEnabled()
{
    static const bool enabled = qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_EDIT_INPUT");
    return enabled;
}

bool editMetricsTraceEnabled()
{
    static const bool enabled = qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_EDIT_METRICS");
    return enabled;
}

void editTrace(const char *prefix, const QString &message)
{
    if (editTraceEnabled())
        qInfo().noquote() << prefix << message;
}

QString normalizedReason(const QString &reason)
{
    return reason.isEmpty() ? QStringLiteral("Explicit") : reason;
}

QString jsonArrayToCompactString(const QJsonArray &array)
{
    return QString::fromUtf8(QJsonDocument(array).toJson(QJsonDocument::Compact));
}

QJsonArray pointToJson(const QPointF &point)
{
    return QJsonArray{point.x(), point.y()};
}

QJsonArray quadToJson(const QPolygonF &quad)
{
    QJsonArray array;
    for (const QPointF &point : quad)
        array.append(pointToJson(point));
    return array;
}

QString toLocalPath(const QString &source)
{
    if (source.startsWith(QLatin1String("file://"), Qt::CaseInsensitive))
        return QUrl(source).toLocalFile();
    return source;
}

fz_quad toFzQuad(const QPolygonF &quad)
{
    fz_quad value;
    const QPointF ul = quad.value(0);
    const QPointF ur = quad.value(1);
    const QPointF lr = quad.value(2);
    const QPointF ll = quad.value(3);
    value.ul = fz_make_point(static_cast<float>(ul.x()), static_cast<float>(ul.y()));
    value.ur = fz_make_point(static_cast<float>(ur.x()), static_cast<float>(ur.y()));
    value.lr = fz_make_point(static_cast<float>(lr.x()), static_cast<float>(lr.y()));
    value.ll = fz_make_point(static_cast<float>(ll.x()), static_cast<float>(ll.y()));
    return value;
}

QPolygonF quadFromRect(const QRectF &rect)
{
    const QRectF r = rect.normalized();
    QPolygonF quad;
    quad << r.topLeft()
         << r.topRight()
         << r.bottomRight()
         << r.bottomLeft();
    return quad;
}

QRectF tightGlyphRedactionRect(const QRectF &bbox)
{
    QRectF r = bbox.normalized();

    const qreal insetY = std::max<qreal>(0.25, r.height() * 0.08);
    const qreal insetX = std::max<qreal>(0.10, r.width() * 0.02);

    return r.adjusted(-insetX, insetY, insetX, -insetY);
}

void applyTextRedaction(fz_context *ctx,
                        pdf_page *page,
                        const fz_quad &quad,
                        pdf_redact_options *options)
{
    pdf_annot *annot = pdf_create_annot(ctx, page, PDF_ANNOT_REDACT);
    pdf_set_annot_rect(ctx, annot, fz_rect_from_quad(quad));
    pdf_set_annot_quad_points(ctx, annot, 1, &quad);
    pdf_set_annot_flags(ctx, annot, PDF_ANNOT_IS_PRINT);
    pdf_obj *borderStyle = pdf_dict_put_dict(ctx, pdf_annot_obj(ctx, annot), PDF_NAME(BS), 2);
    pdf_dict_put_name(ctx, borderStyle, PDF_NAME(S), "S");
    pdf_dict_put_real(ctx, borderStyle, PDF_NAME(W), 0);

    pdf_apply_redaction(ctx, annot, options);
    pdf_drop_annot(ctx, annot);
}

void appendContentStream(fz_context *ctx,
                         pdf_document *doc,
                         pdf_page *page,
                         const QByteArray &contentStream)
{
    fz_buffer *buffer = fz_new_buffer_from_copied_data(
        ctx,
        reinterpret_cast<const unsigned char *>(contentStream.constData()),
        static_cast<size_t>(contentStream.size()));
    pdf_obj *newStream = nullptr;
    fz_try(ctx)
    {
        newStream = pdf_add_stream(ctx, doc, buffer, nullptr, 1);
        pdf_obj *contents = pdf_page_contents(ctx, page);
        if (!contents) {
            pdf_dict_put_drop(ctx, page->obj, PDF_NAME(Contents), newStream);
            newStream = nullptr;
        } else if (pdf_is_array(ctx, contents)) {
            pdf_array_push_drop(ctx, contents, newStream);
            newStream = nullptr;
        } else {
            pdf_obj *array = pdf_new_array(ctx, doc, 2);
            pdf_array_push(ctx, array, contents);
            pdf_array_push_drop(ctx, array, newStream);
            newStream = nullptr;
            pdf_dict_put_drop(ctx, page->obj, PDF_NAME(Contents), array);
        }
    }
    fz_always(ctx)
    {
        fz_drop_buffer(ctx, buffer);
    }
    fz_catch(ctx)
    {
        fz_rethrow(ctx);
    }
}

} // namespace

PdfEditSessionController::PdfEditSessionController(QObject *parent)
    : QObject(parent)
{
    m_editLayerRenderTimer.setSingleShot(true);
    m_editLayerRenderTimer.setInterval(12);
    connect(&m_editLayerRenderTimer, &QTimer::timeout, this, [this]() {
        m_editLayerRenderPending = false;
        regenerateEditLayer();
    });
}

bool PdfEditSessionController::loadDocument(const QString &filePath)
{
    return loadDocumentWithPassword(filePath, QString());
}

QString PdfEditSessionController::selectedBlockId() const
{
    if (m_activeRegionIndex < 0)
        return {};
    return QStringLiteral("glyph-region-%1-%2").arg(m_currentPageIndex).arg(m_activeRegionIndex);
}

QImage PdfEditSessionController::editLayerImage()
{
    if (m_editLayerRenderPending) {
        m_editLayerRenderTimer.stop();
        m_editLayerRenderPending = false;
        regenerateEditLayer();
    }
    return m_editLayerImage;
}

QString PdfEditSessionController::lastResolvedEditFontDebug()
{
    if (m_editLayerRenderPending) {
        m_editLayerRenderTimer.stop();
        m_editLayerRenderPending = false;
        regenerateEditLayer();
    }
    return m_lastResolvedEditFontDebug;
}

bool PdfEditSessionController::loadDocumentWithPassword(const QString &filePath, const QString &password)
{
    if (m_filePath == filePath && m_password == password && m_ready)
        return true;

    clearSession();
    m_filePath = filePath;
    m_password = password;
    if (!m_textEdits.isEmpty() || m_hasPendingEdits) {
        m_textEdits.clear();
        m_hasPendingEdits = false;
        emit pendingEditsChanged();
    }
    m_editLayerImage = {};
    m_lastResolvedEditFontDebug.clear();
    m_redactedBaseCacheImage = {};
    m_redactedBaseCacheKey.clear();
    emit editLayerImageChanged();
    m_currentPageIndex = -1;
    m_pageText = {};
    m_runsJson = QStringLiteral("[]");
    m_regionsJson = QStringLiteral("[]");
    setReady(!m_filePath.isEmpty());
    emit documentChanged();
    emit pageChanged();
    return m_ready;
}

bool PdfEditSessionController::extractPage(int pageIndex)
{
    if (!m_ready || pageIndex < 0)
        return false;

    if (m_currentPageIndex != pageIndex)
        clearSession();

    setBusy(true);
    setStatusMessage(tr("Extrayendo glifos PDF"));
    m_pageText = m_extractor.extractPage(m_filePath, m_password, pageIndex);
    setBusy(false);

    if (!m_pageText.error.isEmpty()) {
        setStatusMessage(m_pageText.error);
        m_currentPageIndex = -1;
        m_runsJson = QStringLiteral("[]");
        m_regionsJson = QStringLiteral("[]");
        emit pageChanged();
        return false;
    }

    m_currentPageIndex = pageIndex;
    rebuildPageJson();
    setStatusMessage(QString());
    if (hasConfirmedEdits(pageIndex) && !m_pixelSize.isEmpty())
        regenerateEditLayer();
    else if (!m_active)
        clearEditLayerIfNoVisibleEdits(QStringLiteral("extractPage"));
    return true;
}

void PdfEditSessionController::extractBlocksForPage(int pageIndex)
{
    extractPage(pageIndex);
}

void PdfEditSessionController::selectBlock(const QString &blockId)
{
    if (!blockId.isEmpty())
        return;

    const int confirmedBefore = confirmedEditCount();
    const int pendingBefore = m_textEdits.size();
    editTrace("[PDF_EDIT_CLEAR]",
              QStringLiteral("methodName=selectBlockEmpty before active=%1 confirmedCountBefore=%2 pendingCountBefore=%3")
                  .arg(m_active)
                  .arg(confirmedBefore)
                  .arg(pendingBefore));

    if (m_active)
        commitActiveText(QStringLiteral("SelectionCleared"));
    else
        clearActiveTransientState(true);

    if (hasConfirmedEdits(m_currentPageIndex) && !m_pixelSize.isEmpty())
        regenerateEditLayer();
    else
        clearEditLayerIfNoVisibleEdits(QStringLiteral("selectBlockEmpty"));

    editTrace("[PDF_EDIT_CLEAR]",
              QStringLiteral("methodName=selectBlockEmpty after active=%1 confirmedCountAfter=%2 pendingCountAfter=%3 imageNull=%4")
                  .arg(m_active)
                  .arg(confirmedEditCount())
                  .arg(m_textEdits.size())
                  .arg(m_editLayerImage.isNull()));
}

void PdfEditSessionController::closeDocument()
{
    clearSession();
    if (!m_textEdits.isEmpty() || m_hasPendingEdits) {
        m_textEdits.clear();
        m_hasPendingEdits = false;
        emit pendingEditsChanged();
    }
    m_editLayerImage = {};
    m_lastResolvedEditFontDebug.clear();
    m_resolvedFontCache.clear();
    m_redactedBaseCacheImage = {};
    m_redactedBaseCacheKey.clear();
    emit editLayerImageChanged();
    m_filePath.clear();
    m_password.clear();
    m_currentPageIndex = -1;
    m_pageText = {};
    m_runsJson = QStringLiteral("[]");
    m_regionsJson = QStringLiteral("[]");
    setReady(false);
    emit documentChanged();
    emit pageChanged();
}

bool PdfEditSessionController::beginSession(int pageIndex,
                                            qreal pageX,
                                            qreal pageY,
                                            int pixelWidth,
                                            int pixelHeight,
                                            qreal scale)
{
    editTrace("[PDF_EDIT_BEGIN]",
              QStringLiteral("request page=%1 x=%2 y=%3 pixels=%4x%5 scale=%6 ready=%7 currentPage=%8")
                  .arg(pageIndex)
                  .arg(pageX)
                  .arg(pageY)
                  .arg(pixelWidth)
                  .arg(pixelHeight)
                  .arg(scale)
                  .arg(m_ready)
                  .arg(m_currentPageIndex));

    if (!ensurePage(pageIndex))
        return false;

    m_pixelSize = QSize(std::max(1, pixelWidth), std::max(1, pixelHeight));
    m_scale = std::max<qreal>(0.01, scale);
    selectRegionAt(QPointF(pageX, pageY));
    editTrace("[PDF_EDIT_BEGIN]",
              QStringLiteral("result active=%1 region=%2 textLength=%3 regions=%4")
                  .arg(m_active)
                  .arg(m_activeRegionIndex)
                  .arg(m_activeText.size())
                  .arg(m_pageText.regions.size()));
    return m_active;
}

void PdfEditSessionController::clearSession()
{
    const int confirmedBefore = confirmedEditCount();
    const int pendingBefore = m_textEdits.size();
    editTrace("[PDF_EDIT_CLEAR]",
              QStringLiteral("methodName=clearSession before active=%1 confirmedCountBefore=%2 pendingCountBefore=%3 imageNull=%4")
                  .arg(m_active)
                  .arg(confirmedBefore)
                  .arg(pendingBefore)
                  .arg(m_editLayerImage.isNull()));

    const bool wasActive = m_active;
    m_active = false;
    m_activeRegionIndex = -1;
    m_activeText.clear();
    m_originalActiveText.clear();
    m_selectionQuadsJson = QStringLiteral("[]");
    const bool cursorChangedNow = m_cursorPosition != 0;
    const bool inputStateChangedNow = m_replaceSelectionOnInput || m_selectionStart != 0 || m_selectionLength != 0;
    m_cursorPosition = 0;
    m_replaceSelectionOnInput = false;
    m_selectionStart = 0;
    m_selectionLength = 0;
    rebuildActiveLayout();
    if (wasActive)
        emit activeChanged();
    emit activeTextChanged();
    if (cursorChangedNow)
        emit cursorChanged();
    if (inputStateChangedNow)
        emit inputStateChanged();

    if (hasConfirmedEdits(m_currentPageIndex) && !m_pixelSize.isEmpty())
        scheduleRegenerateEditLayer(QStringLiteral("clearSession"));
    else
        clearEditLayerIfNoVisibleEdits(QStringLiteral("clearSession"));

    editTrace("[PDF_EDIT_CLEAR]",
              QStringLiteral("methodName=clearSession after confirmedCountAfter=%1 pendingCountAfter=%2 imageNull=%3")
                  .arg(confirmedEditCount())
                  .arg(m_textEdits.size())
                  .arg(m_editLayerImage.isNull()));
}

void PdfEditSessionController::updateActiveText(const QString &text)
{
    if (!m_active || m_activeText == text)
        return;

    editTrace("[PDF_EDIT_KEY]",
              QStringLiteral("updateActiveText page=%1 region=%2 oldLength=%3 newLength=%4")
                  .arg(m_currentPageIndex)
                  .arg(m_activeRegionIndex)
                  .arg(m_activeText.size())
                  .arg(text.size()));
    m_activeText = text;
    emit activeTextChanged();
    rebuildActiveLayout();
    scheduleRegenerateEditLayer(QStringLiteral("updateActiveText"));
}

void PdfEditSessionController::updateActiveStyle(const QString &styleJson)
{
    if (!m_active)
        return;

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(styleJson.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject())
        return;

    const QVector<PdfRun> runs = activeReplacementRuns();
    if (runs.isEmpty())
        return;

    QJsonObject obj = doc.object();
    PdfDetectedTextStyle style = m_activeLayout.valid
        ? m_activeLayout.style
        : PdfEditTextLayout::detectedStyleFromRun(runs.constFirst());

    if (obj.contains(QStringLiteral("fontSize")))
        style.effectiveFontSize = std::max<qreal>(1.0, obj.value(QStringLiteral("fontSize")).toDouble(style.effectiveFontSize));

    if (obj.contains(QStringLiteral("color"))) {
        QColor color(obj.value(QStringLiteral("color")).toString());
        if (color.isValid())
            style.fillColor = color;
    }

    if (obj.contains(QStringLiteral("bold")))
        style.bold = obj.value(QStringLiteral("bold")).toBool(style.bold);
    if (obj.contains(QStringLiteral("italic")))
        style.italic = obj.value(QStringLiteral("italic")).toBool(style.italic);
    if (obj.contains(QStringLiteral("underline")))
        style.underline = obj.value(QStringLiteral("underline")).toBool(style.underline);
    if (obj.contains(QStringLiteral("strikeout")))
        style.strikeout = obj.value(QStringLiteral("strikeout")).toBool(style.strikeout);

    const PdfRun &run = runs.constFirst();
    m_activeLayout = layoutForReplacementRun(run, m_activeText, style);

    rebuildActiveEditGeometryFromLayout();
    rebuildActiveStyleJsonFromLayout();
    scheduleRegenerateEditLayer(QStringLiteral("updateActiveStyle"));
}

bool PdfEditSessionController::commitActiveText(const QString &reason)
{
    const QString finishReason = normalizedReason(reason);
    editTrace("[PDF_EDIT_COMMIT_REQUEST]",
              QStringLiteral("reason=%1 editingActive=%2 activeEditId=%3 currentText=\"%4\" currentText.length=%5 confirmedCountBefore=%6 pendingCountBefore=%7")
                  .arg(finishReason)
                  .arg(m_active)
                  .arg(selectedBlockId())
                  .arg(m_activeText.left(80))
                  .arg(m_activeText.size())
                  .arg(confirmedEditCount())
                  .arg(m_textEdits.size()));

    if (!m_active || m_activeRegionIndex < 0)
        return false;

    const int pageIndex = m_currentPageIndex;
    const int regionIndex = m_activeRegionIndex;
    const QString editId = selectedBlockId();
    const QString originalText = m_originalActiveText;
    const QString confirmedText = m_activeText;
    const bool dirtyBefore = m_hasPendingEdits;
    const bool changed = confirmedText != originalText;

    editTrace("[PDF_EDIT_COMMIT]",
              QStringLiteral("begin reason=%1 active=%2 page=%3 region=%4 originalLength=%5 currentLength=%6 confirmedLength=%7 dirtyBefore=%8 editsBefore=%9")
                  .arg(finishReason)
                  .arg(m_active)
                  .arg(pageIndex)
                  .arg(regionIndex)
                  .arg(originalText.size())
                  .arg(m_activeText.size())
                  .arg(confirmedText.size())
                  .arg(dirtyBefore)
                  .arg(m_textEdits.size()));

    auto existing = std::find_if(
        m_textEdits.begin(),
        m_textEdits.end(),
        [&](const PdfTextEditOperation &candidate) {
            return candidate.pageIndex == pageIndex
                && candidate.regionIndex == regionIndex;
        });

    if (changed) {
        PdfTextEditOperation operation = activeOperationSnapshot();
        operation.originalText = originalText;
        operation.replacementText = confirmedText;
        operation.committed = true;

        if (existing == m_textEdits.end())
            m_textEdits.append(operation);
        else
            *existing = operation;
    } else if (existing != m_textEdits.end()) {
        m_textEdits.erase(existing);
    }

    m_hasPendingEdits = !m_textEdits.isEmpty();
    emit pendingEditsChanged();
    clearActiveTransientState(true);
    regenerateEditLayer();
    emit editCommitted(pageIndex, editId);
    editTrace("[PDF_EDIT_COMMIT_DONE]",
              QStringLiteral("reason=%1 page=%2 region=%3 committedText=\"%4\" changed=%5 confirmedCountAfter=%6 pendingCountAfter=%7 hasPendingEdits=%8 editLayerImageNull=%9")
                  .arg(finishReason)
                  .arg(pageIndex)
                  .arg(regionIndex)
                  .arg(confirmedText.left(80))
                  .arg(changed)
                  .arg(confirmedEditCount())
                  .arg(m_textEdits.size())
                  .arg(m_hasPendingEdits)
                  .arg(m_editLayerImage.isNull()));
    return true;
}

void PdfEditSessionController::commitActiveEdit()
{
    if (m_active)
        commitActiveText(QStringLiteral("SaveRequested"));
}

bool PdfEditSessionController::saveCurrentDocument()
{
    const QString localSource = toLocalPath(m_filePath);
    qInfo().noquote() << QStringLiteral("[Save] saveCurrentDocument path=\"%1\" hasPendingTextEdits=%2")
                             .arg(localSource)
                             .arg(m_hasPendingEdits);

    if (localSource.isEmpty()) {
        emit saveError(tr("No hay PDF abierto para guardar."));
        return false;
    }

    return saveDocumentToPath(localSource, true);
}

bool PdfEditSessionController::saveDocumentAs(const QUrl &outputUrl)
{
    const QString outputPath = outputUrl.isLocalFile()
        ? outputUrl.toLocalFile()
        : toLocalPath(outputUrl.toString(QUrl::PreferLocalFile | QUrl::FullyDecoded));

    if (outputPath.isEmpty()) {
        emit saveError(tr("Ruta de salida vacía."));
        return false;
    }

    return saveDocumentToPath(outputPath, false);
}

bool PdfEditSessionController::saveDocument(const QString &outputPath, bool incremental)
{
    return saveDocumentToPath(outputPath, incremental);
}

bool PdfEditSessionController::saveDocumentToPath(const QString &outputPath, bool overwriteOriginal)
{
    const QString localOutput = toLocalPath(outputPath);
    const QString localSource = toLocalPath(m_filePath);
    editTrace("[PDF_SAVE_REQUEST]",
              QStringLiteral("mode=%1 currentFilePath=\"%2\" targetPath=\"%3\" editingActive=%4 confirmedTextEditsCount=%5 documentDirty=%6")
                  .arg(overwriteOriginal ? QStringLiteral("Save") : QStringLiteral("SaveAs"))
                  .arg(localSource)
                  .arg(localOutput)
                  .arg(m_active)
                  .arg(confirmedEditCount())
                  .arg(m_hasPendingEdits));

    const bool wasActive = m_active;
    commitActiveEdit();
    if (wasActive)
        editTrace("[PDF_SAVE_COMMIT_ACTIVE]",
                  QStringLiteral("committed=true confirmedTextEditsCountAfter=%1")
                      .arg(confirmedEditCount()));

    if (m_textEdits.isEmpty()) {
        emit saveCompleted(overwriteOriginal ? localSource : localOutput);
        editTrace("[PDF_SAVE_DONE]", QStringLiteral("ok=true noPendingTextEdits=true"));
        return true;
    }

    PdfSaveCoordinator coordinator;
    const bool replaceOriginal = overwriteOriginal
        || QFileInfo(localOutput).canonicalFilePath() == QFileInfo(localSource).canonicalFilePath();
    const QString finalTarget = replaceOriginal ? localSource : localOutput;
    const auto writer = [this, finalTarget, replaceOriginal](const QString &tempPath, QString *error) {
        qInfo().noquote() << QStringLiteral("[Save] pdf_save_document tempPath=\"%1\" targetPath=\"%2\" overwriteOriginal=%3")
                                 .arg(tempPath)
                                 .arg(finalTarget)
                                 .arg(replaceOriginal);
        return writeEditedPdfCopy(tempPath, error);
    };

    editTrace("[PDF_SAVE_EXPORT]",
              QStringLiteral("sourcePath=\"%1\" targetPath=\"%2\" overwriteCurrent=%3 editsCount=%4")
                  .arg(localSource)
                  .arg(localOutput)
                  .arg(replaceOriginal)
                  .arg(m_textEdits.size()));

    const PdfSaveCoordinator::SaveResult result = replaceOriginal
        ? coordinator.replaceOriginalTransaction(localSource, writer, true)
        : coordinator.saveAsCopy(localOutput, writer);

    if (!result.ok) {
        emit saveError(result.error);
        editTrace("[PDF_SAVE_ERROR]", QStringLiteral("message=\"%1\"").arg(result.error));
        return false;
    }

    clearDirtyFlagsAfterSave();
    emit saveCompleted(result.finalPath);
    editTrace("[PDF_SAVE_DONE]",
              QStringLiteral("ok=true currentFilePath=\"%1\" documentDirty=%2")
                  .arg(result.finalPath)
                  .arg(m_hasPendingEdits));
    return true;
}

void PdfEditSessionController::clearDirtyFlagsAfterSave()
{
    m_textEdits.clear();
    m_hasPendingEdits = false;
    emit pendingEditsChanged();
}

void PdfEditSessionController::updatePageViewMetrics(int pageIndex, int pixelWidth, int pixelHeight, qreal scale)
{
    if (pageIndex < 0)
        return;

    const QSize nextPixelSize(std::max(1, pixelWidth), std::max(1, pixelHeight));
    const qreal nextScale = std::max<qreal>(0.01, scale);
    if (m_currentPageIndex == pageIndex && m_pixelSize == nextPixelSize && qFuzzyCompare(m_scale, nextScale)) {
        if (m_editLayerImage.isNull() && hasConfirmedEdits(pageIndex))
            regenerateEditLayer();
        return;
    }

    if (!ensurePage(pageIndex))
        return;

    m_pixelSize = nextPixelSize;
    m_scale = nextScale;
    m_redactedBaseCacheImage = {};
    m_redactedBaseCacheKey.clear();
    if (m_active || hasConfirmedEdits(pageIndex))
        regenerateEditLayer();
}

bool PdfEditSessionController::hasConfirmedEdits(int pageIndex) const
{
    return confirmedEditCount(pageIndex) > 0;
}

int PdfEditSessionController::confirmedEditCount(int pageIndex) const
{
    return static_cast<int>(std::count_if(
        m_textEdits.cbegin(),
        m_textEdits.cend(),
        [pageIndex](const PdfTextEditOperation &edit) {
            return edit.committed && (pageIndex < 0 || edit.pageIndex == pageIndex);
        }));
}

void PdfEditSessionController::clearEditLayerIfNoVisibleEdits(const QString &reason)
{
    const int confirmed = confirmedEditCount(m_currentPageIndex);
    if (m_active || confirmed > 0)
        return;

    const bool hadImage = !m_editLayerImage.isNull();
    m_editLayerImage = {};
    if (hadImage)
        emit editLayerImageChanged();
    editTrace("[PDF_EDIT_CLEAR]",
              QStringLiteral("methodName=clearEditLayerIfNoVisibleEdits reason=%1 confirmedCount=%2 pendingCount=%3 imageWasNull=%4")
                  .arg(reason)
                  .arg(confirmed)
                  .arg(m_textEdits.size())
                  .arg(!hadImage));
}

void PdfEditSessionController::handleKeyText(const QString &text)
{
    if (!m_active || text.isEmpty())
        return;

    editTrace("[PDF_EDIT_KEY]",
              QStringLiteral("textInput length=%1 cursor=%2 replaceSelection=%3 selectionLength=%4")
                  .arg(text.size())
                  .arg(m_cursorPosition)
                  .arg(m_replaceSelectionOnInput)
                  .arg(m_selectionLength));

    if (m_replaceSelectionOnInput || m_selectionLength > 0) {
        replaceSelectionWithText(text);
        return;
    }

    QString next = m_activeText;
    const int nextSize = static_cast<int>(next.size());
    const int safeCursor = std::max(0, std::min(m_cursorPosition, nextSize));

    next.insert(safeCursor, text);
    m_cursorPosition = safeCursor + static_cast<int>(text.size());
    emit cursorChanged();
    updateActiveText(next);
}

void PdfEditSessionController::handleBackspace()
{
    if (!m_active)
        return;

    editTrace("[PDF_EDIT_KEY]",
              QStringLiteral("backspace cursor=%1 replaceSelection=%2 selectionLength=%3")
                  .arg(m_cursorPosition)
                  .arg(m_replaceSelectionOnInput)
                  .arg(m_selectionLength));

    if (m_replaceSelectionOnInput || m_selectionLength > 0) {
        replaceSelectionWithText(QString());
        return;
    }

    if (m_cursorPosition <= 0)
        return;

    QString next = m_activeText;
    const int nextSize = static_cast<int>(next.size());
    const int safeCursor = std::max(0, std::min(m_cursorPosition, nextSize));

    if (safeCursor <= 0)
        return;

    next.remove(safeCursor - 1, 1);
    m_cursorPosition = safeCursor - 1;
    emit cursorChanged();
    updateActiveText(next);
}

void PdfEditSessionController::handleDelete()
{
    if (!m_active)
        return;

    editTrace("[PDF_EDIT_KEY]",
              QStringLiteral("delete cursor=%1 replaceSelection=%2 selectionLength=%3")
                  .arg(m_cursorPosition)
                  .arg(m_replaceSelectionOnInput)
                  .arg(m_selectionLength));

    if (m_replaceSelectionOnInput || m_selectionLength > 0) {
        replaceSelectionWithText(QString());
        return;
    }

    if (m_cursorPosition >= static_cast<int>(m_activeText.size()))
        return;

    QString next = m_activeText;
    const int nextSize = static_cast<int>(next.size());
    const int safeCursor = std::max(0, std::min(m_cursorPosition, nextSize));

    if (safeCursor >= nextSize)
        return;

    next.remove(safeCursor, 1);
    emit cursorChanged();
    updateActiveText(next);
}

void PdfEditSessionController::moveCursorLeft()
{
    if (!m_active)
        return;

    if (m_replaceSelectionOnInput || m_selectionLength > 0) {
        m_cursorPosition = std::max(0, m_selectionStart);
        clearInputSelection();
        emit cursorChanged();
        rebuildActiveEditGeometryFromLayout();
        return;
    }

    if (m_cursorPosition <= 0)
        return;

    --m_cursorPosition;
    emit cursorChanged();
    rebuildActiveEditGeometryFromLayout();
}

void PdfEditSessionController::moveCursorRight()
{
    if (!m_active)
        return;

    if (m_replaceSelectionOnInput || m_selectionLength > 0) {
        const int activeTextSize = static_cast<int>(m_activeText.size());
        m_cursorPosition = std::max(0, std::min(m_selectionStart + m_selectionLength, activeTextSize));
        clearInputSelection();
        emit cursorChanged();
        rebuildActiveEditGeometryFromLayout();
        return;
    }

    if (m_cursorPosition >= static_cast<int>(m_activeText.size()))
        return;

    ++m_cursorPosition;
    emit cursorChanged();
    rebuildActiveEditGeometryFromLayout();
}

void PdfEditSessionController::moveCursorHome()
{
    if (!m_active)
        return;

    clearInputSelection();
    if (m_cursorPosition == 0)
        return;

    m_cursorPosition = 0;
    emit cursorChanged();
    rebuildActiveEditGeometryFromLayout();
}

void PdfEditSessionController::moveCursorEnd()
{
    if (!m_active)
        return;

    clearInputSelection();
    const int end = static_cast<int>(m_activeText.size());
    if (m_cursorPosition == end)
        return;

    m_cursorPosition = end;
    emit cursorChanged();
    rebuildActiveEditGeometryFromLayout();
}

void PdfEditSessionController::cancelActiveEdit()
{
    if (!m_active)
        return;

    const int pageIndex = m_currentPageIndex;
    const QString editId = selectedBlockId();
    editTrace("[PDF_EDIT_CANCEL]",
              QStringLiteral("reason=EscapePressed editingActive=%1 activeEditId=%2 page=%3 region=%4 currentLength=%5 confirmedCountBefore=%6")
                  .arg(m_active)
                  .arg(editId)
                  .arg(pageIndex)
                  .arg(m_activeRegionIndex)
                  .arg(m_activeText.size())
                  .arg(confirmedEditCount()));
    clearActiveTransientState(true);
    regenerateEditLayer();
    emit editCancelled(pageIndex, editId);
    editTrace("[PDF_EDIT_CANCEL]",
              QStringLiteral("reason=EscapePressed confirmedCountAfter=%1").arg(confirmedEditCount()));
}

void PdfEditSessionController::inputMethodCommit(const QString &commitText)
{
    handleKeyText(commitText);
}

void PdfEditSessionController::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void PdfEditSessionController::setReady(bool ready)
{
    if (m_ready == ready)
        return;
    m_ready = ready;
    emit readyChanged();
}

void PdfEditSessionController::setStatusMessage(const QString &message)
{
    if (m_statusMessage == message)
        return;
    m_statusMessage = message;
    emit statusMessageChanged();
}

bool PdfEditSessionController::ensurePage(int pageIndex)
{
    if (m_currentPageIndex == pageIndex && m_pageText.error.isEmpty())
        return true;
    return extractPage(pageIndex);
}

void PdfEditSessionController::selectRegionAt(const QPointF &point)
{
    editTrace("[PDF_EDIT_HIT]",
              QStringLiteral("hitTest page=%1 x=%2 y=%3 regions=%4 scale=%5")
                  .arg(m_currentPageIndex)
                  .arg(point.x())
                  .arg(point.y())
                  .arg(m_pageText.regions.size())
                  .arg(m_scale));

    const qreal tolerance = std::max<qreal>(2.0, 4.0 / std::max<qreal>(0.01, m_scale));
    int hitRegionIndex = -1;
    for (int i = 0; i < m_pageText.regions.size(); ++i) {
        if (m_pageText.regions.at(i).box.adjusted(-tolerance, -tolerance, tolerance, tolerance).contains(point)) {
            hitRegionIndex = i;
            break;
        }
    }

    if (hitRegionIndex < 0) {
        qreal bestDistance = std::numeric_limits<qreal>::max();
        for (int i = 0; i < m_pageText.regions.size(); ++i) {
            const QRectF box = m_pageText.regions.at(i).box.normalized();
            if (point.y() < box.top() - tolerance || point.y() > box.bottom() + tolerance)
                continue;

            const qreal dx = point.x() < box.left()
                ? box.left() - point.x()
                : (point.x() > box.right() ? point.x() - box.right() : 0.0);
            if (dx <= tolerance * 4.0 && dx < bestDistance) {
                bestDistance = dx;
                hitRegionIndex = i;
            }
        }
    }

    if (hitRegionIndex < 0) {
        editTrace("[PDF_EDIT_HIT]",
                  QStringLiteral("miss activeBefore=%1 activeRegion=%2").arg(m_active).arg(m_activeRegionIndex));
        if (m_active)
            commitActiveText(QStringLiteral("ClickedOutside"));
        else if (hasConfirmedEdits(m_currentPageIndex) && !m_pixelSize.isEmpty())
            regenerateEditLayer();
        else
            clearEditLayerIfNoVisibleEdits(QStringLiteral("hitMiss"));
        return;
    }

    if (m_active && m_activeRegionIndex != hitRegionIndex)
        commitActiveText(QStringLiteral("ClickedAnotherText"));

    if (m_active && m_activeRegionIndex == hitRegionIndex) {
        const PdfEditableRegion &activeRegion = m_pageText.regions.at(hitRegionIndex);
        const int clickedCursor = cursorIndexForPoint(activeRegion, point);
        const int safeCursor = std::max(0, std::min(clickedCursor, static_cast<int>(m_activeText.size())));
        const bool cursorChangedNow = m_cursorPosition != safeCursor;
        m_cursorPosition = safeCursor;
        clearInputSelection();
        rebuildSelectionJson();
        rebuildActiveEditGeometryFromLayout();
        editTrace("[PDF_EDIT_HIT]",
                  QStringLiteral("activeHit keptSession region=%1 textLength=%2 cursor=%3")
                      .arg(m_activeRegionIndex)
                      .arg(m_activeText.size())
                      .arg(m_cursorPosition));
        if (cursorChangedNow)
            emit cursorChanged();
        emit activeChanged();
        return;
    }

    m_activeRegionIndex = hitRegionIndex;
    PdfEditableRegion &region = m_pageText.regions[m_activeRegionIndex];
    const int regionFirst = std::max(0, region.glyphRange.first);
    const int regionGlyphCount = static_cast<int>(m_pageText.glyphs.size());
    const int regionEnd = std::min(regionGlyphCount, regionFirst + region.glyphRange.second);
    if (regionFirst < regionEnd) {
        const PdfGlyph &anchorGlyph = m_pageText.glyphs.at(regionFirst);
        const QRectF anchorBox = anchorGlyph.bbox.normalized();
        const qreal anchorY = anchorBox.center().y();
        const qreal lineTolerance = std::max<qreal>(2.0, anchorGlyph.fontSize * 0.65);
        int lineFirst = regionFirst;
        int lineEnd = regionEnd;

        for (int i = 0; i < regionGlyphCount; ++i) {
            const PdfGlyph &candidate = m_pageText.glyphs.at(i);
            if (candidate.blockIndex != anchorGlyph.blockIndex)
                continue;

            const QRectF candidateBox = candidate.bbox.normalized();
            if (std::abs(candidateBox.center().y() - anchorY) > lineTolerance)
                continue;

            lineFirst = std::min(lineFirst, i);
            lineEnd = std::max(lineEnd, i + 1);
        }

        QRectF lineBox;
        for (int i = lineFirst; i < lineEnd; ++i) {
            const QRectF glyphBox = m_pageText.glyphs.at(i).bbox.normalized();
            lineBox = lineBox.isNull() ? glyphBox : lineBox.united(glyphBox);
        }

        const qreal verticalInset = std::max<qreal>(0.2, lineBox.height() * 0.03);
        lineBox = lineBox.adjusted(0, verticalInset, 0, -verticalInset);

        QPolygonF lineQuad;
        lineQuad << lineBox.topLeft()
                 << lineBox.topRight()
                 << lineBox.bottomRight()
                 << lineBox.bottomLeft();

        region.glyphRange = {lineFirst, lineEnd - lineFirst};
        region.box = lineBox;
        region.unionQuad = lineQuad;
        region.baselineStart = m_pageText.glyphs.at(lineFirst).origin;
        region.baselineEnd = m_pageText.glyphs.at(lineEnd - 1).origin;
    }

    QString text;
    const int first = std::max(0, region.glyphRange.first);
    const int glyphCount = static_cast<int>(m_pageText.glyphs.size());
    const int end = std::min(glyphCount, first + region.glyphRange.second);
    for (int i = first; i < end; ++i) {
        const char32_t scalar = static_cast<char32_t>(m_pageText.glyphs.at(i).unicode);
        if (scalar)
            text.append(QString::fromUcs4(&scalar, 1));
    }

    m_originalActiveText = text;
    m_activeText = text;
    auto existing = std::find_if(
        m_textEdits.begin(),
        m_textEdits.end(),
        [&](const PdfTextEditOperation &candidate) {
            return candidate.pageIndex == m_currentPageIndex
                && candidate.regionIndex == m_activeRegionIndex;
        });
    if (existing != m_textEdits.end())
        m_activeText = existing->replacementText;
    const int clickedCursor = cursorIndexForPoint(region, point);
    const int activeTextSize = static_cast<int>(m_activeText.size());
    m_cursorPosition = std::max(0, std::min(clickedCursor, activeTextSize));
    m_selectionStart = 0;
    m_selectionLength = activeTextSize;
    m_replaceSelectionOnInput = true;
    m_active = true;
    editTrace("[PDF_EDIT_ACTIVE_TRUE]",
              QStringLiteral("page=%1 region=%2 textLength=%3")
                  .arg(m_currentPageIndex)
                  .arg(m_activeRegionIndex)
                  .arg(m_activeText.size()));
    rebuildSelectionJson();
    rebuildActiveLayout();
    scheduleRegenerateEditLayer(QStringLiteral("selectRegionAt"));
    editTrace("[PDF_EDIT_HIT]",
              QStringLiteral("hit region=%1 textLength=%2 cursor=%3 selectionLength=%4")
                  .arg(m_activeRegionIndex)
                  .arg(m_activeText.size())
                  .arg(m_cursorPosition)
                  .arg(m_selectionLength));
    emit activeTextChanged();
    emit cursorChanged();
    emit inputStateChanged();
    emit activeChanged();
}

void PdfEditSessionController::rebuildPageJson()
{
    m_runsJson = jsonArrayToCompactString(runsToJson(m_pageText.runs));
    m_regionsJson = jsonArrayToCompactString(regionsToJson(m_pageText.regions));
    emit pageChanged();
}

void PdfEditSessionController::rebuildSelectionJson()
{
    QJsonArray array;
    if (m_activeRegionIndex >= 0 && m_activeRegionIndex < m_pageText.regions.size())
        array.append(quadToJson(m_pageText.regions.at(m_activeRegionIndex).unionQuad));
    m_selectionQuadsJson = jsonArrayToCompactString(array);
}

void PdfEditSessionController::rebuildActiveEditGeometry()
{
    rebuildActiveLayout();
}

PdfFontResolver::ResolvedFont PdfEditSessionController::cachedResolvedFontForRun(const PdfRun &run) const
{
    const QString key = m_filePath + QStringLiteral("|") + run.fontResourceKey;
    auto it = m_resolvedFontCache.constFind(key);
    if (it != m_resolvedFontCache.constEnd())
        return it.value();

    PdfFontResolver::ResolvedFont resolved =
        m_fontResolver.resolveEmbeddedFont(m_filePath, m_password, run.fontResourceKey);
    m_resolvedFontCache.insert(key, resolved);
    return resolved;
}

PdfEditTextLayoutResult PdfEditSessionController::layoutForReplacementRun(
    const PdfRun &run,
    const QString &replacementText,
    const PdfDetectedTextStyle &style) const
{
    const PdfFontResolver::ResolvedFont resolved = cachedResolvedFontForRun(run);
    const bool hasStyleOverride = !style.fontResourceKey.isEmpty()
        || !style.fontFamily.isEmpty()
        || !style.fontFaceName.isEmpty();
    const bool bold = hasStyleOverride ? style.bold : run.bold;
    const bool italic = hasStyleOverride ? style.italic : run.italic;
    const PdfEditFontDecision decision =
        m_fontDecisionService.decideFontForEditedText(resolved, replacementText, bold, italic);

    if (qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_EDIT_METRICS")
        || qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_SAVE")) {
        qInfo().noquote()
            << QStringLiteral("[PDF_EDIT_FONT_DECISION] preview text=\"%1\" original=\"%2\" selected=\"%3\" embeddedOriginal=%4 bundledFallback=%5 subsetRejected=%6 reason=%7")
                   .arg(replacementText.left(60))
                   .arg(resolved.originalSubsetName)
                   .arg(decision.fontName)
                   .arg(decision.useEmbeddedOriginal)
                   .arg(decision.useBundledFallback)
                   .arg(decision.subsetOriginalRejected)
                   .arg(decision.reason);
    }

    PdfEditTextLayoutResult layout = m_textLayout.layoutRun(run,
                                                            replacementText,
                                                            decision.fontProgram,
                                                            decision.fontName,
                                                            style);
    layout.usedEmbeddedFont = decision.useEmbeddedOriginal;
    layout.usedFallbackFont = decision.useBundledFallback || !decision.useEmbeddedOriginal;
    layout.debugFontName = decision.fontName;
    layout.debugReason = decision.reason;
    layout.fontName = decision.fontName;
    layout.fontProgram = decision.fontProgram;
    return layout;
}

void PdfEditSessionController::rebuildActiveLayout()
{
    m_activeLayout = {};
    if (!m_active || m_activeRegionIndex < 0 || m_currentPageIndex < 0) {
        rebuildActiveEditGeometryFromLayout();
        rebuildActiveStyleJsonFromLayout();
        return;
    }

    const QVector<PdfRun> runs = activeReplacementRuns();
    if (runs.isEmpty()) {
        rebuildActiveEditGeometryFromLayout();
        rebuildActiveStyleJsonFromLayout();
        return;
    }

    const PdfRun &run = runs.constFirst();
    m_activeLayout = layoutForReplacementRun(run, m_activeText);
    rebuildActiveEditGeometryFromLayout();
    rebuildActiveStyleJsonFromLayout();
}

void PdfEditSessionController::rebuildActiveEditGeometryFromLayout()
{
    QJsonObject root;

    if (!m_active || !m_activeLayout.valid) {
        const QString empty = QStringLiteral("{}");
        if (m_activeEditGeometryJson != empty) {
            m_activeEditGeometryJson = empty;
            emit activeEditGeometryChanged();
        }
        return;
    }

    QRectF visualBox = m_activeLayout.visualBox.normalized();
    if (m_activeRegionIndex >= 0 && m_activeRegionIndex < m_pageText.regions.size()) {
        QRectF frameBox = m_pageText.regions.at(m_activeRegionIndex).box.normalized();
        const QRectF laidOut = m_activeLayout.visualBox.normalized();
        frameBox.setWidth(std::max(frameBox.width(), laidOut.right() - frameBox.left()));
        visualBox = frameBox.normalized();
    }
    const int caretCount = static_cast<int>(m_activeLayout.carets.size());
    const int safeCursor = std::max(0, std::min(m_cursorPosition, caretCount - 1));
    const PdfEditCaret caretData = m_activeLayout.carets.isEmpty()
        ? PdfEditCaret{}
        : m_activeLayout.carets.at(safeCursor);

    QJsonObject box;
    box.insert(QStringLiteral("x"), visualBox.x());
    box.insert(QStringLiteral("y"), visualBox.y());
    box.insert(QStringLiteral("width"), visualBox.width());
    box.insert(QStringLiteral("height"), visualBox.height());

    QJsonObject caret;
    caret.insert(QStringLiteral("x"), caretData.x);
    caret.insert(QStringLiteral("y"), visualBox.y());
    caret.insert(QStringLiteral("height"), visualBox.height());

    QJsonObject baseline;
    baseline.insert(QStringLiteral("startX"), m_activeLayout.baselineStart.x());
    baseline.insert(QStringLiteral("startY"), m_activeLayout.baselineStart.y());
    baseline.insert(QStringLiteral("endX"), m_activeLayout.baselineEnd.x());
    baseline.insert(QStringLiteral("endY"), m_activeLayout.baselineEnd.y());

    root.insert(QStringLiteral("box"), box);
    root.insert(QStringLiteral("caret"), caret);
    root.insert(QStringLiteral("baseline"), baseline);
    root.insert(QStringLiteral("text"), m_activeText);
    root.insert(QStringLiteral("cursor"), safeCursor);
    root.insert(QStringLiteral("font"), m_activeLayout.debugFontName);
    root.insert(QStringLiteral("embedded"), m_activeLayout.usedEmbeddedFont);
    root.insert(QStringLiteral("fallback"), m_activeLayout.usedFallbackFont);
    root.insert(QStringLiteral("fontDecision"), m_activeLayout.debugReason);

    if (editMetricsTraceEnabled()) {
        const int logCaretIndex = std::max(0, std::min(m_cursorPosition, caretCount - 1));
        const qreal logCaretX = m_activeLayout.carets.isEmpty() ? 0.0 : m_activeLayout.carets.at(logCaretIndex).x;
        qInfo().noquote()
            << QStringLiteral("[PDF_EDIT_METRICS] page=%1 region=%2 text=\"%3\" cursor=%4 box=(%5,%6,%7,%8) caretX=%9 baseline=(%10,%11)->(%12,%13) font=\"%14\" embedded=%15 fallback=%16 hScale=%17")
                   .arg(m_currentPageIndex)
                   .arg(m_activeRegionIndex)
                   .arg(m_activeText.left(80))
                   .arg(m_cursorPosition)
                   .arg(visualBox.x())
                   .arg(visualBox.y())
                   .arg(visualBox.width())
                   .arg(visualBox.height())
                   .arg(logCaretX)
                   .arg(m_activeLayout.baselineStart.x())
                   .arg(m_activeLayout.baselineStart.y())
                   .arg(m_activeLayout.baselineEnd.x())
                   .arg(m_activeLayout.baselineEnd.y())
                   .arg(m_activeLayout.debugFontName)
                   .arg(m_activeLayout.usedEmbeddedFont)
                   .arg(m_activeLayout.usedFallbackFont)
                   .arg(m_activeLayout.horizontalScale);
    }

    const QString next = QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact));
    if (m_activeEditGeometryJson != next) {
        m_activeEditGeometryJson = next;
        emit activeEditGeometryChanged();
    }
}

void PdfEditSessionController::rebuildActiveStyleJsonFromLayout()
{
    QJsonObject style;

    if (!m_active || !m_activeLayout.valid) {
        const QString empty = QStringLiteral("{}");
        if (m_activeStyleJson != empty) {
            m_activeStyleJson = empty;
            emit activeStyleChanged();
        }
        return;
    }

    const PdfDetectedTextStyle &s = m_activeLayout.style;
    style.insert(QStringLiteral("fontFamily"), s.fontFamily);
    style.insert(QStringLiteral("fontFaceName"), s.fontFaceName);
    style.insert(QStringLiteral("fontResourceKey"), s.fontResourceKey);
    style.insert(QStringLiteral("fontSize"), s.effectiveFontSize);
    style.insert(QStringLiteral("color"), s.fillColor.name(QColor::HexRgb));
    style.insert(QStringLiteral("bold"), s.bold);
    style.insert(QStringLiteral("italic"), s.italic);
    style.insert(QStringLiteral("underline"), s.underline);
    style.insert(QStringLiteral("strikeout"), s.strikeout);
    style.insert(QStringLiteral("filled"), s.filled);
    style.insert(QStringLiteral("stroked"), s.stroked);
    style.insert(QStringLiteral("horizontalScale"), s.horizontalScale);

    const QString next = QString::fromUtf8(QJsonDocument(style).toJson(QJsonDocument::Compact));
    if (m_activeStyleJson != next) {
        m_activeStyleJson = next;
        emit activeStyleChanged();
    }

    if (editMetricsTraceEnabled()) {
        qInfo().noquote()
            << QStringLiteral("[PDF_EDIT_STYLE] bold=%1 italic=%2 underline=%3 fontSize=%4 color=%5")
                   .arg(s.bold)
                   .arg(s.italic)
                   .arg(s.underline)
                   .arg(s.effectiveFontSize)
                   .arg(s.fillColor.name(QColor::HexRgb));
    }
}

void PdfEditSessionController::scheduleRegenerateEditLayer(const QString &reason)
{
    m_lastRenderReason = reason;
    m_editLayerRenderPending = true;
    if (!m_editLayerRenderTimer.isActive())
        m_editLayerRenderTimer.start();
}

QString PdfEditSessionController::redactedBaseCacheKey(int pageIndex, const QVector<QPolygonF> &quads) const
{
    QJsonObject root;
    root.insert(QStringLiteral("filePath"), m_filePath);
    root.insert(QStringLiteral("pageIndex"), pageIndex);
    root.insert(QStringLiteral("scale"), m_scale);
    root.insert(QStringLiteral("pixelWidth"), m_pixelSize.width());
    root.insert(QStringLiteral("pixelHeight"), m_pixelSize.height());
    QJsonArray quadArray;
    for (const QPolygonF &quad : quads)
        quadArray.append(quadToJson(quad));
    root.insert(QStringLiteral("quads"), quadArray);
    return QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact));
}

void PdfEditSessionController::regenerateEditLayer()
{
    QElapsedTimer timer;
    timer.start();

    const int confirmedCount = static_cast<int>(std::count_if(
        m_textEdits.cbegin(),
        m_textEdits.cend(),
        [&](const PdfTextEditOperation &edit) {
            return edit.pageIndex == m_currentPageIndex && edit.committed;
        }));
    editTrace("[PDF_EDIT_RENDER]",
              QStringLiteral("regenerate active=%1 page=%2 region=%3 activeLength=%4 originalLength=%5 pixel=%6x%7 scale=%8 confirmedCount=%9 pending=%10")
                  .arg(m_active)
                  .arg(m_currentPageIndex)
                  .arg(m_activeRegionIndex)
                  .arg(m_activeText.size())
                  .arg(m_originalActiveText.size())
                  .arg(m_pixelSize.width())
                  .arg(m_pixelSize.height())
                  .arg(m_scale)
                  .arg(confirmedCount)
                  .arg(m_hasPendingEdits));

    if ((!m_active && !hasConfirmedEdits(m_currentPageIndex)) || m_pixelSize.isEmpty()) {
        m_editLayerImage = {};
        emit editLayerImageChanged();
        return;
    }

    QString error;
    const QVector<QPolygonF> redactionQuads = redactionQuadsForPage(m_currentPageIndex);
    const QString baseKey = redactedBaseCacheKey(m_currentPageIndex, redactionQuads);
    const bool baseCacheHit = baseKey == m_redactedBaseCacheKey && !m_redactedBaseCacheImage.isNull();
    QImage base = baseCacheHit
        ? m_redactedBaseCacheImage.copy()
        : m_scratchRenderer.renderRedactedBase(m_filePath,
                                               m_password,
                                               m_currentPageIndex,
                                               redactionQuads,
                                               m_scale,
                                               &error);
    if (base.isNull()) {
        editTrace("[PDF_EDIT_RENDER]", QStringLiteral("redactedBase failed errorLength=%1").arg(error.size()));
        setStatusMessage(error);
        return;
    }

    if (!baseCacheHit) {
        m_redactedBaseCacheImage = base.copy();
        m_redactedBaseCacheKey = baseKey;
    }

    const QVector<PdfEditTextLayoutResult> layouts = replacementLayoutsForPage(m_currentPageIndex);
    QImage overlay = m_scratchRenderer.renderGlyphOverlayFromLayouts(layouts,
                                                                     m_pixelSize,
                                                                     m_scale,
                                                                     &error);
    if (!layouts.isEmpty()) {
        const PdfEditTextLayoutResult &layout = layouts.constFirst();
        m_lastResolvedEditFontDebug = QStringLiteral("embedded:%1 fallback:%2 fontName:%3")
            .arg(layout.usedEmbeddedFont ? QStringLiteral("true") : QStringLiteral("false"))
            .arg(layout.usedFallbackFont ? QStringLiteral("true") : QStringLiteral("false"))
            .arg(layout.debugFontName);
    }
    if (!overlay.isNull()) {
        QPainter painter(&base);
        painter.drawImage(QPoint(0, 0), overlay);
    }

    m_editLayerImage = base;
    editTrace("[PDF_EDIT_RENDER]",
              QStringLiteral("ready image=%1x%2 overlayNull=%3")
                  .arg(m_editLayerImage.width())
                  .arg(m_editLayerImage.height())
                  .arg(overlay.isNull()));
    qInfo().noquote()
        << QStringLiteral("[PDF_EDIT_PERF] regenerateEditLayer reason=%1 elapsedMs=%2 active=%3 textLength=%4 cachedBase=%5")
              .arg(m_lastRenderReason)
              .arg(timer.elapsed())
              .arg(m_active)
              .arg(m_activeText.size())
              .arg(baseCacheHit);
    emit editLayerImageChanged();
}

int PdfEditSessionController::cursorIndexForPoint(const PdfEditableRegion &region, const QPointF &point) const
{
    const int first = std::max(0, region.glyphRange.first);
    const int glyphCount = static_cast<int>(m_pageText.glyphs.size());
    const int end = std::min(glyphCount, first + region.glyphRange.second);

    if (first >= end)
        return 0;

    int bestIndex = 0;
    qreal bestDistance = std::numeric_limits<qreal>::max();

    for (int i = first; i < end; ++i) {
        const PdfGlyph &glyph = m_pageText.glyphs.at(i);
        const QRectF box = glyph.bbox.normalized();

        const qreal midX = box.center().x();
        const qreal distance = std::abs(point.x() - midX);

        if (distance < bestDistance) {
            bestDistance = distance;
            bestIndex = i - first + (point.x() > midX ? 1 : 0);
        }
    }

    return std::max(0, std::min(bestIndex, end - first));
}

void PdfEditSessionController::clearInputSelection()
{
    const bool changed = m_replaceSelectionOnInput || m_selectionStart != 0 || m_selectionLength != 0;

    m_replaceSelectionOnInput = false;
    m_selectionStart = 0;
    m_selectionLength = 0;

    if (changed)
        emit inputStateChanged();
}

void PdfEditSessionController::replaceSelectionWithText(const QString &text)
{
    if (!m_active)
        return;

    QString next = m_activeText;
    const int nextSize = static_cast<int>(next.size());

    const int safeStart = std::max(0, std::min(m_selectionStart, nextSize));
    const int safeLength = std::max(0, std::min(m_selectionLength, nextSize - safeStart));

    next.remove(safeStart, safeLength);
    next.insert(safeStart, text);

    m_cursorPosition = safeStart + static_cast<int>(text.size());

    clearInputSelection();

    emit cursorChanged();
    updateActiveText(next);
}

void PdfEditSessionController::clearActiveTransientState(bool emitActiveSignals)
{
    const bool wasActive = m_active;
    const bool cursorChangedNow = m_cursorPosition != 0;
    const bool inputStateChangedNow = m_replaceSelectionOnInput || m_selectionStart != 0 || m_selectionLength != 0;

    m_active = false;
    m_activeRegionIndex = -1;
    m_activeText.clear();
    m_originalActiveText.clear();
    m_selectionQuadsJson = QStringLiteral("[]");
    m_cursorPosition = 0;
    m_replaceSelectionOnInput = false;
    m_selectionStart = 0;
    m_selectionLength = 0;
    rebuildActiveLayout();

    if (emitActiveSignals && wasActive)
        emit activeChanged();
    emit activeTextChanged();
    if (cursorChangedNow)
        emit cursorChanged();
    if (inputStateChangedNow)
        emit inputStateChanged();
}

PdfTextEditOperation PdfEditSessionController::activeOperationSnapshot() const
{
    PdfTextEditOperation operation;
    operation.id = QStringLiteral("text-edit-%1-%2")
        .arg(m_currentPageIndex)
        .arg(m_activeRegionIndex);
    operation.pageIndex = m_currentPageIndex;
    operation.regionIndex = m_activeRegionIndex;
    operation.originalText = m_originalActiveText;
    operation.replacementText = m_activeText;
    operation.replacementRuns = activeReplacementRuns();
    operation.redactionQuads = activeRedactionQuads();
    operation.committed = true;

    for (const QPolygonF &quad : operation.redactionQuads)
        operation.dirtyRect = operation.dirtyRect.united(quad.boundingRect());
    if (!operation.dirtyRect.isNull())
        operation.dirtyRect = operation.dirtyRect.adjusted(-4, -4, 4, 4);

    if (!operation.replacementRuns.isEmpty() && !operation.replacementRuns.constFirst().glyphs.isEmpty()) {
        const PdfRun &run = operation.replacementRuns.constFirst();
        const PdfGlyph &first = run.glyphs.constFirst();
        const QRectF visualRect = unionGlyphBoxes(run.glyphs, 0, run.glyphs.size()).normalized();
        editTrace("[PDF_EDIT_COMMIT_GEOMETRY]",
                  QStringLiteral("pageIndex=%1 editId=%2 originalText=\"%3\" editedText=\"%4\" pageWidth=unknown pageHeight=unknown visualRect=(%5,%6,%7,%8) visualBaseline=(%9,%10) originalFontSize=%11 originalFontFamily=\"%12\" originalAscent=%13 originalDescent=%14 originalDirection=(%15,%16) zoom=%17 devicePixelRatio=not-used")
                      .arg(operation.pageIndex)
                      .arg(operation.id)
                      .arg(operation.originalText.left(80))
                      .arg(operation.replacementText.left(80))
                      .arg(visualRect.x())
                      .arg(visualRect.y())
                      .arg(visualRect.width())
                      .arg(visualRect.height())
                      .arg(first.origin.x())
                      .arg(first.origin.y())
                      .arg(first.fontSize)
                      .arg(first.fontName)
                      .arg(first.fontSize * 0.78)
                      .arg(first.fontSize * 0.22)
                      .arg(run.direction.x())
                      .arg(run.direction.y())
                      .arg(m_scale));
    }

    return operation;
}

QVector<PdfRun> PdfEditSessionController::replacementRunsForOperation(const PdfTextEditOperation &operation) const
{
    QVector<PdfRun> runs = operation.replacementRuns;
    for (PdfRun &run : runs)
        run.plainText = operation.replacementText;
    return runs;
}

QVector<PdfRun> PdfEditSessionController::replacementRunsForPage(int pageIndex) const
{
    QVector<PdfRun> runs;
    for (const PdfTextEditOperation &operation : m_textEdits) {
        if (operation.pageIndex == pageIndex)
            runs += replacementRunsForOperation(operation);
    }

    if (m_active && m_currentPageIndex == pageIndex)
        runs += activeReplacementRuns();

    return runs;
}

QVector<QPolygonF> PdfEditSessionController::redactionQuadsForPage(int pageIndex) const
{
    QVector<QPolygonF> quads;
    for (const PdfTextEditOperation &operation : m_textEdits) {
        if (operation.pageIndex == pageIndex)
            quads += operation.redactionQuads;
    }

    if (m_active && m_currentPageIndex == pageIndex)
        quads += activeRedactionQuads();

    return quads;
}

QVector<PdfRun> PdfEditSessionController::activeReplacementRuns() const
{
    QVector<PdfRun> replacementRuns;
    if (m_activeRegionIndex < 0 || m_activeRegionIndex >= m_pageText.regions.size())
        return replacementRuns;

    const PdfEditableRegion &region = m_pageText.regions.at(m_activeRegionIndex);
    const int first = std::max(0, region.glyphRange.first);
    const int glyphCount = static_cast<int>(m_pageText.glyphs.size());
    const int count = std::min(region.glyphRange.second, glyphCount - first);
    if (count <= 0)
        return replacementRuns;

    PdfRun run;
    run.glyphs = m_pageText.glyphs.mid(first, count);
    run.plainText = m_activeText;
    if (!run.glyphs.isEmpty()) {
        const PdfGlyph &glyph = run.glyphs.constFirst();
        run.fontResourceKey = glyph.fontResourceKey;
        run.fillColor = glyph.fillColor;
        run.bold = glyph.bold;
        run.italic = glyph.italic;
        run.underline = glyph.underline;
        run.strikeout = glyph.strikeout;
        run.filled = glyph.filled;
        run.stroked = glyph.stroked;
        run.clipped = glyph.clipped;
        run.renderMode = glyph.renderMode;
        run.wmode = glyph.wmode;
        run.bidiLevel = glyph.bidiLevel;
        run.direction = glyph.direction;
        run.trm = glyph.trm;
        run.effectiveFontSize = effectiveVisualFontSize(run);
        if (m_activeLayout.valid && m_activeLayout.text == m_activeText) {
            run.visualWidth = m_activeLayout.visualBox.width();
            run.naturalWidth = m_activeLayout.naturalWidth;
            run.horizontalScale = m_activeLayout.horizontalScale;
            run.effectiveFontSize = m_activeLayout.style.effectiveFontSize;
            run.fillColor = m_activeLayout.style.fillColor;
            run.bold = m_activeLayout.style.bold;
            run.italic = m_activeLayout.style.italic;
            run.underline = m_activeLayout.style.underline;
            run.strikeout = m_activeLayout.style.strikeout;
            run.filled = m_activeLayout.style.filled;
            run.stroked = m_activeLayout.style.stroked;
            run.clipped = m_activeLayout.style.clipped;
            run.renderMode = m_activeLayout.style.renderMode;
        }
    }
    replacementRuns.append(run);
    return replacementRuns;
}

QVector<PdfEditTextLayoutResult> PdfEditSessionController::replacementLayoutsForPage(int pageIndex) const
{
    QVector<PdfEditTextLayoutResult> layouts;

    for (const PdfTextEditOperation &operation : m_textEdits) {
        if (operation.pageIndex != pageIndex)
            continue;

        for (PdfRun run : replacementRunsForOperation(operation)) {
            PdfEditTextLayoutResult layout = layoutForReplacementRun(run, operation.replacementText);
            if (layout.valid)
                layouts.append(layout);
        }
    }

    if (m_active && m_currentPageIndex == pageIndex && m_activeLayout.valid)
        layouts.append(m_activeLayout);

    return layouts;
}

QVector<QPolygonF> PdfEditSessionController::activeRedactionQuads() const
{
    QVector<QPolygonF> quads;
    if (m_activeRegionIndex < 0 || m_activeRegionIndex >= m_pageText.regions.size())
        return quads;

    const PdfEditableRegion &region = m_pageText.regions.at(m_activeRegionIndex);
    const int first = std::max(0, region.glyphRange.first);
    const int glyphCount = static_cast<int>(m_pageText.glyphs.size());
    const int end = std::min(glyphCount, first + region.glyphRange.second);
    quads.reserve(end - first);
    for (int i = first; i < end; ++i) {
        const PdfGlyph &glyph = m_pageText.glyphs.at(i);
        if (!glyph.quad.isEmpty() && glyph.quad.size() >= 4)
            quads.append(glyph.quad);
        else
            quads.append(quadFromRect(tightGlyphRedactionRect(glyph.bbox)));
    }
    return quads;
}

bool PdfEditSessionController::writeEditedPdfCopy(const QString &tempPath, QString *error) const
{
    if (m_textEdits.isEmpty()) {
        if (error)
            *error = QStringLiteral("No hay cambios de texto pendientes.");
        return false;
    }

    fz_context *ctx = fz_new_context(nullptr, nullptr, FZ_STORE_DEFAULT);
    if (!ctx) {
        if (error)
            *error = QStringLiteral("MuPDF no pudo crear contexto de guardado.");
        return false;
    }

    fz_document *doc = nullptr;
    pdf_document *pdfDoc = nullptr;
    pdf_page *page = nullptr;
    QString caught;

    const QByteArray sourcePath = toLocalPath(m_filePath).toUtf8();
    const QByteArray passwordBytes = m_password.toUtf8();
    const QByteArray targetPath = toLocalPath(tempPath).toUtf8();

    fz_try(ctx)
    {
        fz_register_document_handlers(ctx);
        doc = fz_open_document(ctx, sourcePath.constData());
        if (fz_needs_password(ctx, doc)) {
            if (passwordBytes.isEmpty() || !fz_authenticate_password(ctx, doc, passwordBytes.constData()))
                fz_throw(ctx, FZ_ERROR_GENERIC, "Password required for edited PDF save.");
        }

        pdfDoc = pdf_specifics(ctx, doc);
        if (!pdfDoc)
            fz_throw(ctx, FZ_ERROR_GENERIC, "The active document is not a writable PDF.");

        QHash<int, QVector<PdfTextEditOperation>> editsByPage;
        for (const PdfTextEditOperation &edit : m_textEdits)
            editsByPage[edit.pageIndex].append(edit);

        PdfContentWriter contentWriter;
        PdfFontResourceWriter fontWriter;
        for (auto it = editsByPage.constBegin(); it != editsByPage.constEnd(); ++it) {
            const int editedPageIndex = it.key();
            const QVector<PdfTextEditOperation> pageEdits = it.value();

            page = pdf_load_page(ctx, pdfDoc, editedPageIndex);
            fz_page *fitzPage = fz_load_page(ctx, doc, editedPageIndex);
            const fz_rect pageBounds = fz_bound_page(ctx, fitzPage);
            fz_drop_page(ctx, fitzPage);
            const qreal pageHeight = pageBounds.y1 - pageBounds.y0;

            pdf_redact_options redactionOptions = {};
            redactionOptions.black_boxes = 0;
            redactionOptions.image_method = PDF_REDACT_IMAGE_NONE;
            redactionOptions.line_art = PDF_REDACT_LINE_ART_NONE;
            redactionOptions.text = PDF_REDACT_TEXT_REMOVE;

            for (const PdfTextEditOperation &edit : pageEdits) {
                qInfo().noquote() << QStringLiteral("[PDF_EXPORT_REDACT] applying glyph redactions only pageIndex=%1 quads=%2")
                                      .arg(editedPageIndex)
                                      .arg(edit.redactionQuads.size());
                for (const QPolygonF &quad : edit.redactionQuads) {
                    const fz_quad fzQuad = toFzQuad(quad);
                    applyTextRedaction(ctx, page, fzQuad, &redactionOptions);
                }
            }

            for (const PdfTextEditOperation &edit : pageEdits) {
                for (const PdfRun &run : edit.replacementRuns) {
                    QString localError;
                    const PdfFontResolver::ResolvedFont resolved =
                        m_fontResolver.resolveEmbeddedFont(m_filePath, m_password, run.fontResourceKey);
                    const PdfFontWritePlan fontPlan =
                        fontWriter.ensureFontForTextWithOriginalProgram(
                            ctx,
                            pdfDoc,
                            page,
                            run,
                            edit.replacementText,
                            resolved.fontProgram,
                            resolved.originalSubsetName.isEmpty()
                                ? (run.glyphs.isEmpty() ? QString() : run.glyphs.constFirst().fontName)
                                : resolved.originalSubsetName,
                            &localError);
                    if (fontPlan.resourceName.isEmpty())
                        fz_throw(ctx, FZ_ERROR_GENERIC, localError.toUtf8().constData());

                    const PdfContentWriter::StreamBuildResult stream =
                        contentWriter.buildReplacementTextStream(run,
                                                                 edit.replacementText,
                                                                 fontPlan,
                                                                 pageHeight,
                                                                 edit.id);
                    if (stream.contentStream.isEmpty())
                        fz_throw(ctx, FZ_ERROR_GENERIC, "Replacement text stream was empty.");
                    appendContentStream(ctx, pdfDoc, page, stream.contentStream);
                }
            }

            pdf_drop_page(ctx, page);
            page = nullptr;
        }

        pdf_write_options writeOptions = pdf_default_write_options;
        writeOptions.do_garbage = 1;
        writeOptions.do_compress = 1;
        pdf_save_document(ctx, pdfDoc, targetPath.constData(), &writeOptions);
    }
    fz_catch(ctx)
    {
        caught = QString::fromUtf8(fz_caught_message(ctx));
    }

    if (page)
        pdf_drop_page(ctx, page);
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

} // namespace PDFClowne::Editing
