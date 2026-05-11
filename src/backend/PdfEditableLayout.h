#pragma once

#include "PdfTextElement.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QSizeF>
#include <QVector>

class PdfEditableLayout
{
    Q_GADGET

public:
    int pageIndex = -1;
    QSizeF pageSizePdf;
    QVector<PdfTextElement> elements;
    bool ocrCandidate = false;
    QString ocrReason;

    static PdfEditableLayout fromJsonElements(int pageIndex, const QJsonArray &sourceElements);

    QJsonArray elementsJson() const;
    QJsonObject toJson() const;
    void markOcrCandidate(const QString &reason);
};
