#pragma once

#include <QByteArray>
#include <QString>

namespace PDFClowne::Editing {

struct PdfFontWritePlan {
    QString resourceName;
    QByteArray encodedText;
    bool hexString = true;
    bool winAnsi = false;
    bool identityH = false;
    bool fallbackFont = false;
    QString debugFontName;
    qreal horizontalScale = 1.0;
    qreal effectiveFontSize = 0.0;
    qreal baselineAdjustment = 0.0;
};

} // namespace PDFClowne::Editing
