#pragma once

#include "PdfTextBlock.h"

#include <QList>
#include <QObject>
#include <QString>

#include <fpdfview.h>

namespace PDFClowne::Editing {

class PdfExtractionWorker : public QObject {
    Q_OBJECT

public:
    PdfExtractionWorker(FPDF_DOCUMENT doc, int pageNumber, QObject* parent = nullptr);

public slots:
    void run();

signals:
    void progressChanged(int, const QString&);
    void finished(int, const QList<PdfTextBlock>&, bool);
    void failed(const QString&);

private:
    FPDF_DOCUMENT m_doc = nullptr;
    int m_pageNumber = -1;
};

} // namespace PDFClowne::Editing
