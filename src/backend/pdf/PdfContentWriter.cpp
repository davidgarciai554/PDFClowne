#include "PdfContentWriter.h"

#include <QLocale>

#include <cmath>

namespace PDFClowne::Editing {
namespace {

QByteArray number(qreal value)
{
    return QByteArray::number(value, 'f', 6).replace(QByteArray(".000000"), QByteArray());
}

} // namespace

QByteArray PdfContentWriter::escapedPdfString(const QString &text)
{
    QByteArray output;
    const QByteArray utf16 = QString(text).toUtf8();
    output.reserve(utf16.size() + 8);
    for (char ch : utf16) {
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
    const QString &writerFontResourceName) const
{
    StreamBuildResult result;
    result.fontResourceKey = run.fontResourceKey;
    if (run.glyphs.isEmpty() || newText.isEmpty() || writerFontResourceName.isEmpty())
        return result;

    const PdfGlyph &first = run.glyphs.constFirst();
    const QTransform &tm = first.trm;
    const qreal fontSize = std::max<qreal>(1.0, first.fontSize);

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
    stream.append(writerFontResourceName.toUtf8());
    stream.append(" ");
    stream.append(number(fontSize));
    stream.append(" Tf\n");
    stream.append(number(tm.m11()));
    stream.append(" ");
    stream.append(number(tm.m12()));
    stream.append(" ");
    stream.append(number(tm.m21()));
    stream.append(" ");
    stream.append(number(tm.m22()));
    stream.append(" ");
    stream.append(number(tm.dx()));
    stream.append(" ");
    stream.append(number(tm.dy()));
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
        stream.append("(");
        stream.append(escapedPdfString(newText));
        stream.append(") Tj\n");
    } else {
        result.usesTJ = true;
        stream.append("[(");
        stream.append(escapedPdfString(newText));
        stream.append(")] TJ\n");
    }

    stream.append("ET\n");
    stream.append("Q\n");
    result.contentStream = stream;
    return result;
}

} // namespace PDFClowne::Editing
