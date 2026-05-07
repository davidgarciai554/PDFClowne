#include "PdfPageObjectExtractor.h"
#include "PdfiumInitializer.h"

#include <QFile>
#include <QTemporaryDir>

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

// Creates a PDF with a blank page and no text objects — simulates a scanned document
// where the page is an image with no embedded text layer.
bool writeBlankPagePdf(const QString& path)
{
    PDFIUM_LOCK();

    FPDF_DOCUMENT doc = FPDF_CreateNewDocument();
    if (!doc) return false;

    FPDF_PAGE page = FPDFPage_New(doc, 0, 612.0, 792.0);
    if (!page) { FPDF_CloseDocument(doc); return false; }

    if (!FPDFPage_GenerateContent(page))
        { FPDF_ClosePage(page); FPDF_CloseDocument(doc); return false; }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        { FPDF_ClosePage(page); FPDF_CloseDocument(doc); return false; }

    FileWriter writer(file);
    const bool saved = FPDF_SaveAsCopy(doc, &writer, FPDF_NO_INCREMENTAL) != 0;

    FPDF_ClosePage(page);
    FPDF_CloseDocument(doc);
    return saved;
}

} // namespace

int main()
{
    QTemporaryDir tmp;
    if (!tmp.isValid()) {
        std::cerr << "Could not create temporary directory\n";
        return 1;
    }

    const QString pdfPath = tmp.filePath(QStringLiteral("scanned.pdf"));
    if (!writeBlankPagePdf(pdfPath)) {
        std::cerr << "Could not create scanned.pdf fixture\n";
        return 1;
    }

    FPDF_DOCUMENT doc = nullptr;
    {
        PDFIUM_LOCK();
        doc = FPDF_LoadDocument(pdfPath.toUtf8().constData(), nullptr);
    }
    if (!doc) {
        std::cerr << "PDFium could not reload scanned.pdf\n";
        return 1;
    }

    PDFClowne::Editing::PdfPageObjectExtractor extractor(doc);
    const QList<PDFClowne::Editing::PdfTextRun> runs = extractor.extractTextRunsFromPage(0);

    {
        PDFIUM_LOCK();
        FPDF_CloseDocument(doc);
    }

    if (!runs.isEmpty()) {
        std::cerr << "Extractor returned " << runs.size()
                  << " runs from a page with no text objects (expected 0)\n";
        return 1;
    }

    return 0;
}
