#include "../../src/backend/render/PdfScratchPageRenderer.h"
#include "../../src/backend/pdf/PdfContentWriter.h"
#include "../../src/backend/pdf/PdfFontWritePlan.h"
#include "../../src/backend/text/PdfEditSessionController.h"

#include <QCoreApplication>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRect>
#include <QString>

#include <cmath>
#include <iostream>
#include <limits>

namespace {

int fail(const QString &message)
{
    std::cerr << message.toStdString() << '\n';
    return 1;
}

QRect scaledBoxRect(const QJsonObject &box, qreal scale, const QSize &bounds)
{
    const qreal x = box.value(QStringLiteral("x")).toDouble() * scale;
    const qreal y = box.value(QStringLiteral("y")).toDouble() * scale;
    const qreal width = box.value(QStringLiteral("width")).toDouble() * scale;
    const qreal height = box.value(QStringLiteral("height")).toDouble() * scale;
    QRect rect(std::floor(x) - 64,
               std::floor(y) - 64,
               std::ceil(width) + 128,
               std::ceil(height) + 128);
    return rect.intersected(QRect(QPoint(0, 0), bounds));
}

QRect scaledQuadRect(const QJsonArray &quad, qreal scale, const QSize &bounds)
{
    if (quad.size() < 4)
        return QRect();

    qreal minX = std::numeric_limits<qreal>::max();
    qreal minY = std::numeric_limits<qreal>::max();
    qreal maxX = std::numeric_limits<qreal>::lowest();
    qreal maxY = std::numeric_limits<qreal>::lowest();
    for (const QJsonValue &value : quad) {
        const QJsonArray point = value.toArray();
        if (point.size() < 2)
            continue;
        const qreal x = point.at(0).toDouble() * scale;
        const qreal y = point.at(1).toDouble() * scale;
        minX = std::min(minX, x);
        minY = std::min(minY, y);
        maxX = std::max(maxX, x);
        maxY = std::max(maxY, y);
    }

    QRect rect(std::floor(minX) - 64,
               std::floor(minY) - 64,
               std::ceil(maxX - minX) + 128,
               std::ceil(maxY - minY) + 128);
    return rect.intersected(QRect(QPoint(0, 0), bounds));
}

bool pixelsDiffer(const QRgb left, const QRgb right)
{
    return std::abs(qRed(left) - qRed(right)) > 1
        || std::abs(qGreen(left) - qGreen(right)) > 1
        || std::abs(qBlue(left) - qBlue(right)) > 1
        || std::abs(qAlpha(left) - qAlpha(right)) > 1;
}

bool diffOnlyInside(const QImage &original, const QImage &edited, const QRect &allowed)
{
    if (original.size() != edited.size() || original.isNull() || edited.isNull())
        return false;

    const QImage left = original.convertToFormat(QImage::Format_RGBA8888);
    const QImage right = edited.convertToFormat(QImage::Format_RGBA8888);
    for (int y = 0; y < left.height(); ++y) {
        const QRgb *leftLine = reinterpret_cast<const QRgb *>(left.constScanLine(y));
        const QRgb *rightLine = reinterpret_cast<const QRgb *>(right.constScanLine(y));
        for (int x = 0; x < left.width(); ++x) {
            if (!allowed.contains(x, y) && pixelsDiffer(leftLine[x], rightLine[x]))
                return false;
        }
    }
    return true;
}

QString mutateFirstCharacter(const QString &text)
{
    if (text.isEmpty())
        return QStringLiteral("X");

    QString next = text;
    next[0] = text.at(0) == QLatin1Char('X') ? QChar(QLatin1Char('Y')) : QChar(QLatin1Char('X'));
    return next;
}

} // namespace

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);

    if (app.arguments().size() < 2)
        return fail(QStringLiteral("Usage: PdfEditSessionVisualSnapshotTest <pdf>"));

    const QString pdfPath = app.arguments().at(1);
    const QVector<qreal> scales{1.0, 1.25, 1.5, 2.0};

    PDFClowne::Editing::PdfEditSessionController probe;
    if (!probe.loadDocument(pdfPath) || !probe.extractPage(0))
        return fail(QStringLiteral("Could not extract glyph regions from fixture PDF."));

    const QJsonArray regions = QJsonDocument::fromJson(probe.editableRegionsJson().toUtf8()).array();
    if (regions.isEmpty())
        return fail(QStringLiteral("Fixture PDF did not expose any editable regions."));

    const QPointF pdfBaseline =
        PDFClowne::Editing::PdfContentWriter::visualBaselineToPdfBaseline(QPointF(100.0, 300.0), 842.0);
    if (std::abs(pdfBaseline.x() - 100.0) > 0.001 || std::abs(pdfBaseline.y() - 542.0) > 0.001)
        return fail(QStringLiteral("visualBaselineToPdfBaseline must convert Y once into PDF user space."));

    const QRectF pdfRect =
        PDFClowne::Editing::PdfContentWriter::visualRectToPdfRect(QRectF(100.0, 280.0, 300.0, 20.0), 842.0);
    if (std::abs(pdfRect.x() - 100.0) > 0.001
            || std::abs(pdfRect.y() - 542.0) > 0.001
            || std::abs(pdfRect.width() - 300.0) > 0.001
            || std::abs(pdfRect.height() - 20.0) > 0.001) {
        return fail(QStringLiteral("visualRectToPdfRect must preserve size and convert visual bottom to PDF Y."));
    }

    PDFClowne::Editing::PdfRun exportRun;
    PDFClowne::Editing::PdfGlyph exportGlyph;
    exportGlyph.pageIndex = 0;
    exportGlyph.origin = QPointF(100.0, 300.0);
    exportGlyph.bbox = QRectF(100.0, 286.0, 80.0, 18.0);
    exportGlyph.quad << QPointF(100.0, 286.0)
                     << QPointF(180.0, 286.0)
                     << QPointF(180.0, 304.0)
                     << QPointF(100.0, 304.0);
    exportGlyph.advance = QPointF(7.0, 0.0);
    exportGlyph.fontSize = 12.0;
    exportGlyph.trm = QTransform(12.0, 0.0, 0.0, 12.0, 100.0, 300.0);
    exportRun.glyphs.append(exportGlyph);
    exportRun.plainText = QStringLiteral("ABC");
    exportRun.direction = QPointF(1.0, 0.0);
    PDFClowne::Editing::PdfFontWritePlan plan;
    plan.resourceName = QStringLiteral("Fpdfclowne");
    plan.encodedText = QByteArrayLiteral("ABC");
    plan.hexString = false;
    const QByteArray stream = PDFClowne::Editing::PdfContentWriter()
        .buildReplacementTextStream(exportRun, QStringLiteral("ABC"), plan, 842.0)
        .contentStream;
    if (!stream.contains("12 Tf"))
        return fail(QStringLiteral("Export stream must use the original font size in PDF points."));
    if (!stream.contains("1 0 0 1 100 542 Tm"))
        return fail(QStringLiteral("Export stream must use unscaled PDF baseline coordinates, not scaled preview matrix."));
    if (stream.contains("12 0 0 12 100 300 Tm"))
        return fail(QStringLiteral("Export stream must not write the preview/text extraction matrix as the PDF Tm."));

    const QJsonObject firstRegion = regions.first().toObject();
    const QJsonObject box = firstRegion.value(QStringLiteral("box")).toObject();
    const qreal pageX = box.value(QStringLiteral("x")).toDouble()
        + box.value(QStringLiteral("width")).toDouble() / 2.0;
    const qreal pageY = box.value(QStringLiteral("y")).toDouble()
        + box.value(QStringLiteral("height")).toDouble() / 2.0;

    PDFClowne::Editing::PdfEditSessionController orderController;
    if (!orderController.loadDocument(pdfPath))
        return fail(QStringLiteral("Could not load fixture for text order verification."));
    QString orderError;
    PDFClowne::Render::PdfScratchPageRenderer renderer;
    const QImage orderOriginal = renderer.renderRedactedBase(pdfPath, QString(), 0, {}, 1.0, &orderError);
    if (orderOriginal.isNull())
        return fail(QStringLiteral("Could not render fixture for text order verification: %1").arg(orderError));
    if (!orderController.beginSession(0, pageX, pageY, orderOriginal.width(), orderOriginal.height(), 1.0))
        return fail(QStringLiteral("Could not begin edit session for text order verification."));
    for (const QChar ch : QStringLiteral("DAVID"))
        orderController.handleKeyText(QString(ch));
    if (orderController.activeText() != QLatin1String("DAVID"))
        return fail(QStringLiteral("Editable text input order regressed. Expected DAVID, got %1.")
                        .arg(orderController.activeText()));
    if (orderController.activeText() == QLatin1String("DIVAD"))
        return fail(QStringLiteral("Editable text was inserted in reverse order."));
    orderController.handleBackspace();
    if (orderController.activeText() != QLatin1String("DAVI"))
        return fail(QStringLiteral("Backspace must remove the character before the cursor after ordered input."));

    for (qreal scale : scales) {
        QString error;
        const QImage original = renderer.renderRedactedBase(pdfPath, QString(), 0, {}, scale, &error);
        if (original.isNull())
            return fail(QStringLiteral("Could not render original page at scale %1: %2").arg(scale).arg(error));

        PDFClowne::Editing::PdfEditSessionController controller;
        if (!controller.loadDocument(pdfPath))
            return fail(QStringLiteral("Could not load fixture into edit session."));
        if (!controller.beginSession(0, pageX, pageY, original.width(), original.height(), scale))
            return fail(QStringLiteral("Could not begin edit session at scale %1.").arg(scale));

        const QJsonArray selectionQuads = QJsonDocument::fromJson(
            controller.selectionQuadsJson().toUtf8()).array();
        const QRect allowedDiff = selectionQuads.isEmpty()
            ? scaledBoxRect(box, scale, original.size())
            : scaledQuadRect(selectionQuads.first().toArray(), scale, original.size());

        const QImage activePreview = controller.editLayerImage();
        if (activePreview.isNull())
            return fail(QStringLiteral("Active edit session must render visual feedback at scale %1.").arg(scale));

        if (!diffOnlyInside(original, activePreview, allowedDiff))
            return fail(QStringLiteral("Active edit preview diff escaped the active region at scale %1.").arg(scale));

        controller.updateActiveText(mutateFirstCharacter(controller.activeText()));
        const QImage edited = controller.editLayerImage();
        if (edited.isNull())
            return fail(QStringLiteral("After mutation the edit layer must render at scale %1.").arg(scale));

        if (!diffOnlyInside(original, edited, allowedDiff))
            return fail(QStringLiteral("Edited diff escaped the active region at scale %1.").arg(scale));

        if (!controller.commitActiveText())
            return fail(QStringLiteral("Enter/commit did not confirm the active edit at scale %1.").arg(scale));

        if (controller.isActive())
            return fail(QStringLiteral("Commit left the edit session active at scale %1.").arg(scale));

        if (!controller.hasConfirmedEdits(0))
            return fail(QStringLiteral("Commit did not persist a confirmed edit at scale %1.").arg(scale));

        const QImage committed = controller.editLayerImage();
        if (committed.isNull())
            return fail(QStringLiteral("Committed edit layer disappeared at scale %1.").arg(scale));

        if (!diffOnlyInside(original, committed, allowedDiff))
            return fail(QStringLiteral("Committed edit diff escaped the active region at scale %1.").arg(scale));

        if (committed != edited && !diffOnlyInside(edited, committed, allowedDiff))
            return fail(QStringLiteral("Committed edit repaint moved outside the active region at scale %1.").arg(scale));

        controller.extractPage(0);
        controller.updatePageViewMetrics(0, original.width(), original.height(), scale);
        const QImage regenerated = controller.editLayerImage();
        if (regenerated.isNull())
            return fail(QStringLiteral("Confirmed edit did not survive page extraction/regeneration at scale %1.").arg(scale));

        if (!diffOnlyInside(original, regenerated, allowedDiff))
            return fail(QStringLiteral("Regenerated confirmed edit diff escaped the active region at scale %1.").arg(scale));
    }

    // Confirmed edits must survive clearSession (simulates overlay unmount in view mode).
    PDFClowne::Editing::PdfEditSessionController viewModeController;
    if (!viewModeController.loadDocument(pdfPath))
        return fail(QStringLiteral("Could not load fixture for view-mode persistence verification."));
    QString viewModeError;
    const QImage viewModeBase = renderer.renderRedactedBase(pdfPath, QString(), 0, {}, 1.0, &viewModeError);
    if (viewModeBase.isNull())
        return fail(QStringLiteral("Could not render fixture for view-mode persistence: %1").arg(viewModeError));
    if (!viewModeController.beginSession(0, pageX, pageY, viewModeBase.width(), viewModeBase.height(), 1.0))
        return fail(QStringLiteral("Could not begin edit session for view-mode persistence test."));
    viewModeController.updateActiveText(QStringLiteral("VIEW MODE TEST"));
    if (!viewModeController.commitActiveText())
        return fail(QStringLiteral("Commit failed in view-mode persistence test."));
    if (!viewModeController.hasPendingEdits())
        return fail(QStringLiteral("hasPendingEdits must be true after commit."));
    viewModeController.clearSession();
    if (!viewModeController.hasPendingEdits())
        return fail(QStringLiteral("Confirmed edits must survive clearSession (view-mode switch simulation)."));
    viewModeController.updatePageViewMetrics(0, viewModeBase.width(), viewModeBase.height(), 1.0);
    if (viewModeController.editLayerImage().isNull())
        return fail(QStringLiteral("editLayerImage must be non-null for confirmed edits in view mode."));

    PDFClowne::Editing::PdfEditSessionController clickOutsideController;
    if (!clickOutsideController.loadDocument(pdfPath))
        return fail(QStringLiteral("Could not load fixture for click-outside persistence verification."));
    if (!clickOutsideController.beginSession(0, pageX, pageY, viewModeBase.width(), viewModeBase.height(), 1.0))
        return fail(QStringLiteral("Could not begin edit session for click-outside persistence test."));
    clickOutsideController.updateActiveText(QStringLiteral("CLICK FUERA TEST"));
    const bool outsideStarted = clickOutsideController.beginSession(0,
                                                                    4.0,
                                                                    viewModeBase.height() - 4.0,
                                                                    viewModeBase.width(),
                                                                    viewModeBase.height(),
                                                                    1.0);
    if (outsideStarted)
        return fail(QStringLiteral("Click outside text unexpectedly started a new edit session."));
    if (!clickOutsideController.hasPendingEdits())
        return fail(QStringLiteral("Click outside must commit the active text edit before clearing selection."));
    if (clickOutsideController.editLayerImage().isNull())
        return fail(QStringLiteral("Click outside must leave confirmed edit layer visible."));

    if (regions.size() > 1) {
        const QJsonObject secondRegion = regions.at(1).toObject();
        const QJsonObject secondBox = secondRegion.value(QStringLiteral("box")).toObject();
        const qreal secondX = secondBox.value(QStringLiteral("x")).toDouble()
            + secondBox.value(QStringLiteral("width")).toDouble() / 2.0;
        const qreal secondY = secondBox.value(QStringLiteral("y")).toDouble()
            + secondBox.value(QStringLiteral("height")).toDouble() / 2.0;

        PDFClowne::Editing::PdfEditSessionController clickOtherTextController;
        if (!clickOtherTextController.loadDocument(pdfPath))
            return fail(QStringLiteral("Could not load fixture for click-other-text persistence verification."));
        if (!clickOtherTextController.beginSession(0, pageX, pageY, viewModeBase.width(), viewModeBase.height(), 1.0))
            return fail(QStringLiteral("Could not begin first edit session for click-other-text test."));
        clickOtherTextController.updateActiveText(QStringLiteral("PRIMERA EDICION"));
        if (!clickOtherTextController.beginSession(0, secondX, secondY, viewModeBase.width(), viewModeBase.height(), 1.0))
            return fail(QStringLiteral("Clicking another text line should start a second edit session."));
        if (!clickOtherTextController.hasPendingEdits())
            return fail(QStringLiteral("Clicking another text line must preserve the first confirmed edit."));
        clickOtherTextController.updateActiveText(QStringLiteral("SEGUNDA EDICION"));
        if (!clickOtherTextController.commitActiveText())
            return fail(QStringLiteral("Could not commit second edit after clicking another text line."));
        if (clickOtherTextController.editLayerImage().isNull())
            return fail(QStringLiteral("Multiple confirmed edits must keep a visible edit layer."));
    }

    PDFClowne::Editing::PdfEditSessionController cancelController;
    if (!cancelController.loadDocument(pdfPath))
        return fail(QStringLiteral("Could not load fixture for cancel verification."));
    const qreal cancelScale = 1.0;
    QString cancelError;
    const QImage cancelOriginal = renderer.renderRedactedBase(pdfPath, QString(), 0, {}, cancelScale, &cancelError);
    if (cancelOriginal.isNull())
        return fail(QStringLiteral("Could not render fixture for cancel verification: %1").arg(cancelError));
    if (!cancelController.beginSession(0, pageX, pageY, cancelOriginal.width(), cancelOriginal.height(), cancelScale))
        return fail(QStringLiteral("Could not begin edit session for cancel verification."));
    cancelController.updateActiveText(QStringLiteral("ESCAPE TEST"));
    cancelController.cancelActiveEdit();
    if (cancelController.isActive())
        return fail(QStringLiteral("Escape/cancel left the edit session active."));
    if (cancelController.hasConfirmedEdits(0))
        return fail(QStringLiteral("Escape/cancel created a confirmed edit."));

    return 0;
}
