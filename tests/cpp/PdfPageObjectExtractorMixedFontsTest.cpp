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

QVector<FPDF_WCHAR> toWide(const QString& text)
{
    QVector<FPDF_WCHAR> buf;
    buf.reserve(text.size() + 1);
    for (const QChar ch : text)
        buf.append(ch.unicode());
    buf.append(0);
    return buf;
}

bool addTextObject(FPDF_DOCUMENT doc, FPDF_PAGE page, const char* fontName,
                   float fontSize, float x, float y, const QString& text)
{
    FPDF_FONT font = FPDFText_LoadStandardFont(doc, fontName);
    if (!font) return false;

    FPDF_PAGEOBJECT obj = FPDFPageObj_CreateTextObj(doc, font, fontSize);
    if (!obj) { FPDFFont_Close(font); return false; }

    QVector<FPDF_WCHAR> wtext = toWide(text);
    FPDFText_SetText(obj, wtext.data());

    FS_MATRIX m {};
    m.a = 1.0f; m.d = 1.0f; m.e = x; m.f = y;
    FPDFPageObj_SetMatrix(obj, &m);
    FPDFPageObj_SetFillColor(obj, 0, 0, 0, 255);
    FPDFPage_InsertObject(page, obj);
    FPDFFont_Close(font);
    return true;
}

bool writeMixedFontsPdf(const QString& path)
{
    PDFIUM_LOCK();

    FPDF_DOCUMENT doc = FPDF_CreateNewDocument();
    if (!doc) return false;

    FPDF_PAGE page = FPDFPage_New(doc, 0, 612.0, 792.0);
    if (!page) { FPDF_CloseDocument(doc); return false; }

    if (!addTextObject(doc, page, "Helvetica",   18.0f, 72.0f, 720.0f, QStringLiteral("Hello Helvetica")))
        { FPDF_ClosePage(page); FPDF_CloseDocument(doc); return false; }

    if (!addTextObject(doc, page, "Times-Roman", 18.0f, 72.0f, 680.0f, QStringLiteral("Hello Times")))
        { FPDF_ClosePage(page); FPDF_CloseDocument(doc); return false; }

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

    const QString pdfPath = tmp.filePath(QStringLiteral("mixed_fonts.pdf"));
    if (!writeMixedFontsPdf(pdfPath)) {
        std::cerr << "Could not create mixed_fonts.pdf fixture\n";
        return 1;
    }

    FPDF_DOCUMENT doc = nullptr;
    {
        PDFIUM_LOCK();
        doc = FPDF_LoadDocument(pdfPath.toUtf8().constData(), nullptr);
    }
    if (!doc) {
        std::cerr << "PDFium could not reload mixed_fonts.pdf\n";
        return 1;
    }

    PDFClowne::Editing::PdfPageObjectExtractor extractor(doc);
    const QList<PDFClowne::Editing::PdfTextRun> runs = extractor.extractTextRunsFromPage(0);

    {
        PDFIUM_LOCK();
        FPDF_CloseDocument(doc);
    }

    bool foundHelvetica = false;
    bool foundTimes = false;
    bool foundHelveticaText = false;
    bool foundTimesText = false;

    for (const PDFClowne::Editing::PdfTextRun& run : runs) {
        if (run.fontName.contains(QStringLiteral("Helvetica"), Qt::CaseInsensitive))
            foundHelvetica = true;
        if (run.fontName.contains(QStringLiteral("Times"), Qt::CaseInsensitive))
            foundTimes = true;
        if (run.text.contains(QStringLiteral("Hello Helvetica")))
            foundHelveticaText = true;
        if (run.text.contains(QStringLiteral("Hello Times")))
            foundTimesText = true;
    }

    if (!foundHelvetica) {
        std::cerr << "Extractor did not find Helvetica font\n";
        return 1;
    }
    if (!foundTimes) {
        std::cerr << "Extractor did not find Times-Roman font\n";
        return 1;
    }
    if (!foundHelveticaText) {
        std::cerr << "Extractor did not find Helvetica text content\n";
        return 1;
    }
    if (!foundTimesText) {
        std::cerr << "Extractor did not find Times text content\n";
        return 1;
    }

    return 0;
}
