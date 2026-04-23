#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class PdfDocument : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString filePath READ filePath NOTIFY filePathChanged)
    Q_PROPERTY(QString previewSource READ previewSource NOTIFY previewSourceChanged)
    Q_PROPERTY(QStringList pageSources READ pageSources NOTIFY pageSourcesChanged)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY pageCountChanged)
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(bool isLoaded READ isLoaded NOTIFY isLoadedChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit PdfDocument(QObject *parent = nullptr);

    QString filePath() const { return m_filePath; }
    QString previewSource() const { return m_previewSource; }
    QStringList pageSources() const { return m_pageSources; }
    int pageCount() const { return m_pageCount; }
    QString title() const { return m_title; }
    bool isLoaded() const { return m_isLoaded; }
    QString errorMessage() const { return m_errorMessage; }

public slots:
    bool load(const QString &source);
    bool saveRotatedCopy(const QString &source, const QString &target, const QString &rotationsJson);
    void clear();

signals:
    void loaded();
    void loadFailed(const QString &error);

    void filePathChanged();
    void previewSourceChanged();
    void pageSourcesChanged();
    void pageCountChanged();
    void titleChanged();
    void isLoadedChanged();
    void errorMessageChanged();

private:
    QString m_filePath;
    QString m_previewSource;
    QStringList m_pageSources;
    QString m_title;
    QString m_errorMessage;
    int m_pageCount = 0;
    bool m_isLoaded = false;
};
