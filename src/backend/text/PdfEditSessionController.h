#pragma once

#include "PdfFontResolver.h"
#include "PdfGlyphRunModel.h"
#include "PdfTextExtractor.h"
#include "../pdf/PdfTextEditOperation.h"
#include "../render/PdfScratchPageRenderer.h"

#include <QImage>
#include <QInputMethodEvent>
#include <QObject>
#include <QPointF>
#include <QSize>
#include <QString>
#include <QUrl>

namespace PDFClowne::Editing {

class PdfEditSessionController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString filePath READ filePath NOTIFY documentChanged)
    Q_PROPERTY(bool ready READ isReady NOTIFY readyChanged)
    Q_PROPERTY(bool busy READ isBusy NOTIFY busyChanged)
    Q_PROPERTY(bool active READ isActive NOTIFY activeChanged)
    Q_PROPERTY(bool hasPendingEdits READ hasPendingEdits NOTIFY pendingEditsChanged)
    Q_PROPERTY(int currentPageIndex READ currentPageIndex NOTIFY pageChanged)
    Q_PROPERTY(QString selectedBlockId READ selectedBlockId NOTIFY activeChanged)
    Q_PROPERTY(QString runsJson READ runsJson NOTIFY pageChanged)
    Q_PROPERTY(QString editableRegionsJson READ editableRegionsJson NOTIFY pageChanged)
    Q_PROPERTY(QString selectionQuadsJson READ selectionQuadsJson NOTIFY activeChanged)
    Q_PROPERTY(QString activeText READ activeText WRITE updateActiveText NOTIFY activeTextChanged)
    Q_PROPERTY(int cursorPosition READ cursorPosition NOTIFY cursorChanged)
    Q_PROPERTY(bool replaceSelectionOnInput READ replaceSelectionOnInput NOTIFY inputStateChanged)
    Q_PROPERTY(int selectionStart READ selectionStart NOTIFY inputStateChanged)
    Q_PROPERTY(int selectionLength READ selectionLength NOTIFY inputStateChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QImage editLayerImage READ editLayerImage NOTIFY editLayerImageChanged)
    Q_PROPERTY(bool scannedDocumentSuspected READ scannedDocumentSuspected NOTIFY pageChanged)

public:
    explicit PdfEditSessionController(QObject *parent = nullptr);

    QString filePath() const { return m_filePath; }
    bool isReady() const { return m_ready; }
    bool isBusy() const { return m_busy; }
    bool isActive() const { return m_active; }
    bool hasPendingEdits() const { return m_hasPendingEdits; }
    int currentPageIndex() const { return m_currentPageIndex; }
    QString selectedBlockId() const;
    QString runsJson() const { return m_runsJson; }
    QString editableRegionsJson() const { return m_regionsJson; }
    QString selectionQuadsJson() const { return m_selectionQuadsJson; }
    QString activeText() const { return m_activeText; }
    int cursorPosition() const { return m_cursorPosition; }
    bool replaceSelectionOnInput() const { return m_replaceSelectionOnInput; }
    int selectionStart() const { return m_selectionStart; }
    int selectionLength() const { return m_selectionLength; }
    QString statusMessage() const { return m_statusMessage; }
    QImage editLayerImage() const { return m_editLayerImage; }
    bool scannedDocumentSuspected() const { return m_ready && m_currentPageIndex >= 0 && m_pageText.glyphs.isEmpty(); }

    Q_INVOKABLE bool loadDocumentWithPassword(const QString &filePath, const QString &password);
    Q_INVOKABLE bool loadDocument(const QString &filePath);
    Q_INVOKABLE bool extractPage(int pageIndex);
    Q_INVOKABLE void extractBlocksForPage(int pageIndex);
    Q_INVOKABLE void selectBlock(const QString &blockId);
    Q_INVOKABLE void closeDocument();
    Q_INVOKABLE bool beginSession(int pageIndex,
                                  qreal pageX,
                                  qreal pageY,
                                  int pixelWidth,
                                  int pixelHeight,
                                  qreal scale);
    Q_INVOKABLE void clearSession();
    Q_INVOKABLE void updateActiveText(const QString &text);
    Q_INVOKABLE bool commitActiveText(const QString &reason = QStringLiteral("Explicit"));
    Q_INVOKABLE void commitActiveEdit();
    Q_INVOKABLE bool saveCurrentDocument();
    Q_INVOKABLE bool saveDocumentAs(const QUrl &outputUrl);
    Q_INVOKABLE bool saveDocument(const QString &outputPath, bool incremental = false);
    Q_INVOKABLE void updatePageViewMetrics(int pageIndex, int pixelWidth, int pixelHeight, qreal scale);
    Q_INVOKABLE bool hasActiveEdit() const { return m_active; }
    Q_INVOKABLE bool hasConfirmedEdits(int pageIndex) const;
    Q_INVOKABLE void handleKeyText(const QString &text);
    Q_INVOKABLE void handleBackspace();
    Q_INVOKABLE void handleDelete();
    Q_INVOKABLE void moveCursorLeft();
    Q_INVOKABLE void moveCursorRight();
    Q_INVOKABLE void moveCursorHome();
    Q_INVOKABLE void moveCursorEnd();
    Q_INVOKABLE void cancelActiveEdit();
    Q_INVOKABLE void inputMethodCommit(const QString &commitText);

