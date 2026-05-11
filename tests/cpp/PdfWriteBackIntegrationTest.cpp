#include "PdfTextBlock.h"
#include "PdfWriteBackEngine.h"
#include "PdfiumInitializer.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QTemporaryDir>

#include <fpdf_edit.h>
#include <fpdf_save.h>
#include <fpdf_text.h>
#include <fpdfview.h>

#include <cmath>
#include <iostream>
#include <vector>

using PDFClowne::Editing::FontFallbackResult;
using PDFClowne::Editing::PdfTextBlock;
using PDFClowne::Editing::PdfTextLine;
using PDFClowne::Editing::PdfTextRun;
using PDFClowne::Editing::PdfWriteBackEngine;

namespace {

void expect(bool condition, const char* message)
{
    if (!condition) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}

std::vector<unsigned short> toUtf16(const QString& text)
{
    std::vector<unsigned short> result;
    result.reserve(static_cast<size_t>(text.size()) + 1);
    for (const QChar ch : text)
        result.push_back(ch.unicode());
    result.push_back(0);
    return result;
}

PdfTextBlock sourceBlock()
{
    PdfTextRun run;
    run.pageObjectIndex = 0;
    run.text = QStringLiteral("Before");
    run.bboxPdf = QRectF(72, 700, 180, 24);
    run.fontName = QStringLiteral("Helvetica");
    run.fontSize = 18.0;

    PdfTextLine line;
    line.runs.append(run);
    line.bboxPdf = run.bboxPdf;
    line.baseline = 700;

    PdfTextBlock block;
    block.blockId = QStringLiteral("block-1");
    block.pageNumber = 0;
    block.lines.append(line);
    block.bboxPdf = run.bboxPdf;
    block.dominantFontName = QStringLiteral("Helvetica");
    block.dominantFontSize = 18.0;
    block.dominantColor = Qt::black;
    return block;
}

PdfTextBlock visualReplacementBlock()
{
    PdfTextBlock block = sourceBlock();
    block.blockId = QStringLiteral("visual-block-1");
    block.editability = QStringLiteral("visualEditable");
    block.editStrategy = QStringLiteral("persistentVisualReplacement");
    for (PdfTextLine& line : block.lines) {
        for (PdfTextRun& run : line.runs) {
            run.pageObjectIndex = -1;
            run.editability = QStringLiteral("visualEditable");
            run.editStrategy = QStringLiteral("persistentVisualReplacement");
        }
    }
    return block;
}

FPDF_DOCUMENT createOnePageDocument()
{
    PDFIUM_LOCK();
    FPDF_DOCUMENT doc = FPDF_CreateNewDocument();
    if (!doc)
        return nullptr;

    FPDF_PAGE page = FPDFPage_New(doc, 0, 612, 792);
    FPDF_FONT font = FPDFText_LoadStandardFont(doc, "Helvetica");
    FPDF_PAGEOBJECT text = FPDFPageObj_CreateTextObj(doc, font, 18.0f);
    const auto utf16 = toUtf16(QStringLiteral("Before"));
    FPDFText_SetText(text, reinterpret_cast<FPDF_WIDESTRING>(utf16.data()));
    FPDFPageObj_Transform(text, 1, 0, 0, 1, 72, 700);
    FPDFPageObj_SetFillColor(text, 0, 0, 0, 255);
    FPDFPage_InsertObject(page, text);
    FPDFPage_GenerateContent(page);
    FPDFFont_Close(font);
    FPDF_ClosePage(page);
    return doc;
}

QString extractPageText(const QString& path)
{
    QByteArray encodedPath = path.toUtf8();
    PDFIUM_LOCK();
    FPDF_DOCUMENT doc = FPDF_LoadDocument(encodedPath.constData(), nullptr);
    if (!doc)
        return {};
    FPDF_PAGE page = FPDF_LoadPage(doc, 0);
    FPDF_TEXTPAGE textPage = FPDFText_LoadPage(page);
    const int charCount = FPDFText_CountChars(textPage);
    std::vector<unsigned short> buffer(static_cast<size_t>(charCount) + 1);
    FPDFText_GetText(textPage, 0, charCount, reinterpret_cast<unsigned short*>(buffer.data()));
    FPDFText_ClosePage(textPage);
    FPDF_ClosePage(page);
    FPDF_CloseDocument(doc);
    return QString::fromUtf16(buffer.data()).trimmed();
}

std::vector<unsigned char> renderFirstPage(const QString& path)
{
    QByteArray encodedPath = path.toUtf8();
    PDFIUM_LOCK();
    FPDF_DOCUMENT doc = FPDF_LoadDocument(encodedPath.constData(), nullptr);
    expect(doc != nullptr, "render must open document");
    FPDF_PAGE page = FPDF_LoadPage(doc, 0);
    expect(page != nullptr, "render must open first page");

    constexpr int width = 612;
    constexpr int height = 792;
    FPDF_BITMAP bitmap = FPDFBitmap_Create(width, height, 0);
    FPDFBitmap_FillRect(bitmap, 0, 0, width, height, 0xFFFFFFFF);
    FPDF_RenderPageBitmap(bitmap, page, 0, 0, width, height, 0, FPDF_ANNOT);

    const int stride = FPDFBitmap_GetStride(bitmap);
    const auto* bytes = static_cast<const unsigned char*>(FPDFBitmap_GetBuffer(bitmap));
    std::vector<unsigned char> pixels(bytes, bytes + stride * height);

    FPDFBitmap_Destroy(bitmap);
    FPDF_ClosePage(page);
    FPDF_CloseDocument(doc);
    return pixels;
}

double differentPixelRatio(const std::vector<unsigned char>& left,
                           const std::vector<unsigned char>& right)
{
    expect(left.size() == right.size(), "rendered images must have the same size");
    size_t different = 0;
    for (size_t i = 0; i < left.size(); i += 4) {
        if (left[i] != right[i] || left[i + 1] != right[i + 1]
                || left[i + 2] != right[i + 2] || left[i + 3] != right[i + 3]) {
            ++different;
        }
    }
    return static_cast<double>(different) / static_cast<double>(left.size() / 4);
}

} // namespace

