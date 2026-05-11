#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QRectF>
#include <QString>
#include <QVector>

class PdfEditCommand
{
public:
    QString type;
    QJsonObject payload;

    QJsonObject toJson() const;
    static PdfEditCommand fromJson(const QJsonObject &object);
    static PdfEditCommand editTextCommand(const QString &blockId,
                                          const QString &beforeText,
                                          const QString &afterText);
    static PdfEditCommand resizeBlockCommand(const QString &blockId,
                                             const QRectF &beforeRect,
                                             const QRectF &afterRect);
    static PdfEditCommand moveBlockCommand(const QString &blockId,
                                           const QRectF &beforeRect,
                                           const QRectF &afterRect);
    static PdfEditCommand deleteBlockCommand(const QString &blockId,
                                             const QJsonObject &deletedBlock);
    static PdfEditCommand changeStyleCommand(const QString &blockId,
                                             const QJsonObject &beforeStyle,
                                             const QJsonObject &afterStyle);
};

class PdfUndoStack
{
public:
    void push(const PdfEditCommand &command);
    QJsonObject undo();
    QJsonObject redo();
    void clear();
    bool canUndo() const;
    bool canRedo() const;
    bool isDirty() const;
    QString journalJson() const;
    void setJournalJson(const QString &json);

private:
    static bool canMerge(const PdfEditCommand &previous, const PdfEditCommand &next);
    static void mergeInto(PdfEditCommand *previous, const PdfEditCommand &next);

    QVector<PdfEditCommand> m_done;
    QVector<PdfEditCommand> m_undone;
};
