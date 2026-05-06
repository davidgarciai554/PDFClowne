#include "PdfPageObjectExtractor.h"
#include "PdfiumInitializer.h"

#include <QFile>
#include <QTemporaryDir>
#include <QVector>

#include <fpdf_edit.h>
#include <fpdf_save.h>
#include <fpdfview.h>

#include <iostream>

namespace {

class FileWriter final : public FPDF_FILEWRITE {
public:
    explicit FileWriter(QFile& file)
        : m_file(file)
    {
        version = 1;
        WriteBlock = &FileWriter::writeBlock;
    }

private:
    static int writeBlock(FPDF_FILEWRITE* writer, const void* data, unsigned long size)
    {
        auto* self = static_cast<FileWriter*>(writer);
        return self->m_file.write(static_cast<const char*>(data), size) == static_cast<qint64>(size);
    }

    QFile& m_file;
};

QVector<FPDF_WCHAR> toPdfWideString(const QString& text)
{
    QVector<FPDF_WCHAR> buffer;
    buffer.reserve(text.size() + 1);
    for (const QChar ch : text) {
        buffer.append(ch.unicode());
    }
    buffer.append(0);
    return buffer;
}

bool writeSimpleParagraphPdf(const QString& path)
{
    PDFIUM_LOCK();

    FPDF_DOCUMENT document = FPDF_CreateNewDocument();
    if (!document) {
        return false;
    }

    FPDF_PAGE page = FPDFPage_New(document, 0, 612.0, 792.0);
    if (!page) {
        FPDF_CloseDocument(document);
        return false;
    }

    FPDF_FONT font = FPDFText_LoadStandardFont(document, "Helvetica");
    FPDF_PAGEOBJECT textObject = font ? FPDFPageObj_CreateTextObj(document, font, 24.0f) : nullptr;
    if (!textObject) {
        if (font) {
            FPDFFont_Close(font);
        }
        FPDF_ClosePage(page);
        FPDF_CloseDocument(document);
        return false;
    }

    QVector<FPDF_WCHAR> text = toPdfWideString(QStringLiteral("Hello PDFium extractor"));
    FPDFText_SetText(textObject, text.data());

    FS_MATRIX matrix {};
    matrix.a = 1.0f;
    matrix.d = 1.0f;
    matrix.e = 72.0f;
    matrix.f = 720.0f;
    FPDFPageObj_SetMatrix(textObject, &matrix);
    FPDFPageObj_SetFillColor(textObject, 0, 0, 0, 255);
    FPDFPage_InsertObject(page, textObject);

    if (!FPDFPage_GenerateContent(page)) {
        FPDFFont_Close(font);
        FPDF_ClosePage(page);
        FPDF_CloseDocument(document);
        return false;
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        FPDFFont_Close(font);
        FPDF_ClosePage(page);
        FPDF_CloseDocument(document);
        return false;
    }

    FileWriter writer(file);
    const bool saved = FPDF_SaveAsCopy(document, &writer, FPDF_NO_INCREMENTAL) != 0;

    FPDFFont_Close(font);
    FPDF_ClosePage(page);
    FPDF_CloseDocument(document);
    return saved;
}

} // namespace

int main()
{
    QTemporaryDir tempDir;
    if (!tempDir.isValid()) {
        std::cerr << "Could not create temporary directory\n";
        return 1;
    }

    const QString pdfPath = tempDir.filePath(QStringLiteral("simple_paragraph.pdf"));
    if (!writeSimpleParagraphPdf(pdfPath)) {
        std::cerr << "Could not create simple paragraph fixture with PDFium\n";
        return 1;
    }

    FPDF_DOCUMENT document = nullptr;
    {
        PDFIUM_LOCK();
        document = FPDF_LoadDocument(pdfPath.toUtf8().constData(), nullptr);
    }

    if (!document) {
        std::cerr << "PDFium could not reload generated simple paragraph fixture\n";
        return 1;
    }

    PDFClowne::Editing::PdfPageObjectExtractor extractor(document);
    const QList<PDFClowne::Editing::PdfTextRun> runs = extractor.extractTextRunsFromPage(0);

    bool foundText = false;
    bool foundBounds = false;
    for (const PDFClowne::Editing::PdfTextRun& run : runs) {
        if (run.text.contains(QStringLiteral("Hello PDFium extractor"))) {
            foundText = true;
            foundBounds = !run.bboxPdf.isEmpty();
            break;
        }
    }

    {
        PDFIUM_LOCK();
        FPDF_CloseDocument(document);
    }

    if (!foundText) {
        std::cerr << "Extractor did not return the expected paragraph text\n";
        return 1;
    }

    if (!foundBounds) {
        std::cerr << "Extractor returned text without a non-empty bounding box\n";
        return 1;
    }

    return 0;
}
