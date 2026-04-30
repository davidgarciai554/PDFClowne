#pragma once

#include <QObject>
#include <QPointF>
#include <QString>
#include <QStringList>
#include <memory>

class PdfDocument : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString filePath READ filePath NOTIFY filePathChanged)
    Q_PROPERTY(QString previewSource READ previewSource NOTIFY previewSourceChanged)
    Q_PROPERTY(QStringList pageSources READ pageSources NOTIFY pageSourcesChanged)
    Q_PROPERTY(QStringList thumbnailSources READ thumbnailSources NOTIFY thumbnailSourcesChanged)
    Q_PROPERTY(QString pageSizesJson READ pageSizesJson NOTIFY pageSizesJsonChanged)
    Q_PROPERTY(QString outlineJson READ outlineJson NOTIFY outlineJsonChanged)
    Q_PROPERTY(QString pageLinksJson READ pageLinksJson NOTIFY pageLinksJsonChanged)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY pageCountChanged)
    Q_PROPERTY(qint64 fileSizeBytes READ fileSizeBytes NOTIFY fileSizeBytesChanged)
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(bool isLoaded READ isLoaded NOTIFY isLoadedChanged)
    Q_PROPERTY(bool passwordRequired READ passwordRequired NOTIFY passwordRequiredChanged)
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY passwordChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString selectionText READ selectionText NOTIFY selectionChanged)
    Q_PROPERTY(QString selectionGeometryJson READ selectionGeometryJson NOTIFY selectionChanged)
    Q_PROPERTY(int selectionPage READ selectionPage NOTIFY selectionChanged)

public:
    explicit PdfDocument(QObject *parent = nullptr);
    ~PdfDocument() override;

    QString filePath() const { return m_filePath; }
    QString previewSource() const { return m_previewSource; }
    QStringList pageSources() const { return m_pageSources; }
    QStringList thumbnailSources() const { return m_thumbnailSources; }
    QString pageSizesJson() const { return m_pageSizesJson; }
    QString outlineJson() const { return m_outlineJson; }
    QString pageLinksJson() const { return m_pageLinksJson; }
    int pageCount() const { return m_pageCount; }
    qint64 fileSizeBytes() const { return m_fileSizeBytes; }
    QString title() const { return m_title; }
    bool isLoaded() const { return m_isLoaded; }
    bool passwordRequired() const { return m_passwordRequired; }
    QString password() const { return m_password; }
    QString errorMessage() const { return m_errorMessage; }
    QString selectionText() const { return m_selectionText; }
    QString selectionGeometryJson() const { return m_selectionGeometryJson; }
    int selectionPage() const { return m_selectionPage; }
    void setPassword(const QString &password);

public slots:
    bool load(const QString &source, const QString &password = {});
    Q_INVOKABLE bool retryWithPassword(const QString &password);
    QString renderPage(int pageIndex, qreal scale = 2.0);
    QString renderThumbnail(int pageIndex);
    QString searchPage(int pageIndex, const QString &query);
    QString searchDocument(const QString &query);
    QString extractPageText(int pageIndex);
    QString extractDocumentText();
    int resolveLinkPage(const QString &uri);
    bool saveRotatedCopy(const QString &source, const QString &target, const QString &rotationsJson);
    void beginSelection(int pageIndex, const QPointF &point);
    void updateSelection(int pageIndex, const QPointF &point);
    void endSelection();
    void clearSelection();
    void clear();

signals:
    void loaded();
    void loadFailed(const QString &error);

    void filePathChanged();
    void previewSourceChanged();
    void pageSourcesChanged();
    void thumbnailSourcesChanged();
    void pageSizesJsonChanged();
    void outlineJsonChanged();
    void pageLinksJsonChanged();
    void pageCountChanged();
    void fileSizeBytesChanged();
    void titleChanged();
    void isLoadedChanged();
    void passwordRequiredChanged();
    void passwordChanged();
    void errorMessageChanged();
    void selectionChanged();

private:
    class PdfEngine;

    void rebuildNavigationData();
    void setSelectionState(const QString &text, const QString &geometryJson, int pageIndex);

    QString m_filePath;
    QString m_previewSource;
    QStringList m_pageSources;
    QStringList m_thumbnailSources;
    QString m_pageSizesJson;
    QString m_outlineJson;
    QString m_pageLinksJson;
    QString m_title;
    QString m_password;
    QString m_errorMessage;
    QString m_selectionText;
    QString m_selectionGeometryJson = QStringLiteral("[]");
    int m_pageCount = 0;
    int m_selectionPage = -1;
    qint64 m_fileSizeBytes = 0;
    bool m_isLoaded = false;
    bool m_passwordRequired = false;
    bool m_selectionInProgress = false;
    QPointF m_selectionAnchor;
    std::unique_ptr<PdfEngine> m_engine;
};
