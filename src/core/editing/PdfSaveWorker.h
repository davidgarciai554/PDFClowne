#pragma once

#include "FontFallbackManager.h"
#include "PdfTextBlock.h"
#include "PdfWriteBackEngine.h"

#include <QHash>
#include <QList>
#include <QObject>
#include <QString>

#include <fpdfview.h>

namespace PDFClowne::Editing {

class PdfSaveWorker : public QObject {
    Q_OBJECT

public:
    PdfSaveWorker(FPDF_DOCUMENT doc,
                  QString outputPath,
                  PdfWriteBackEngine::SaveMode mode,
                  QHash<QString, QString> editedTexts,
                  QHash<QString, int> editedPages,
                  QHash<int, QList<PdfTextBlock>> pageBlockCache,
                  QObject* parent = nullptr);

public slots:
    void run();

signals:
    void progressChanged(int, const QString&);
    void finished(const QString&);
    void failed(const QString&);

private:
    FPDF_DOCUMENT m_doc = nullptr;
    QString m_outputPath;
    PdfWriteBackEngine::SaveMode m_mode = PdfWriteBackEngine::SaveMode::FullRewrite;
    QHash<QString, QString> m_editedTexts;
    QHash<QString, int> m_editedPages;
    QHash<int, QList<PdfTextBlock>> m_pageBlockCache;
    FontFallbackManager m_fontFallback;
    PdfWriteBackEngine m_writeBack;

    const PdfTextBlock* findBlock(const QString& blockId) const;
};

} // namespace PDFClowne::Editing
