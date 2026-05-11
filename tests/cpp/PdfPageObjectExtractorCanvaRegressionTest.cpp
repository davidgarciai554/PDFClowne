#include "PdfPageObjectExtractor.h"
#include "PdfiumInitializer.h"
#include "TextBlockBuilder.h"

#include <QCoreApplication>
#include <QDir>
#include <QStringList>

#include <fpdfview.h>

#include <iostream>

namespace {

QString fixturePath()
{
#ifdef PDFCLOWNE_SOURCE_DIR
    return QDir(QStringLiteral(PDFCLOWNE_SOURCE_DIR))
        .filePath(QStringLiteral("tests/pdfs/01-base.pdf"));
#else
    return QDir::current().filePath(QStringLiteral("tests/pdfs/01-base.pdf"));
#endif
}

QString blockText(const PDFClowne::Editing::PdfTextBlock& block)
{
    QStringList lines;
    for (const PDFClowne::Editing::PdfTextLine& line : block.lines) {
        QString text;
        for (const PDFClowne::Editing::PdfTextRun& run : line.runs)
            text += run.text;
        lines.append(text.simplified());
    }
    return lines.join(QLatin1Char(' ')).simplified();
}

} // namespace

int main(int argc, char** argv)
{
    QCoreApplication app(argc, argv);

    const QString path = fixturePath();
    FPDF_DOCUMENT document = nullptr;
    {
        PDFIUM_LOCK();
        document = FPDF_LoadDocument(path.toUtf8().constData(), nullptr);
    }
    if (!document) {
        std::cerr << "Could not open Canva regression fixture: "
                  << path.toStdString() << "\n";
        return 1;
    }

    PDFClowne::Editing::PdfPageObjectExtractor extractor(document);
    PDFClowne::Editing::TextBlockBuilder builder;

    bool foundName = false;
    bool foundBackend = false;
    bool foundBackendParagraphBlock = false;
    bool foundStandaloneBackendTail = false;
    bool foundSkills = false;
    int visualEditableBlocks = 0;
    int totalBlocks = 0;

    const int pageCount = FPDF_GetPageCount(document);
    for (int page = 0; page < pageCount; ++page) {
        const QList<PDFClowne::Editing::PdfTextRun> runs =
            extractor.extractTextRunsFromPage(page);
        const QList<PDFClowne::Editing::PdfTextBlock> blocks =
            builder.buildBlocks(runs, page);

        totalBlocks += blocks.size();
        for (const PDFClowne::Editing::PdfTextBlock& block : blocks) {
            const QString text = blockText(block);
            foundName = foundName || text.contains(QStringLiteral("DAVID GARCIA MARTIN"));
            foundBackend = foundBackend || text.contains(QStringLiteral("Backend Engineer con experiencia"));
            foundBackendParagraphBlock = foundBackendParagraphBlock
                || (text.contains(QStringLiteral("Backend Engineer con experiencia"))
                    && text.contains(QStringLiteral("seguridad"))
                    && text.contains(QStringLiteral("concepción hasta el despliegue"))
                    && block.lines.size() >= 2);
            foundSkills = foundSkills || text.contains(QStringLiteral("HABILIDADES PROFESIONALES Y PERSONALES"));
            if (text.contains(QStringLiteral("concepción hasta el despliegue"))
                && !text.contains(QStringLiteral("Backend Engineer con experiencia"))) {
                foundStandaloneBackendTail = true;
            }
            if (block.editability == QStringLiteral("visualEditable"))
                ++visualEditableBlocks;
        }
    }

    {
        PDFIUM_LOCK();
        FPDF_CloseDocument(document);
    }

    if (totalBlocks == 0) {
        std::cerr << "01-base.pdf produced no editable analysis blocks\n";
        return 1;
    }
    if (!foundName || !foundBackend || !foundSkills) {
        std::cerr << "01-base.pdf missed expected Canva CV text: "
                  << "name=" << foundName
                  << " backend=" << foundBackend
                  << " skills=" << foundSkills << "\n";
        return 1;
    }
    if (!foundBackendParagraphBlock) {
        std::cerr << "01-base.pdf must group the Backend summary as a multi-line editable block\n";
        FPDF_DOCUMENT debugDocument = nullptr;
        {
            PDFIUM_LOCK();
            debugDocument = FPDF_LoadDocument(path.toUtf8().constData(), nullptr);
        }
        if (debugDocument) {
            PDFClowne::Editing::PdfPageObjectExtractor debugExtractor(debugDocument);
            const QList<PDFClowne::Editing::PdfTextBlock> debugBlocks =
                builder.buildBlocks(debugExtractor.extractTextRunsFromPage(0), 0);
            for (const PDFClowne::Editing::PdfTextBlock& block : debugBlocks) {
                const QString text = blockText(block);
                if (text.contains(QStringLiteral("Backend"))
                    || text.contains(QStringLiteral("seguridad"))) {
                    std::cerr << "  block lines=" << block.lines.size()
                              << " editability=" << block.editability.toStdString()
                              << " x=" << block.bboxPdf.left()
                              << " y=" << block.bboxPdf.top()
                              << " w=" << block.bboxPdf.width()
                              << " h=" << block.bboxPdf.height()
                              << " text=" << text.left(220).toStdString() << "\n";
                    for (const PDFClowne::Editing::PdfTextLine& line : block.lines) {
                        std::cerr << "    line baseline=" << line.baseline
                                  << " x=" << line.bboxPdf.left()
                                  << " y=" << line.bboxPdf.top()
                                  << " w=" << line.bboxPdf.width()
                                  << " h=" << line.bboxPdf.height()
                                  << " text=" << blockText(PDFClowne::Editing::PdfTextBlock{ {}, 0, { line } }).left(120).toStdString()
                                  << "\n";
                    }
                }
            }
            PDFIUM_LOCK();
            FPDF_CloseDocument(debugDocument);
        }
        return 1;
    }
    if (foundStandaloneBackendTail) {
        std::cerr << "01-base.pdf must not expose the Backend paragraph tail as a separate clickable block\n";
        FPDF_DOCUMENT debugDocument = nullptr;
        {
            PDFIUM_LOCK();
            debugDocument = FPDF_LoadDocument(path.toUtf8().constData(), nullptr);
        }
        if (debugDocument) {
            PDFClowne::Editing::PdfPageObjectExtractor debugExtractor(debugDocument);
            const QList<PDFClowne::Editing::PdfTextBlock> debugBlocks =
                builder.buildBlocks(debugExtractor.extractTextRunsFromPage(0), 0);
            for (const PDFClowne::Editing::PdfTextBlock& block : debugBlocks) {
                const QString text = blockText(block);
                if (text.contains(QStringLiteral("Backend"))
                    || text.contains(QStringLiteral("concepción"))) {
                    std::cerr << "  block lines=" << block.lines.size()
                              << " x=" << block.bboxPdf.left()
                              << " y=" << block.bboxPdf.top()
                              << " w=" << block.bboxPdf.width()
                              << " h=" << block.bboxPdf.height()
                              << " text=" << text.left(260).toStdString() << "\n";
                }
            }
            PDFIUM_LOCK();
            FPDF_CloseDocument(debugDocument);
        }
        return 1;
    }
    if (visualEditableBlocks == 0) {
        std::cerr << "01-base.pdf must expose complex Canva text as visualEditable\n";
        return 1;
    }

    return 0;
}
