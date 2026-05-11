#pragma once

#include <QColor>
#include <QRectF>
#include <QString>

#include <array>

namespace PDFClowne::Editing {

struct PdfTextRun {
    int pageObjectIndex = -1;
    QString text;
    QRectF bboxPdf;
    QString fontName;
    double fontSize = 0.0;
    QColor color = Qt::black;
    double rotation = 0.0;
    std::array<double, 6> matrix { 1.0, 0.0, 0.0, 1.0, 0.0, 0.0 };
    int renderMode = 0;
    bool fontIsEmbedded = false;
    bool fontIsSubset = false;
    QString sourceKind = QStringLiteral("directPageText");
    QString editability = QStringLiteral("nativeEditable");
    QString editStrategy = QStringLiteral("nativeStreamRewrite");
    double unicodeQuality = 1.0;
    bool isEditable = true;
    QString nonEditableReason;
};

} // namespace PDFClowne::Editing
