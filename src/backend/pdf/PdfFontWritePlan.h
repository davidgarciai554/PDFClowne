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
};

} // namespace PDFClowne::Editing
