#include "PdfEditableLayout.h"

#include <algorithm>

namespace {

double elementFontSize(const QJsonObject &object)
{
    return object.value(QStringLiteral("fontSize")).toDouble(0.0);
}

PdfTextElement::Kind classifyBlock(const QJsonObject &object, double averageFontSize)
{
    const double size = elementFontSize(object);
    const int lineCount = object.value(QStringLiteral("lineCount")).toInt(
        object.value(QStringLiteral("lines")).toArray().size());
    const double height = object.value(QStringLiteral("rect")).toObject().value(QStringLiteral("height")).toDouble(0.0);

    if (averageFontSize > 0.0 && size >= averageFontSize * 1.22 && lineCount <= 2)
        return PdfTextElement::Kind::Heading;
    if (averageFontSize > 0.0 && size >= averageFontSize * 1.10 && lineCount <= 3)
        return PdfTextElement::Kind::Subheading;
    if (lineCount > 1 || height > size * 1.6)
        return PdfTextElement::Kind::Paragraph;
    return PdfTextElement::Kind::Block;
}

} // namespace

PdfEditableLayout PdfEditableLayout::fromJsonElements(int pageIndex, const QJsonArray &sourceElements)
{
    PdfEditableLayout layout;
    layout.pageIndex = pageIndex;

    double fontSizeSum = 0.0;
    int fontSizeCount = 0;
    for (const QJsonValue &value : sourceElements) {
        const QJsonObject object = value.toObject();
        const double size = elementFontSize(object);
        if (size > 0.0) {
            fontSizeSum += size;
            ++fontSizeCount;
        }
    }
    const double averageFontSize = fontSizeCount > 0 ? fontSizeSum / fontSizeCount : 0.0;

    for (const QJsonValue &value : sourceElements) {
        const QJsonObject object = value.toObject();
        if (object.value(QStringLiteral("elementType")).toString(QStringLiteral("text")) != QStringLiteral("text"))
            continue;

        PdfTextElement element;
        element.source = object;
        element.id = object.value(QStringLiteral("stableElementId")).toString(
            object.value(QStringLiteral("blockKey")).toString());
        element.pageIndex = object.value(QStringLiteral("pageIndex")).toInt(pageIndex);
        element.kind = classifyBlock(object, averageFontSize);
        element.bboxPdf = PdfTextElement::rectFromJson(object.value(QStringLiteral("rect")).toObject());
        element.text = object.value(QStringLiteral("text")).toString();
        element.fontName = object.value(QStringLiteral("fontFaceName")).toString(
            object.value(QStringLiteral("fontFamily")).toString());
        element.fontSize = elementFontSize(object);
        const QColor parsedColor(object.value(QStringLiteral("color")).toString());
        element.color = parsedColor.isValid() ? parsedColor : QColor(Qt::black);
        element.rotation = object.value(QStringLiteral("rotation")).toDouble(0.0);
        element.sourceRef = object.value(QStringLiteral("fontResourceName")).toString(
            object.value(QStringLiteral("blockKey")).toString(element.id));
        element.editable = object.value(QStringLiteral("editable")).toBool(true);
        element.spans = object.value(QStringLiteral("spans")).toArray();
        element.lines = object.value(QStringLiteral("lines")).toArray();
        layout.elements.append(element);
    }

    if (layout.elements.isEmpty())
        layout.markOcrCandidate(QStringLiteral("no-native-text-elements"));

    return layout;
}

QJsonArray PdfEditableLayout::elementsJson() const
{
    QJsonArray array;
    for (const PdfTextElement &element : elements)
        array.append(element.toJson());
    return array;
}

QJsonObject PdfEditableLayout::toJson() const
{
    QJsonObject object;
    object.insert(QStringLiteral("pageIndex"), pageIndex);
    object.insert(QStringLiteral("ocrCandidate"), ocrCandidate);
    object.insert(QStringLiteral("ocrReason"), ocrReason);
    object.insert(QStringLiteral("elements"), elementsJson());
    object.insert(QStringLiteral("textElementCount"), elements.size());
    return object;
}

void PdfEditableLayout::markOcrCandidate(const QString &reason)
{
    ocrCandidate = true;
    ocrReason = reason;
}
