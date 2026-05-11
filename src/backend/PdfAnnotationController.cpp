#include "PdfAnnotationController.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>

PdfAnnotationController::PdfAnnotationController(QObject *parent)
    : QObject(parent)
{
}

QString PdfAnnotationController::annotationsJson() const
{
    return QString::fromUtf8(QJsonDocument(m_annotations).toJson(QJsonDocument::Compact));
}

QString PdfAnnotationController::createAnnotation(const QString &type,
                                                  int pageIndex,
                                                  const QString &rectJson,
                                                  const QString &styleJson)
{
    QJsonObject annotation = QJsonDocument::fromJson(styleJson.toUtf8()).object();
    annotation.insert(QStringLiteral("id"),
                      QStringLiteral("%1-%2").arg(type, QString::number(QDateTime::currentMSecsSinceEpoch())));
    annotation.insert(QStringLiteral("type"), type);
    annotation.insert(QStringLiteral("pageIndex"), pageIndex);
    annotation.insert(QStringLiteral("rect"), QJsonDocument::fromJson(rectJson.toUtf8()).object());
    m_annotations.append(annotation);
    emit annotationsChanged();
    return annotation.value(QStringLiteral("id")).toString();
}

bool PdfAnnotationController::updateAnnotation(const QString &id, const QString &patchJson)
{
    const QJsonObject patch = QJsonDocument::fromJson(patchJson.toUtf8()).object();
    for (int i = 0; i < m_annotations.size(); ++i) {
        QJsonObject annotation = m_annotations.at(i).toObject();
        if (annotation.value(QStringLiteral("id")).toString() != id)
            continue;

        for (auto it = patch.begin(); it != patch.end(); ++it)
            annotation.insert(it.key(), it.value());
        m_annotations.replace(i, annotation);
        emit annotationsChanged();
        return true;
    }
    return false;
}

bool PdfAnnotationController::removeAnnotation(const QString &id)
{
    for (int i = 0; i < m_annotations.size(); ++i) {
        if (m_annotations.at(i).toObject().value(QStringLiteral("id")).toString() != id)
            continue;

        m_annotations.removeAt(i);
        emit annotationsChanged();
        return true;
    }
    return false;
}

void PdfAnnotationController::setAnnotationsJson(const QString &annotationsJson)
{
    const QJsonDocument document = QJsonDocument::fromJson(annotationsJson.toUtf8());
    m_annotations = document.isArray() ? document.array() : QJsonArray();
    emit annotationsChanged();
}

void PdfAnnotationController::clear()
{
    if (m_annotations.isEmpty())
        return;

    m_annotations = QJsonArray();
    emit annotationsChanged();
}
