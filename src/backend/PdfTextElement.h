#pragma once

#include <QColor>
#include <QJsonArray>
#include <QJsonObject>
#include <QRectF>
#include <QString>

struct PdfTextElement {
    enum class Kind {
        Span,
        Line,
        Block,
        Heading,
        Subheading,
        Paragraph,
        Annotation
    };

    QString id;
    int pageIndex = -1;
    Kind kind = Kind::Block;
    QRectF bboxPdf;
    QString text;
    QString fontName;
    double fontSize = 0.0;
    QColor color = Qt::black;
    double rotation = 0.0;
    QString sourceRef;
    bool editable = true;
    QJsonArray spans;
    QJsonArray lines;
    QJsonObject source;

    static QString kindName(Kind kind)
    {
        switch (kind) {
        case Kind::Span: return QStringLiteral("span");
        case Kind::Line: return QStringLiteral("line");
        case Kind::Heading: return QStringLiteral("heading");
        case Kind::Subheading: return QStringLiteral("subheading");
        case Kind::Paragraph: return QStringLiteral("paragraph");
        case Kind::Annotation: return QStringLiteral("annotation");
        case Kind::Block:
        default: return QStringLiteral("block");
        }
    }

    static QRectF rectFromJson(const QJsonObject &rect)
    {
        return QRectF(rect.value(QStringLiteral("x")).toDouble(),
                      rect.value(QStringLiteral("y")).toDouble(),
                      rect.value(QStringLiteral("width")).toDouble(),
                      rect.value(QStringLiteral("height")).toDouble());
    }

    static QJsonObject rectToJson(const QRectF &rect)
    {
        QJsonObject object;
        object.insert(QStringLiteral("x"), rect.x());
        object.insert(QStringLiteral("y"), rect.y());
        object.insert(QStringLiteral("width"), rect.width());
        object.insert(QStringLiteral("height"), rect.height());
        return object;
    }

    QJsonObject toJson() const
    {
        QJsonObject object = source;
        object.insert(QStringLiteral("id"), id);
        object.insert(QStringLiteral("stableElementId"), id);
        object.insert(QStringLiteral("pageIndex"), pageIndex);
        object.insert(QStringLiteral("kind"), kindName(kind));
        object.insert(QStringLiteral("elementType"), QStringLiteral("text"));
        object.insert(QStringLiteral("editable"), editable);
        object.insert(QStringLiteral("bboxPdf"), rectToJson(bboxPdf));
        object.insert(QStringLiteral("rect"), rectToJson(bboxPdf));
        object.insert(QStringLiteral("text"), text);
        object.insert(QStringLiteral("fontName"), fontName);
        object.insert(QStringLiteral("fontFamily"), fontName);
        object.insert(QStringLiteral("fontSize"), fontSize);
        object.insert(QStringLiteral("color"), color.name(QColor::HexRgb).toUpper());
        object.insert(QStringLiteral("rotation"), rotation);
        object.insert(QStringLiteral("sourceRef"), sourceRef);
        object.insert(QStringLiteral("spans"), spans);
        object.insert(QStringLiteral("lines"), lines);
        return object;
    }
};
