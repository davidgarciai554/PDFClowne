#include "PdfEditCommand.h"

#include <QJsonDocument>

namespace {

QJsonObject rectToJson(const QRectF &rect)
{
    return {
        {QStringLiteral("x"), rect.x()},
        {QStringLiteral("y"), rect.y()},
        {QStringLiteral("width"), rect.width()},
        {QStringLiteral("height"), rect.height()},
    };
}

PdfEditCommand makeBlockCommand(const QString &type, const QString &blockId)
{
    PdfEditCommand command;
    command.type = type;
    command.payload.insert(QStringLiteral("blockId"), blockId);
    return command;
}

} // namespace

QJsonObject PdfEditCommand::toJson() const
{
    QJsonObject object = payload;
    object.insert(QStringLiteral("type"), type);
    return object;
}

PdfEditCommand PdfEditCommand::fromJson(const QJsonObject &object)
{
    PdfEditCommand command;
    command.type = object.value(QStringLiteral("type")).toString();
    command.payload = object;
    return command;
}

PdfEditCommand PdfEditCommand::editTextCommand(const QString &blockId,
                                               const QString &beforeText,
                                               const QString &afterText)
{
    PdfEditCommand command = makeBlockCommand(QStringLiteral("editText"), blockId);
    command.payload.insert(QStringLiteral("beforeText"), beforeText);
    command.payload.insert(QStringLiteral("afterText"), afterText);
    return command;
}

PdfEditCommand PdfEditCommand::resizeBlockCommand(const QString &blockId,
                                                  const QRectF &beforeRect,
                                                  const QRectF &afterRect)
{
    PdfEditCommand command = makeBlockCommand(QStringLiteral("resizeBlock"), blockId);
    command.payload.insert(QStringLiteral("beforeRect"), rectToJson(beforeRect));
    command.payload.insert(QStringLiteral("afterRect"), rectToJson(afterRect));
    return command;
}

PdfEditCommand PdfEditCommand::moveBlockCommand(const QString &blockId,
                                                const QRectF &beforeRect,
                                                const QRectF &afterRect)
{
    PdfEditCommand command = makeBlockCommand(QStringLiteral("moveBlock"), blockId);
    command.payload.insert(QStringLiteral("beforeRect"), rectToJson(beforeRect));
    command.payload.insert(QStringLiteral("afterRect"), rectToJson(afterRect));
    return command;
}

PdfEditCommand PdfEditCommand::deleteBlockCommand(const QString &blockId,
                                                  const QJsonObject &deletedBlock)
{
    PdfEditCommand command = makeBlockCommand(QStringLiteral("deleteBlock"), blockId);
    command.payload.insert(QStringLiteral("deletedBlock"), deletedBlock);
    return command;
}

PdfEditCommand PdfEditCommand::changeStyleCommand(const QString &blockId,
                                                  const QJsonObject &beforeStyle,
                                                  const QJsonObject &afterStyle)
{
    PdfEditCommand command = makeBlockCommand(QStringLiteral("changeStyle"), blockId);
    command.payload.insert(QStringLiteral("beforeStyle"), beforeStyle);
    command.payload.insert(QStringLiteral("afterStyle"), afterStyle);
    return command;
}

void PdfUndoStack::push(const PdfEditCommand &command)
{
    if (!m_done.isEmpty() && canMerge(m_done.last(), command)) {
        mergeInto(&m_done.last(), command);
        m_undone.clear();
        return;
    }

    m_done.append(command);
    m_undone.clear();
}

QJsonObject PdfUndoStack::undo()
{
    if (m_done.isEmpty())
        return {};

    const PdfEditCommand command = m_done.takeLast();
    m_undone.append(command);
    return command.toJson();
}

QJsonObject PdfUndoStack::redo()
{
    if (m_undone.isEmpty())
        return {};

    const PdfEditCommand command = m_undone.takeLast();
    m_done.append(command);
    return command.toJson();
}

void PdfUndoStack::clear()
{
    m_done.clear();
    m_undone.clear();
}

bool PdfUndoStack::canUndo() const
{
    return !m_done.isEmpty();
}

bool PdfUndoStack::canRedo() const
{
    return !m_undone.isEmpty();
}

bool PdfUndoStack::isDirty() const
{
    return !m_done.isEmpty();
}

QString PdfUndoStack::journalJson() const
{
    QJsonArray array;
    for (const PdfEditCommand &command : m_done)
        array.append(command.toJson());
    return QString::fromUtf8(QJsonDocument(array).toJson(QJsonDocument::Compact));
}

void PdfUndoStack::setJournalJson(const QString &json)
{
    clear();
    const QJsonDocument document = QJsonDocument::fromJson(json.toUtf8());
    if (!document.isArray())
        return;

    const QJsonArray array = document.array();
    for (const QJsonValue &value : array)
        m_done.append(PdfEditCommand::fromJson(value.toObject()));
}

bool PdfUndoStack::canMerge(const PdfEditCommand &previous, const PdfEditCommand &next)
{
    return previous.type == QStringLiteral("editText")
        && next.type == QStringLiteral("editText")
        && previous.payload.value(QStringLiteral("blockId")).toString()
            == next.payload.value(QStringLiteral("blockId")).toString();
}

void PdfUndoStack::mergeInto(PdfEditCommand *previous, const PdfEditCommand &next)
{
    if (!previous)
        return;

    previous->payload.insert(QStringLiteral("afterText"),
                             next.payload.value(QStringLiteral("afterText")).toString());
}