signals:
    void documentChanged();
    void readyChanged();
    void busyChanged();
    void activeChanged();
    void pendingEditsChanged();
    void pageChanged();
    void activeTextChanged();
    void cursorChanged();
    void inputStateChanged();
    void statusMessageChanged();
    void editLayerImageChanged();
    void editCommitted(int pageIndex, const QString &editId);
    void editCancelled(int pageIndex, const QString &editId);
    void saveCompleted(const QString &outputPath);
    void saveError(const QString &message);

private:
    void setBusy(bool busy);
    void setReady(bool ready);
    void setStatusMessage(const QString &message);
    bool ensurePage(int pageIndex);
    void selectRegionAt(const QPointF &point);
    void rebuildPageJson();
    void rebuildSelectionJson();
    void regenerateEditLayer();
    int cursorIndexForPoint(const PdfEditableRegion &region, const QPointF &point) const;
    void replaceSelectionWithText(const QString &text);
    void clearInputSelection();
    void clearActiveTransientState(bool emitActiveSignals);
    int confirmedEditCount(int pageIndex = -1) const;
    void clearEditLayerIfNoVisibleEdits(const QString &reason);
    PdfTextEditOperation activeOperationSnapshot() const;
    QVector<PdfRun> replacementRunsForOperation(const PdfTextEditOperation &operation) const;
    QVector<PdfRun> replacementRunsForPage(int pageIndex) const;
    QVector<QPolygonF> redactionQuadsForPage(int pageIndex) const;
    QVector<PdfRun> activeReplacementRuns() const;
    QVector<QPolygonF> activeRedactionQuads() const;
    bool saveDocumentToPath(const QString &outputPath, bool overwriteOriginal);
    bool writeEditedPdfCopy(const QString &tempPath, QString *error) const;
    void clearDirtyFlagsAfterSave();

    QString m_filePath;
    QString m_password;
    QString m_runsJson = QStringLiteral("[]");
    QString m_regionsJson = QStringLiteral("[]");
    QString m_selectionQuadsJson = QStringLiteral("[]");
    QString m_activeText;
    QString m_originalActiveText;
    QString m_statusMessage;
    QImage m_editLayerImage;
    PdfTextExtractor::PageText m_pageText;
    PdfTextExtractor m_extractor;
    PdfFontResolver m_fontResolver;
    PDFClowne::Render::PdfScratchPageRenderer m_scratchRenderer;
    bool m_ready = false;
    bool m_busy = false;
    bool m_active = false;
    bool m_hasPendingEdits = false;
    int m_currentPageIndex = -1;
    int m_activeRegionIndex = -1;
    QVector<PdfTextEditOperation> m_textEdits;
    int m_cursorPosition = 0;
    bool m_replaceSelectionOnInput = false;
    int m_selectionStart = 0;
    int m_selectionLength = 0;
    QSize m_pixelSize;
    qreal m_scale = 1.0;
};

} // namespace PDFClowne::Editing
