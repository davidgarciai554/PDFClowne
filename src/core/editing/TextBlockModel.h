#pragma once

#include "PdfTextBlock.h"

#include <QAbstractListModel>
#include <QList>

namespace PDFClowne::Editing {

class TextBlockModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        BlockIdRole = Qt::UserRole + 1,
        BboxXRole,
        BboxYRole,
        BboxWidthRole,
        BboxHeightRole,
        IsEditableRole,
        NonEditableReasonRole,
        DominantFontNameRole,
        DominantFontSizeRole,
        DominantColorRole,
        PageNumberRole,
        PlainTextRole,
    };

    explicit TextBlockModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setBlocks(const QList<PdfTextBlock>& blocks);
    void clear();

    const QList<PdfTextBlock>& blocks() const { return m_blocks; }

private:
    QList<PdfTextBlock> m_blocks;
};

} // namespace PDFClowne::Editing
