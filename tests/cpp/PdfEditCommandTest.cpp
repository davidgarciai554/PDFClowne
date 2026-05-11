#include "PdfEditCommand.h"
#include "PdfEditSession.h"

#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRectF>

#include <iostream>

namespace {

void expect(bool condition, const char* message)
{
    if (!condition) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}

QJsonArray journalArray(const PdfUndoStack& stack)
{
    const QJsonDocument document = QJsonDocument::fromJson(stack.journalJson().toUtf8());
    expect(document.isArray(), "journalJson must be a JSON array");
    return document.array();
}

void commandFactoriesPreserveTypedPayloads()
{
    const QRectF beforeRect(10, 20, 30, 40);
    const QRectF afterRect(11, 22, 33, 44);

    const PdfEditCommand text = PdfEditCommand::editTextCommand(
        QStringLiteral("block-1"), QStringLiteral("old"), QStringLiteral("new"));
    expect(text.type == QStringLiteral("editText"), "editTextCommand must set type");
    expect(text.payload.value(QStringLiteral("blockId")).toString() == QStringLiteral("block-1"),
           "editTextCommand must preserve blockId");
    expect(text.payload.value(QStringLiteral("beforeText")).toString() == QStringLiteral("old"),
           "editTextCommand must preserve beforeText");
    expect(text.payload.value(QStringLiteral("afterText")).toString() == QStringLiteral("new"),
           "editTextCommand must preserve afterText");

    const PdfEditCommand resize = PdfEditCommand::resizeBlockCommand(
        QStringLiteral("block-2"), beforeRect, afterRect);
    expect(resize.type == QStringLiteral("resizeBlock"), "resizeBlockCommand must set type");
    expect(resize.payload.value(QStringLiteral("afterRect")).toObject().value(QStringLiteral("width")).toDouble() == 33.0,
           "resizeBlockCommand must preserve afterRect width");

    const PdfEditCommand move = PdfEditCommand::moveBlockCommand(
        QStringLiteral("block-3"), beforeRect, afterRect);
    expect(move.type == QStringLiteral("moveBlock"), "moveBlockCommand must set type");
    expect(move.payload.value(QStringLiteral("beforeRect")).toObject().value(QStringLiteral("x")).toDouble() == 10.0,
           "moveBlockCommand must preserve beforeRect x");

    const QJsonObject deletedPayload{{QStringLiteral("blockId"), QStringLiteral("block-4")},
                                     {QStringLiteral("text"), QStringLiteral("gone")}};
    const PdfEditCommand deleted = PdfEditCommand::deleteBlockCommand(QStringLiteral("block-4"), deletedPayload);
    expect(deleted.type == QStringLiteral("deleteBlock"), "deleteBlockCommand must set type");
    expect(deleted.payload.value(QStringLiteral("deletedBlock")).toObject().value(QStringLiteral("text")).toString() == QStringLiteral("gone"),
           "deleteBlockCommand must preserve deleted block payload");

    const QJsonObject beforeStyle{{QStringLiteral("bold"), false}};
    const QJsonObject afterStyle{{QStringLiteral("bold"), true}};
    const PdfEditCommand style = PdfEditCommand::changeStyleCommand(
        QStringLiteral("block-5"), beforeStyle, afterStyle);
    expect(style.type == QStringLiteral("changeStyle"), "changeStyleCommand must set type");
    expect(style.payload.value(QStringLiteral("afterStyle")).toObject().value(QStringLiteral("bold")).toBool(),
           "changeStyleCommand must preserve afterStyle");
}

void consecutiveTextCommandsForSameBlockMerge()
{
    PdfUndoStack stack;
    stack.push(PdfEditCommand::editTextCommand(
        QStringLiteral("block-1"), QStringLiteral("hello"), QStringLiteral("hello!")));
    stack.push(PdfEditCommand::editTextCommand(
        QStringLiteral("block-1"), QStringLiteral("hello!"), QStringLiteral("hello!!")));

    const QJsonArray journal = journalArray(stack);
    expect(journal.size() == 1, "consecutive editText commands for one block must merge");
    const QJsonObject merged = journal.first().toObject();
    expect(merged.value(QStringLiteral("beforeText")).toString() == QStringLiteral("hello"),
           "merged editText command must keep the first beforeText");
    expect(merged.value(QStringLiteral("afterText")).toString() == QStringLiteral("hello!!"),
           "merged editText command must keep the latest afterText");

    const QJsonObject undone = stack.undo();
    expect(undone.value(QStringLiteral("beforeText")).toString() == QStringLiteral("hello"),
           "undo must return merged command with first beforeText");
    expect(undone.value(QStringLiteral("afterText")).toString() == QStringLiteral("hello!!"),
           "undo must return merged command with latest afterText");
}

void differentBlocksDoNotMerge()
{
    PdfUndoStack stack;
    stack.push(PdfEditCommand::editTextCommand(
        QStringLiteral("block-1"), QStringLiteral("a"), QStringLiteral("ab")));
    stack.push(PdfEditCommand::editTextCommand(
        QStringLiteral("block-2"), QStringLiteral("x"), QStringLiteral("xy")));

    expect(journalArray(stack).size() == 2, "editText commands for different blocks must not merge");
}

void editSessionExposesTypedCommandHelpers()
{
    PdfEditSession session;
    session.begin(QStringLiteral("sample.pdf"));

    expect(!session.canUndo(), "new edit session must not expose undo");
    expect(!session.canRedo(), "new edit session must not expose redo");

    session.addTextEditCommand(QStringLiteral("block-1"), QStringLiteral("a"), QStringLiteral("ab"));
    session.addTextEditCommand(QStringLiteral("block-1"), QStringLiteral("ab"), QStringLiteral("abc"));

    expect(session.canUndo(), "session must expose undo after a typed command");
    const QJsonDocument document = QJsonDocument::fromJson(session.journalJson().toUtf8());
    expect(document.isArray(), "session journal must be a JSON array");
    expect(document.array().size() == 1, "session must merge consecutive typed text edits");

    const QJsonObject undone = QJsonDocument::fromJson(session.undo().toUtf8()).object();
    expect(undone.value(QStringLiteral("type")).toString() == QStringLiteral("editText"),
           "session undo must return typed editText command");
    expect(session.canRedo(), "session must expose redo after undo");

    session.addResizeBlockCommand(QStringLiteral("block-1"), QRectF(1, 2, 3, 4), QRectF(5, 6, 7, 8));
    session.addMoveBlockCommand(QStringLiteral("block-1"), QRectF(5, 6, 7, 8), QRectF(9, 10, 7, 8));
    session.addDeleteBlockCommand(QStringLiteral("block-1"), QJsonDocument(QJsonObject{
        {QStringLiteral("text"), QStringLiteral("deleted")}
    }).toJson(QJsonDocument::Compact));
    session.addChangeStyleCommand(QStringLiteral("block-1"),
                                  QJsonDocument(QJsonObject{{QStringLiteral("bold"), false}}).toJson(QJsonDocument::Compact),
                                  QJsonDocument(QJsonObject{{QStringLiteral("bold"), true}}).toJson(QJsonDocument::Compact));

    const QJsonArray typedJournal = QJsonDocument::fromJson(session.journalJson().toUtf8()).array();
    expect(typedJournal.size() == 4, "session must store typed resize, move, delete, and style commands");
    expect(typedJournal.at(0).toObject().value(QStringLiteral("type")).toString() == QStringLiteral("resizeBlock"),
           "session must store resizeBlock commands");
    expect(typedJournal.at(1).toObject().value(QStringLiteral("type")).toString() == QStringLiteral("moveBlock"),
           "session must store moveBlock commands");
    expect(typedJournal.at(2).toObject().value(QStringLiteral("type")).toString() == QStringLiteral("deleteBlock"),
           "session must store deleteBlock commands");
    expect(typedJournal.at(3).toObject().value(QStringLiteral("type")).toString() == QStringLiteral("changeStyle"),
           "session must store changeStyle commands");
}

} // namespace

int main(int argc, char* argv[])
{
    QCoreApplication app(argc, argv);

    commandFactoriesPreserveTypedPayloads();
    consecutiveTextCommandsForSameBlockMerge();
    differentBlocksDoNotMerge();
    editSessionExposesTypedCommandHelpers();

    std::cout << "PdfEditCommand tests passed\n";
    return 0;
}
