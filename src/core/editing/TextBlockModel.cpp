#include "TextBlockModel.h"

#include <QStringList>

namespace PDFClowne::Editing {

TextBlockModel::TextBlockModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int TextBlockModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid()) return 0;
    return m_blocks.size();
}

QVariant TextBlockModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_blocks.size())
        return {};

    const PdfTextBlock& block = m_blocks.at(index.row());

    switch (static_cast<Roles>(role)) {
    case BlockIdRole:           return block.blockId;
    case BboxXRole:             return block.bboxPdf.x();
    case BboxYRole:             return block.bboxPdf.y();
    case BboxWidthRole:         return block.bboxPdf.width();
    case BboxHeightRole:        return block.bboxPdf.height();
    case IsEditableRole:        return block.isEditable;
    case NonEditableReasonRole: return block.nonEditableReason;
    case DominantFontNameRole:  return block.dominantFontName;
    case DominantFontSizeRole:  return block.dominantFontSize;
    case DominantColorRole:     return block.dominantColor;
    case PageNumberRole:        return block.pageNumber;
    case PlainTextRole: {
        QStringList parts;
        for (const PdfTextLine& line : block.lines)
            for (const PdfTextRun& run : line.runs)
                parts.append(run.text);
        return parts.join(' ');
    }
    default: return {};
    }
}

QHash<int, QByteArray> TextBlockModel::roleNames() const
{
    return {
        { BlockIdRole,           "blockId"           },
        { BboxXRole,             "bboxX"             },
        { BboxYRole,             "bboxY"             },
        { BboxWidthRole,         "bboxWidth"         },
        { BboxHeightRole,        "bboxHeight"        },
        { IsEditableRole,        "isEditable"        },
        { NonEditableReasonRole, "nonEditableReason" },
        { DominantFontNameRole,  "dominantFontName"  },
        { DominantFontSizeRole,  "dominantFontSize"  },
        { DominantColorRole,     "dominantColor"     },
        { PageNumberRole,        "pageNumber"        },
        { PlainTextRole,         "plainText"         },
    };
}

void TextBlockModel::setBlocks(const QList<PdfTextBlock>& blocks)
{
    beginResetModel();
    m_blocks = blocks;
    endResetModel();
}

void TextBlockModel::clear()
{
    beginResetModel();
    m_blocks.clear();
    endResetModel();
}

} // namespace PDFClowne::Editing
