#include "../../src/backend/render/PdfScratchPageRenderer.h"
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

    const QJsonObject firstRegion = regions.first().toObject();
    const QJsonObject box = firstRegion.value(QStringLiteral("box")).toObject();
    const qreal pageX = box.value(QStringLiteral("x")).toDouble()
        + box.value(QStringLiteral("width")).toDouble() / 2.0;
    const qreal pageY = box.value(QStringLiteral("y")).toDouble()
        + box.value(QStringLiteral("height")).toDouble() / 2.0;

    PDFClowne::Render::PdfScratchPageRenderer renderer;
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

        if (!controller.editLayerImage().isNull())
            return fail(QStringLiteral("Before first mutation the edit layer must be empty at scale %1.").arg(scale));

        const QJsonArray selectionQuads = QJsonDocument::fromJson(
            controller.selectionQuadsJson().toUtf8()).array();
        const QRect allowedDiff = selectionQuads.isEmpty()
            ? scaledBoxRect(box, scale, original.size())
            : scaledQuadRect(selectionQuads.first().toArray(), scale, original.size());

        controller.updateActiveText(mutateFirstCharacter(controller.activeText()));
        const QImage edited = controller.editLayerImage();
        if (edited.isNull())
            return fail(QStringLiteral("After mutation the edit layer must render at scale %1.").arg(scale));

        if (!diffOnlyInside(original, edited, allowedDiff))
            return fail(QStringLiteral("Edited diff escaped the active region at scale %1.").arg(scale));
    }

    return 0;
}
