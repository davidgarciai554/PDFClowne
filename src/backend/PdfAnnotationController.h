#pragma once

#include <QJsonArray>
#include <QObject>
#include <QString>

class PdfAnnotationController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString annotationsJson READ annotationsJson NOTIFY annotationsChanged)

public:
    explicit PdfAnnotationController(QObject *parent = nullptr);

    QString annotationsJson() const;

    Q_INVOKABLE QString createAnnotation(const QString &type,
                                         int pageIndex,
                                         const QString &rectJson,
                                         const QString &styleJson = {});
    Q_INVOKABLE bool updateAnnotation(const QString &id, const QString &patchJson);
    Q_INVOKABLE bool removeAnnotation(const QString &id);
    Q_INVOKABLE void setAnnotationsJson(const QString &annotationsJson);
    Q_INVOKABLE void clear();

signals:
    void annotationsChanged();

private:
    QJsonArray m_annotations;
};
