#include "PdfEditSession.h"

#include <QJsonDocument>
#include <QJsonObject>

namespace {

QJsonObject jsonObjectFromString(const QString &json)
{
    const QJsonDocument document = QJsonDocument::fromJson(json.toUtf8());
    return document.isObject() ? document.object() : QJsonObject{};
}

} // namespace

PdfEditSession::PdfEditSession(QObject *parent)
    : QObject(parent)
{
}

bool PdfEditSession::isDirty() const
{
    return m_undoStack.isDirty();
}

bool PdfEditSession::canUndo() const
{
    return m_undoStack.canUndo();
}

bool PdfEditSession::canRedo() const
{
    return m_undoStack.canRedo();
}

QString PdfEditSession::journalJson() const
{
    return m_undoStack.journalJson();
}

QString PdfEditSession::documentPath() const
{
    return m_documentPath;
}

void PdfEditSession::begin(const QString &documentPath)
{
    if (m_documentPath == documentPath && !m_undoStack.isDirty())
        return;

    m_documentPath = documentPath;
    m_undoStack.clear();
    emit documentPathChanged();
    emitStateChanged();
}

void PdfEditSession::addCommand(const QString &type, const QString &payloadJson)
{
    QJsonObject payload = jsonObjectFromString(payloadJson);
    payload.insert(QStringLiteral("type"), type);

    PdfEditCommand command;
    command.type = type;
    command.payload = payload;
    m_undoStack.push(command);
    emitStateChanged();
}

void PdfEditSession::addTextEditCommand(const QString &blockId,
                                        const QString &beforeText,
                                        const QString &afterText)
{
    m_undoStack.push(PdfEditCommand::editTextCommand(blockId, beforeText, afterText));
    emitStateChanged();
}

void PdfEditSession::addResizeBlockCommand(const QString &blockId,
                                           const QRectF &beforeRect,
                                           const QRectF &afterRect)
{
    m_undoStack.push(PdfEditCommand::resizeBlockCommand(blockId, beforeRect, afterRect));
    emitStateChanged();
}

void PdfEditSession::addMoveBlockCommand(const QString &blockId,
                                         const QRectF &beforeRect,
                                         const QRectF &afterRect)
{
    m_undoStack.push(PdfEditCommand::moveBlockCommand(blockId, beforeRect, afterRect));
    emitStateChanged();
}

void PdfEditSession::addDeleteBlockCommand(const QString &blockId, const QString &deletedBlockJson)
{
    m_undoStack.push(PdfEditCommand::deleteBlockCommand(blockId, jsonObjectFromString(deletedBlockJson)));
    emitStateChanged();
}

void PdfEditSession::addChangeStyleCommand(const QString &blockId,
                                           const QString &beforeStyleJson,
                                           const QString &afterStyleJson)
{
    m_undoStack.push(PdfEditCommand::changeStyleCommand(blockId,
                                                        jsonObjectFromString(beforeStyleJson),
                                                        jsonObjectFromString(afterStyleJson)));
    emitStateChanged();
}

QString PdfEditSession::undo()
{
    const QString json = QString::fromUtf8(QJsonDocument(m_undoStack.undo()).toJson(QJsonDocument::Compact));
    emitStateChanged();
    return json;
}

QString PdfEditSession::redo()
{
    const QString json = QString::fromUtf8(QJsonDocument(m_undoStack.redo()).toJson(QJsonDocument::Compact));
    emitStateChanged();
    return json;
}

void PdfEditSession::setJournalJson(const QString &journalJson)
{
    m_undoStack.setJournalJson(journalJson);
    emitStateChanged();
}

void PdfEditSession::clear()
{
    m_undoStack.clear();
    emitStateChanged();
}

void PdfEditSession::emitStateChanged()
{
    emit dirtyChanged();
    emit undoAvailabilityChanged();
    emit redoAvailabilityChanged();
    emit journalChanged();
}
