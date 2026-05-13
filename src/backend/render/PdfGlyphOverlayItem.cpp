#include "PdfGlyphOverlayItem.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QKeySequence>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <QSGTexture>

namespace PDFClowne::Render {

PdfGlyphOverlayItem::PdfGlyphOverlayItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
    setFlag(ItemAcceptsInputMethod, true);
    setAcceptedMouseButtons(Qt::AllButtons);
    setFocus(true);
    setActiveFocusOnTab(true);
}

void PdfGlyphOverlayItem::setController(PDFClowne::Editing::PdfEditSessionController *controller)
{
    if (m_controller == controller)
        return;

    if (m_controller)
        disconnect(m_controller, nullptr, this, nullptr);

    m_controller = controller;
    if (m_controller) {
        connect(m_controller,
                &PDFClowne::Editing::PdfEditSessionController::editLayerImageChanged,
                this,
                &PdfGlyphOverlayItem::update);
        connect(m_controller,
                &PDFClowne::Editing::PdfEditSessionController::activeChanged,
                this,
                [this]() {
                    setFocus(true);
                    forceActiveFocus(Qt::MouseFocusReason);
                    if (window())
                        window()->requestActivate();
                    update();
                });
    }

    emit controllerChanged();
    update();
}

QSGNode *PdfGlyphOverlayItem::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *data)
{
    Q_UNUSED(data)

    auto *node = static_cast<QSGSimpleTextureNode *>(oldNode);
    const QImage image = m_controller ? m_controller->editLayerImage() : QImage();
    if (image.isNull() || !window()) {
        delete node;
        return nullptr;
    }

    if (!node) {
        node = new QSGSimpleTextureNode;
        node->setOwnsTexture(true);
    }

    QSGTexture *texture = window()->createTextureFromImage(image);
    node->setTexture(texture);
    node->setRect(boundingRect());
    return node;
}

void PdfGlyphOverlayItem::keyPressEvent(QKeyEvent *event)
{
    if (!m_controller || !event) {
        QQuickItem::keyPressEvent(event);
        return;
    }

    if (event->matches(QKeySequence::Copy)) {
        QGuiApplication::clipboard()->setText(m_controller->activeText());
        event->accept();
        return;
    }

    if (event->matches(QKeySequence::Paste)) {
        const QString text = QGuiApplication::clipboard()->text();
        if (!text.isEmpty())
            m_controller->handleKeyText(text);
        event->accept();
        return;
    }

    if (event->key() == Qt::Key_Left) {
        m_controller->moveCursorLeft();
        event->accept();
        return;
    }

    if (event->key() == Qt::Key_Right) {
        m_controller->moveCursorRight();
        event->accept();
        return;
    }

    if (event->key() == Qt::Key_Delete) {
        m_controller->handleDelete();
        event->accept();
        return;
    }

    if (event->key() == Qt::Key_Backspace) {
        m_controller->handleBackspace();
        event->accept();
        return;
    }

    if (event->key() == Qt::Key_Return || event->key() == Qt::Key_Enter) {
        m_controller->commitActiveText();
        event->accept();
        return;
    }

    if (event->key() == Qt::Key_Escape) {
        m_controller->cancelActiveEdit();
        event->accept();
        return;
    }

    const QString text = event->text();
    if (!text.isEmpty()) {
        m_controller->handleKeyText(text);
        event->accept();
        return;
    }

    QQuickItem::keyPressEvent(event);
}

void PdfGlyphOverlayItem::inputMethodEvent(QInputMethodEvent *event)
{
    if (!m_controller || !event) {
        QQuickItem::inputMethodEvent(event);
        return;
    }

    if (!event->commitString().isEmpty())
        m_controller->inputMethodCommit(event->commitString());
    event->accept();
}

QVariant PdfGlyphOverlayItem::inputMethodQuery(Qt::InputMethodQuery query) const
{
    if (!m_controller)
        return QQuickItem::inputMethodQuery(query);

    switch (query) {
    case Qt::ImEnabled:
        return true;
    case Qt::ImSurroundingText:
        return m_controller->activeText();
    case Qt::ImCurrentSelection:
        return QString();
    default:
        return QQuickItem::inputMethodQuery(query);
    }
}

} // namespace PDFClowne::Render
