#pragma once

#include "PdfEditCommand.h"

#include <QObject>
#include <QRectF>
#include <QString>

class PdfEditSession : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool dirty READ isDirty NOTIFY dirtyChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY undoAvailabilityChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY redoAvailabilityChanged)
    Q_PROPERTY(QString journalJson READ journalJson NOTIFY journalChanged)
    Q_PROPERTY(QString documentPath READ documentPath NOTIFY documentPathChanged)

public:
    explicit PdfEditSession(QObject *parent = nullptr);

    bool isDirty() const;
    bool canUndo() const;
    bool canRedo() const;
    QString journalJson() const;
    QString documentPath() const;

    Q_INVOKABLE void begin(const QString &documentPath);
    Q_INVOKABLE void addCommand(const QString &type, const QString &payloadJson);
    Q_INVOKABLE void addTextEditCommand(const QString &blockId,
                                        const QString &beforeText,
                                        const QString &afterText);
    Q_INVOKABLE void addResizeBlockCommand(const QString &blockId,
                                           const QRectF &beforeRect,
                                           const QRectF &afterRect);
    Q_INVOKABLE void addMoveBlockCommand(const QString &blockId,
                                         const QRectF &beforeRect,
                                         const QRectF &afterRect);
    Q_INVOKABLE void addDeleteBlockCommand(const QString &blockId,
                                           const QString &deletedBlockJson);
    Q_INVOKABLE void addChangeStyleCommand(const QString &blockId,
                                           const QString &beforeStyleJson,
                                           const QString &afterStyleJson);
    Q_INVOKABLE QString undo();
    Q_INVOKABLE QString redo();
    Q_INVOKABLE void setJournalJson(const QString &journalJson);
    Q_INVOKABLE void clear();

signals:
    void dirtyChanged();
    void undoAvailabilityChanged();
    void redoAvailabilityChanged();
    void journalChanged();
    void documentPathChanged();

private:
    void emitStateChanged();

    QString m_documentPath;
    PdfUndoStack m_undoStack;
};