int main(int argc, char* argv[])
{
    QCoreApplication app(argc, argv);
    QTemporaryDir tempDir;
    expect(tempDir.isValid(), "temporary directory must be available");

    PdfWriteBackEngine engine;
    FPDF_DOCUMENT originalDoc = createOnePageDocument();
    expect(originalDoc != nullptr, "source document must be created");

    const QString originalPath = QDir(tempDir.path()).absoluteFilePath(QStringLiteral("before.pdf"));
    expect(engine.saveTo(originalDoc, originalPath, PdfWriteBackEngine::SaveMode::FullRewrite),
           "source document must save");

    FontFallbackResult font;
    font.resolvedFontName = QStringLiteral("Helvetica");
    font.resolvedFontSize = 18.0;

    expect(engine.writeBackBlock(originalDoc, 0, sourceBlock(), QStringLiteral("After"), font),
           "writeBackBlock must replace text");

    const QString editedPath = QDir(tempDir.path()).absoluteFilePath(QStringLiteral("after.pdf"));
    expect(engine.saveTo(originalDoc, editedPath, PdfWriteBackEngine::SaveMode::FullRewrite),
           "edited document must save");
    FPDF_CloseDocument(originalDoc);

    const QString text = extractPageText(editedPath);
    expect(text.contains(QStringLiteral("After")), "save-reload text extraction must find edited text");
    expect(!text.contains(QStringLiteral("Before")), "save-reload text extraction must not keep old text");

    const double diffRatio = differentPixelRatio(renderFirstPage(originalPath), renderFirstPage(editedPath));
    expect(diffRatio > 0.0, "golden-image comparison must detect a visual change");
    expect(diffRatio < 0.02, "golden-image comparison must stay within 2 percent tolerance");

    FPDF_DOCUMENT visualDoc = createOnePageDocument();
    expect(visualDoc != nullptr, "visual replacement source document must be created");
    const QString visualOriginalPath = QDir(tempDir.path()).absoluteFilePath(QStringLiteral("visual-before.pdf"));
    expect(engine.saveTo(visualDoc, visualOriginalPath, PdfWriteBackEngine::SaveMode::FullRewrite),
           "visual replacement source document must save");

    expect(engine.writeBackBlock(visualDoc, 0, visualReplacementBlock(), QStringLiteral("Visual After"), font),
           "visualEditable writeBackBlock must persist mask plus replacement text");

    const QString visualEditedPath = QDir(tempDir.path()).absoluteFilePath(QStringLiteral("visual-after.pdf"));
    expect(engine.saveTo(visualDoc, visualEditedPath, PdfWriteBackEngine::SaveMode::FullRewrite),
           "visual replacement edited document must save");
    FPDF_CloseDocument(visualDoc);

    const QString visualText = extractPageText(visualEditedPath);
    expect(visualText.contains(QStringLiteral("Visual After")),
           "visual replacement save-reload text extraction must find replacement text");
    const double visualDiffRatio =
        differentPixelRatio(renderFirstPage(visualOriginalPath), renderFirstPage(visualEditedPath));
    expect(visualDiffRatio > 0.0,
           "visual replacement must produce a persisted visual render difference");

    std::cout << "PdfWriteBack integration tests passed\n";
    return 0;
}
