#include "PdfEditSessionController.h"

#include "../pdf/PdfContentWriter.h"
#include "../pdf/PdfSaveCoordinator.h"

#include <QBuffer>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QPainter>
#include <QUrl>

#include <mupdf/fitz.h>
#include <mupdf/pdf.h>

#include <algorithm>

namespace PDFClowne::Editing {
namespace {

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

QString resourceNameFromKey(const QString &fontResourceKey)
{
    const QString marker = QStringLiteral("/font:");
    const QString endMarker = QStringLiteral("/xref:");
    const int start = fontResourceKey.indexOf(marker);
    if (start < 0)
        return {};

    const int valueStart = start + marker.size();
    const int valueEnd = fontResourceKey.indexOf(endMarker, valueStart);
    if (valueEnd <= valueStart)
        return {};

    return fontResourceKey.mid(valueStart, valueEnd - valueStart);
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

pdf_obj *ensurePageResources(fz_context *ctx, pdf_document *doc, pdf_page *page)
{
    pdf_obj *resources = pdf_page_resources(ctx, page);
    if (resources)
        return resources;

    resources = pdf_new_dict(ctx, doc, 4);
    pdf_dict_put_drop(ctx, page->obj, PDF_NAME(Resources), resources);
    return pdf_page_resources(ctx, page);
}

QString ensureWritableFontResource(fz_context *ctx,
                                   pdf_document *doc,
                                   pdf_page *page,
                                   const QString &preferredResourceName,
                                   QString *error)
{
    pdf_obj *resources = ensurePageResources(ctx, doc, page);
    pdf_obj *fonts = pdf_dict_get(ctx, resources, PDF_NAME(Font));
    if (!fonts)
        fonts = pdf_dict_put_dict(ctx, resources, PDF_NAME(Font), 4);

    if (!preferredResourceName.isEmpty()
            && pdf_dict_gets(ctx, fonts, preferredResourceName.toUtf8().constData()))
        return preferredResourceName;

    fz_font *font = nullptr;
    QString resourceName;
    fz_try(ctx)
    {
        font = fz_new_base14_font(ctx, "Helvetica");
        pdf_obj *fontRef = pdf_add_simple_font(ctx, doc, font, PDF_SIMPLE_ENCODING_LATIN);
        for (int i = 0; i < 100; ++i) {
            const QString candidate = i == 0
                ? QStringLiteral("PclEditF")
                : QStringLiteral("PclEditF%1").arg(i);
            if (!pdf_dict_gets(ctx, fonts, candidate.toUtf8().constData())) {
                pdf_dict_puts(ctx, fonts, candidate.toUtf8().constData(), fontRef);
                resourceName = candidate;
                break;
            }
        }
    }
    fz_always(ctx)
    {
        if (font)
            fz_drop_font(ctx, font);
    }
    fz_catch(ctx)
    {
        if (error)
            *error = QString::fromUtf8(fz_caught_message(ctx));
        resourceName.clear();
    }

    if (resourceName.isEmpty() && error && error->isEmpty())
        *error = QStringLiteral("No se pudo declarar un recurso de fuente para el texto editado.");
    return resourceName;
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

bool PdfEditSessionController::loadDocumentWithPassword(const QString &filePath, const QString &password)
{
    if (m_filePath == filePath && m_password == password && m_ready)
        return true;

    clearSession();
    m_filePath = filePath;
    m_password = password;
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
    return true;
}

void PdfEditSessionController::extractBlocksForPage(int pageIndex)
{
    extractPage(pageIndex);
}

void PdfEditSessionController::selectBlock(const QString &blockId)
{
    if (blockId.isEmpty())
        clearSession();
}

void PdfEditSessionController::closeDocument()
{
    clearSession();
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
    if (!ensurePage(pageIndex))
        return false;

    m_pixelSize = QSize(std::max(1, pixelWidth), std::max(1, pixelHeight));
    m_scale = std::max<qreal>(0.01, scale);
    selectRegionAt(QPointF(pageX, pageY));
    return m_active;
}

void PdfEditSessionController::clearSession()
{
    const bool wasActive = m_active;
    m_active = false;
    m_activeRegionIndex = -1;
    m_activeText.clear();
    m_originalActiveText.clear();
    m_selectionQuadsJson = QStringLiteral("[]");
    m_editLayerImage = {};
    if (wasActive)
        emit activeChanged();
    emit activeTextChanged();
    emit editLayerImageChanged();
}

void PdfEditSessionController::updateActiveText(const QString &text)
{
    if (!m_active || m_activeText == text)
        return;

    m_activeText = text;
    if (m_activeText != m_originalActiveText && !m_hasPendingEdits) {
        m_hasPendingEdits = true;
        emit pendingEditsChanged();
    }
    emit activeTextChanged();
    regenerateEditLayer();
}

bool PdfEditSessionController::commitActiveText()
{
    if (!m_active)
        return false;

    if (m_activeText == m_originalActiveText)
        clearSession();
    return true;
}

bool PdfEditSessionController::saveDocument(const QString &outputPath, bool incremental)
{
    if (!m_hasPendingEdits || !m_active) {
        emit saveError(tr("No hay cambios de texto pendientes."));
        return false;
    }

    PdfSaveCoordinator coordinator;
    const auto writer = [this](const QString &tempPath, QString *error) {
        return writeEditedPdfCopy(tempPath, error);
    };

    const QString localOutput = toLocalPath(outputPath);
    const QString localSource = toLocalPath(m_filePath);
    const bool replaceOriginal = incremental
        || QFileInfo(localOutput).canonicalFilePath() == QFileInfo(localSource).canonicalFilePath();

    const PdfSaveCoordinator::SaveResult result = replaceOriginal
        ? coordinator.replaceOriginalTransaction(localSource, writer, true)
        : coordinator.saveAsCopy(localOutput, writer);

    if (!result.ok) {
        emit saveError(result.error);
        return false;
    }

    m_hasPendingEdits = false;
    emit pendingEditsChanged();
    emit saveCompleted(result.finalPath);
    return true;
}

void PdfEditSessionController::handleKeyText(const QString &text)
{
    if (!m_active || text.isEmpty())
        return;
    updateActiveText(m_activeText + text);
}

void PdfEditSessionController::handleBackspace()
{
    if (!m_active || m_activeText.isEmpty())
        return;
    QString next = m_activeText;
    next.chop(1);
    updateActiveText(next);
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
    m_activeRegionIndex = -1;
    for (int i = 0; i < m_pageText.regions.size(); ++i) {
        if (m_pageText.regions.at(i).box.adjusted(-2, -2, 2, 2).contains(point)) {
            m_activeRegionIndex = i;
            break;
        }
    }

    if (m_activeRegionIndex < 0) {
        if (m_active) {
            m_active = false;
            emit activeChanged();
        }
        return;
    }

    const PdfEditableRegion &region = m_pageText.regions.at(m_activeRegionIndex);
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
    m_active = true;
    rebuildSelectionJson();
    emit activeTextChanged();
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

void PdfEditSessionController::regenerateEditLayer()
{
    if (!m_active || m_activeText == m_originalActiveText || m_pixelSize.isEmpty()) {
        m_editLayerImage = {};
        emit editLayerImageChanged();
        return;
    }

    QString error;
    QImage base = m_scratchRenderer.renderRedactedBase(m_filePath,
                                                       m_password,
                                                       m_currentPageIndex,
                                                       activeRedactionQuads(),
                                                       m_scale,
                                                       &error);
    if (base.isNull()) {
        setStatusMessage(error);
        return;
    }

    QImage overlay = m_scratchRenderer.renderGlyphOverlay(activeReplacementRuns(),
                                                          m_fontResolver,
                                                          m_filePath,
                                                          m_password,
                                                          m_pixelSize,
                                                          m_scale,
                                                          &error);
    if (!overlay.isNull()) {
        QPainter painter(&base);
        painter.drawImage(QPoint(0, 0), overlay);
    }

    m_editLayerImage = base;
    emit editLayerImageChanged();
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
        run.wmode = glyph.wmode;
        run.bidiLevel = glyph.bidiLevel;
        run.direction = glyph.direction;
        run.trm = glyph.trm;
    }
    replacementRuns.append(run);
    return replacementRuns;
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
    for (int i = first; i < end; ++i)
        quads.append(m_pageText.glyphs.at(i).quad);
    return quads;
}

bool PdfEditSessionController::writeEditedPdfCopy(const QString &tempPath, QString *error) const
{
    const QVector<PdfRun> replacementRuns = activeReplacementRuns();
    const QVector<QPolygonF> redactionQuads = activeRedactionQuads();
    if (replacementRuns.isEmpty() || redactionQuads.isEmpty()) {
        if (error)
            *error = QStringLiteral("No hay una region editable activa para guardar.");
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

        page = pdf_load_page(ctx, pdfDoc, m_currentPageIndex);
        for (const QPolygonF &quad : redactionQuads) {
            const fz_quad fzQuad = toFzQuad(quad);
            pdf_annot *annot = pdf_create_annot(ctx, page, PDF_ANNOT_REDACT);
            pdf_set_annot_rect(ctx, annot, fz_rect_from_quad(fzQuad));
            pdf_set_annot_quad_points(ctx, annot, 1, &fzQuad);
        }

        pdf_redact_options redactionOptions = {};
        redactionOptions.black_boxes = 0;
        redactionOptions.image_method = PDF_REDACT_IMAGE_NONE;
        redactionOptions.line_art = PDF_REDACT_LINE_ART_NONE;
        redactionOptions.text = PDF_REDACT_TEXT_REMOVE;
        pdf_redact_page(ctx, pdfDoc, page, &redactionOptions);

        PdfContentWriter contentWriter;
        for (const PdfRun &run : replacementRuns) {
            QString localError;
            const QString resourceName = ensureWritableFontResource(ctx,
                                                                    pdfDoc,
                                                                    page,
                                                                    resourceNameFromKey(run.fontResourceKey),
                                                                    &localError);
            if (resourceName.isEmpty())
                fz_throw(ctx, FZ_ERROR_GENERIC, localError.toUtf8().constData());

            const PdfContentWriter::StreamBuildResult stream =
                contentWriter.buildReplacementTextStream(run, m_activeText, resourceName);
            if (stream.contentStream.isEmpty())
                fz_throw(ctx, FZ_ERROR_GENERIC, "Replacement text stream was empty.");
            appendContentStream(ctx, pdfDoc, page, stream.contentStream);
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
