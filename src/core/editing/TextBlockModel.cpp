#include "TextBlockModel.h"

#include <QVariantList>
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
    case SourceKindRole:        return block.sourceKind;
    case EditabilityRole:       return block.editability;
    case EditStrategyRole:      return block.editStrategy;
    case UnicodeQualityRole:    return block.unicodeQuality;
    case PlainTextRole: {
        QStringList parts;
        for (const PdfTextLine& line : block.lines) {
            QString lineText;
            for (const PdfTextRun& run : line.runs)
                lineText += run.text;
            parts.append(lineText);
        }
        return parts.join(QLatin1Char('\n'));
    }
    case LineRectsRole: {
        QVariantList rects;
        for (const PdfTextLine& line : block.lines) {
            QVariantMap item;
            item.insert(QStringLiteral("x"), line.bboxPdf.x());
            item.insert(QStringLiteral("y"), line.bboxPdf.y());
            item.insert(QStringLiteral("width"), line.bboxPdf.width());
            item.insert(QStringLiteral("height"), line.bboxPdf.height());
            item.insert(QStringLiteral("baseline"), line.baseline);
            rects.append(item);
        }
        return rects;
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
        { LineRectsRole,         "lineRects"         },
        { SourceKindRole,        "sourceKind"        },
        { EditabilityRole,       "editability"       },
        { EditStrategyRole,      "editStrategy"      },
        { UnicodeQualityRole,    "unicodeQuality"    },
    };
}

void TextBlockModel::setBlocks(const QList<PdfTextBlock>& blocks)
{
    beginResetModel();
    m_blocks = blocks;
    endResetModel();
    emit countChanged();
}

void TextBlockModel::clear()
{
    beginResetModel();
    m_blocks.clear();
    endResetModel();
    emit countChanged();
}

int TextBlockModel::count() const
{
    return m_blocks.size();
}

int TextBlockModel::editableCount() const
{
    int total = 0;
    for (const PdfTextBlock& block : m_blocks) {
        if (block.isEditable)
            ++total;
    }
    return total;
}

int TextBlockModel::recoverableTextCount() const
{
    int total = 0;
    for (const PdfTextBlock& block : m_blocks) {
        if (block.isEditable
            || block.editability == QStringLiteral("ocrEditable")
            || block.editability == QStringLiteral("visualEditable")
            || block.editability == QStringLiteral("nativeEditable")) {
            ++total;
        }
    }
    return total;
}

} // namespace PDFClowne::Editing
