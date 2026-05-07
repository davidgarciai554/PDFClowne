#pragma once

#include "FontFallbackManager.h"
#include "TextBlockBuilder.h"
#include "TextBlockModel.h"

#include <QHash>
#include <QObject>
#include <QString>

#include <fpdfview.h>

namespace PDFClowne::Editing {

// Owns a PDFium document handle and drives the extraction + block-building pipeline.
// Register as a QML type from main.cpp (conditional on PDFCLOWNE_ENABLE_PDFIUM_EDITING).
class EditingController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ready READ isReady NOTIFY readyChanged)
    Q_PROPERTY(QString selectedBlockId READ selectedBlockId WRITE setSelectedBlockId
                   NOTIFY selectedBlockIdChanged)
    Q_PROPERTY(PDFClowne::Editing::TextBlockModel* currentPageBlocks READ currentPageBlocks
                   NOTIFY pageBlocksChanged)

public:
    explicit EditingController(QObject* parent = nullptr);
    ~EditingController() override;

    bool isReady() const;
    QString selectedBlockId() const;
    void setSelectedBlockId(const QString& id);
    TextBlockModel* currentPageBlocks();

    Q_INVOKABLE bool loadDocument(const QString& filePath);
    Q_INVOKABLE bool loadDocumentWithPassword(const QString& filePath, const QString& password);
    Q_INVOKABLE void extractBlocksForPage(int pageNumber);
    Q_INVOKABLE void selectBlock(const QString& blockId);
    Q_INVOKABLE void closeDocument();

    // Returns new block height in PDF points after word-wrapping newText at the block's width.
    Q_INVOKABLE qreal reflowText(const QString& blockId, const QString& newText);
    Q_INVOKABLE void  updateBlockText(const QString& blockId, const QString& newText);
    Q_INVOKABLE QString blockText(const QString& blockId) const;

    // Font fallback — returns the resolved font family for `newText` in `blockId`.
    // Sets `fallbackUsed` (out) to true when the original font was replaced.
    Q_INVOKABLE QString resolveFont(const QString& blockId, const QString& newText,
                                    bool& fallbackUsed) const;
    // QML-friendly overload (no out-param): returns empty string if original font is fine.
    Q_INVOKABLE QString fallbackFontFor(const QString& blockId, const QString& newText) const;

signals:
    void readyChanged();
    void pageBlocksChanged();
    void selectedBlockIdChanged();
    void extractionError(const QString& message);

private:
    FPDF_DOCUMENT m_doc = nullptr;
    TextBlockModel m_model;
    TextBlockBuilder m_builder;
    FontFallbackManager m_fontFallback;
    QString m_selectedBlockId;
    bool m_ready = false;
    QHash<QString, QString> m_editedTexts;

    void setReady(bool ready);
    const PdfTextBlock* findBlock(const QString& blockId) const;
};

} // namespace PDFClowne::Editing
