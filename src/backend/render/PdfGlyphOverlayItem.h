#pragma once

#include "../text/PdfEditSessionController.h"

#include <QQuickItem>

namespace PDFClowne::Render {

class PdfGlyphOverlayItem : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(PDFClowne::Editing::PdfEditSessionController* controller READ controller WRITE setController NOTIFY controllerChanged)

public:
    explicit PdfGlyphOverlayItem(QQuickItem *parent = nullptr);

    PDFClowne::Editing::PdfEditSessionController *controller() const { return m_controller; }
    void setController(PDFClowne::Editing::PdfEditSessionController *controller);

signals:
    void controllerChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *data) override;
    void keyPressEvent(QKeyEvent *event) override;
    void inputMethodEvent(QInputMethodEvent *event) override;
    QVariant inputMethodQuery(Qt::InputMethodQuery query) const override;

private:
    PDFClowne::Editing::PdfEditSessionController *m_controller = nullptr;
};

} // namespace PDFClowne::Render
