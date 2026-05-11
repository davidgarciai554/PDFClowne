#pragma once

#include "PdfTextBlock.h"

#include <QAbstractListModel>
#include <QList>

namespace PDFClowne::Editing {

class TextBlockModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int editableCount READ editableCount NOTIFY countChanged)
    Q_PROPERTY(int recoverableTextCount READ recoverableTextCount NOTIFY countChanged)

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
        LineRectsRole,
        SourceKindRole,
        EditabilityRole,
        EditStrategyRole,
        UnicodeQualityRole,
    };

    explicit TextBlockModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setBlocks(const QList<PdfTextBlock>& blocks);
    void clear();

    const QList<PdfTextBlock>& blocks() const { return m_blocks; }
    int count() const;
    int editableCount() const;
    int recoverableTextCount() const;

signals:
    void countChanged();

private:
    QList<PdfTextBlock> m_blocks;
};

} // namespace PDFClowne::Editing
