#pragma once

#include <QObject>

class QThread;

class DocumentSearchWorker;

class DocumentSearchController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit DocumentSearchController(QObject *parent = nullptr);
    ~DocumentSearchController() override;

    bool busy() const { return m_busy; }

    Q_INVOKABLE void searchDocument(const QString &filePath, const QString &query, int requestId, const QString &password = QString());

signals:
    void requestSearch(const QString &filePath, const QString &query, int requestId, const QString &password);
    void searchCompleted(const QString &filePath, int requestId, const QString &query, const QString &resultsJson, bool canceled);
    void busyChanged();

private slots:
    void handleSearchCompleted(const QString &filePath, int requestId, const QString &query, const QString &resultsJson, bool canceled);

private:
    void setBusy(bool busy);

    QThread *m_workerThread = nullptr;
    DocumentSearchWorker *m_worker = nullptr;
    bool m_busy = false;
};
