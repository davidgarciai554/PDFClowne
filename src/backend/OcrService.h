#pragma once

#include <QObject>
#include <QString>

class OcrService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ isAvailable CONSTANT)

public:
    explicit OcrService(QObject *parent = nullptr);

    Q_INVOKABLE bool isAvailable() const;
    Q_INVOKABLE QString engineName() const;
    Q_INVOKABLE bool shouldOfferOcr(const QString &editableLayoutJson) const;
};
