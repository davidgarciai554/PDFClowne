#include "PdfContentWriter.h"

#include <QDebug>

#include <QLocale>

#include <cmath>

namespace PDFClowne::Editing {
namespace {

QByteArray number(qreal value)
{
    return QByteArray::number(value, 'f', 6).replace(QByteArray(".000000"), QByteArray());
}

bool saveTraceEnabled()
{
    static const bool enabled = qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_SAVE")
        || qEnvironmentVariableIsSet("PDFCLOWNE_DEBUG_EDIT_INPUT");
    return enabled;
}

QPointF normalizedDirection(QPointF direction)
{
    const qreal length = std::hypot(direction.x(), direction.y());
    if (length <= 0.0001)
        return QPointF(1.0, 0.0);
    return direction / length;
}

} // namespace

QPointF PdfContentWriter::visualPointToPdfPoint(const QPointF &visualPoint, qreal pageHeight)
{
    return QPointF(visualPoint.x(), pageHeight - visualPoint.y());
}

QPointF PdfContentWriter::visualBaselineToPdfBaseline(const QPointF &visualBaseline, qreal pageHeight)
{
    return visualPointToPdfPoint(visualBaseline, pageHeight);
}

QRectF PdfContentWriter::visualRectToPdfRect(const QRectF &visualRect, qreal pageHeight)
{
    const QRectF r = visualRect.normalized();
    return QRectF(r.left(), pageHeight - r.bottom(), r.width(), r.height());
}

QRectF PdfContentWriter::expandVisualRedactionRect(const QRectF &visualRect, qreal fontSize)
{
    const QRectF r = visualRect.normalized();
    const qreal padX = std::max<qreal>(1.0, fontSize * 0.12);
    const qreal padTop = std::max<qreal>(1.0, fontSize * 0.20);
    const qreal padBottom = std::max<qreal>(1.0, fontSize * 0.30);
    return r.adjusted(-padX, -padTop, padX, padBottom);
}

QByteArray PdfContentWriter::buildRedactionCoverStream(const PdfRun &run,
                                                       qreal pageHeight,
                                                       const QString &editId) const
{
    Q_UNUSED(run)
    Q_UNUSED(pageHeight)
    if (saveTraceEnabled())
        qInfo().noquote() << QStringLiteral("[PDF_EXPORT_REDACT] coverStreamDisabled editId=%1").arg(editId);
    return {};
}

QByteArray PdfContentWriter::escapedPdfBytes(const QByteArray &text)
{
    QByteArray output;
    output.reserve(text.size() + 8);
    for (char ch : text) {
        switch (ch) {
        case '(':
        case ')':
        case '\\':
            output.append('\\');
            output.append(ch);
            break;
        case '\n':
            output.append("\\n");
            break;
        case '\r':
            output.append("\\r");
            break;
        case '\t':
            output.append("\\t");
            break;
        default:
            output.append(ch);
            break;
        }
    }
    return output;
}

PdfContentWriter::StreamBuildResult PdfContentWriter::buildReplacementTextStream(
    const PdfRun &run,
    const QString &newText,
    const PdfFontWritePlan &fontPlan,
    qreal pageHeight,
    const QString &editId) const
{
    StreamBuildResult result;
    result.fontResourceKey = run.fontResourceKey;
    if (run.glyphs.isEmpty() || newText.isEmpty() || fontPlan.resourceName.isEmpty() || fontPlan.encodedText.isEmpty())
        return result;

    const PdfGlyph &first = run.glyphs.constFirst();
    const qreal fontSize = std::max<qreal>(1.0, first.fontSize);
    QPointF pdfBaseline = visualBaselineToPdfBaseline(first.origin, pageHeight);
    const qreal textMatrixBaselineLift = fontPlan.fallbackFont ? fontSize * 0.75 : 0.0;
    pdfBaseline.ry() += textMatrixBaselineLift;
    const QPointF pdfDirection = QPointF(normalizedDirection(run.direction).x(),
                                         -normalizedDirection(run.direction).y());
    const QRectF visualRect = unionGlyphBoxes(run.glyphs, 0, run.glyphs.size()).normalized();
    const QRectF pdfRect = visualRectToPdfRect(visualRect, pageHeight);

    if (saveTraceEnabled()) {
        qInfo().noquote()
            << QStringLiteral("[PDF_EXPORT_WRITE_TEXT] pageIndex=%1 editId=%2 editedText=\"%3\" visualBaselineReceived=(%4,%5) pdfBaseline=(%6,%7) pageHeight=%8 fontName=\"%9\" fontSize=%10 textMatrix=(%11,%12,%13,%14,%15,%16) direction=(%17,%18) writingMode=%19 estimatedTextWidth=not-yet redactionRectWidth=%20 redactionRectHeight=%21 textMatrixBaselineLift=%22 zoomUsed=false devicePixelRatioUsed=false")
                   .arg(first.pageIndex)
                   .arg(editId)
                   .arg(newText.left(80))
                   .arg(first.origin.x())
                   .arg(first.origin.y())
                   .arg(pdfBaseline.x())
                   .arg(pdfBaseline.y())
                   .arg(pageHeight)
                   .arg(fontPlan.debugFontName)
                   .arg(fontSize)
                   .arg(pdfDirection.x())
                   .arg(pdfDirection.y())
                   .arg(-pdfDirection.y())
                   .arg(pdfDirection.x())
                   .arg(pdfBaseline.x())
                   .arg(pdfBaseline.y())
                   .arg(pdfDirection.x())
                   .arg(pdfDirection.y())
                   .arg(run.wmode)
                   .arg(pdfRect.width())
                   .arg(pdfRect.height())
                   .arg(textMatrixBaselineLift);
        if (fontSize > 30.0)
            qWarning().noquote() << QStringLiteral("[PDF_SAVE_ERROR] Suspicious text export fontPointSize=%1").arg(fontSize);
    }

    QByteArray stream;
    stream.append("q\n");
    stream.append(number(run.fillColor.redF()));
    stream.append(" ");
    stream.append(number(run.fillColor.greenF()));
    stream.append(" ");
    stream.append(number(run.fillColor.blueF()));
    stream.append(" rg\n");
    stream.append("BT\n");
    stream.append("/");
    stream.append(fontPlan.resourceName.toUtf8());
    stream.append(" ");
    stream.append(number(fontSize));
    stream.append(" Tf\n");
    stream.append(number(pdfDirection.x()));
    stream.append(" ");
    stream.append(number(pdfDirection.y()));
    stream.append(" ");
    stream.append(number(-pdfDirection.y()));
    stream.append(" ");
    stream.append(number(pdfDirection.x()));
    stream.append(" ");
    stream.append(number(pdfBaseline.x()));
    stream.append(" ");
    stream.append(number(pdfBaseline.y()));
    stream.append(" Tm\n");

    bool simpleAdvances = true;
    for (int i = 1; i < run.glyphs.size(); ++i) {
        const QPointF previous = run.glyphs.at(i - 1).origin + run.glyphs.at(i - 1).advance;
        const QPointF current = run.glyphs.at(i).origin;
        if (std::abs(previous.x() - current.x()) > 0.01 ||
            std::abs(previous.y() - current.y()) > 0.01) {
            simpleAdvances = false;
            break;
        }
    }

    if (simpleAdvances) {
        if (fontPlan.hexString) {
            stream.append("<");
            stream.append(fontPlan.encodedText.toHex().toUpper());
            stream.append("> Tj\n");
        } else {
            stream.append("(");
            stream.append(escapedPdfBytes(fontPlan.encodedText));
            stream.append(") Tj\n");
        }
    } else {
        result.usesTJ = true;
        if (fontPlan.hexString) {
            stream.append("[<");
            stream.append(fontPlan.encodedText.toHex().toUpper());
            stream.append(">] TJ\n");
        } else {
            stream.append("[(");
            stream.append(escapedPdfBytes(fontPlan.encodedText));
            stream.append(")] TJ\n");
        }
    }

    stream.append("ET\n");
    stream.append("Q\n");
    result.contentStream = stream;
    return result;
}

} // namespace PDFClowne::Editing
