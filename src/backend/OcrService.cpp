#include "OcrService.h"

#include <QJsonDocument>
#include <QJsonObject>

OcrService::OcrService(QObject *parent)
    : QObject(parent)
{
}

bool OcrService::isAvailable() const
{
#ifdef PDFCLOWNE_ENABLE_OCR
    return false;
#else
    return false;
#endif
}

QString OcrService::engineName() const
{
    return QStringLiteral("none");
}

bool OcrService::shouldOfferOcr(const QString &editableLayoutJson) const
{
    const QJsonObject layout = QJsonDocument::fromJson(editableLayoutJson.toUtf8()).object();
    return layout.value(QStringLiteral("ocrCandidate")).toBool(false);
}
