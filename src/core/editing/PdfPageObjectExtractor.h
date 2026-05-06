#pragma once

#include "PdfTextRun.h"

#include <QList>
#include <QString>

#include <fpdf_edit.h>
#include <fpdf_text.h>
#include <fpdfview.h>

namespace PDFClowne::Editing {

class PdfPageObjectExtractor {
public:
    explicit PdfPageObjectExtractor(FPDF_DOCUMENT doc);

    QList<PdfTextRun> extractTextRunsFromPage(int pageNumber);

private:
    FPDF_DOCUMENT m_doc = nullptr;

    PdfTextRun extractRun(FPDF_PAGEOBJECT obj, FPDF_TEXTPAGE textPage, int idx);
    QString readUnicodeString(FPDF_PAGEOBJECT obj, FPDF_TEXTPAGE textPage);
};

} // namespace PDFClowne::Editing
