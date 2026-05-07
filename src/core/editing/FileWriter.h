#pragma once

#include <QFile>
#include <QString>

#include <fpdf_save.h>

namespace PDFClowne::Editing {

// FPDF_FILEWRITE adapter backed by a QFile.
// Keep alive for the entire duration of FPDF_SaveAsCopy / FPDF_SaveWithVersion.
class FileWriter {
public:
    explicit FileWriter(const QString& path);
    ~FileWriter();

    bool isOpen() const;
    FPDF_FILEWRITE* handle();

private:
    QFile m_file;
    FPDF_FILEWRITE m_fw{};

    static int CALLBACK writeBlock(FPDF_FILEWRITE* fw, const void* data,
                                   unsigned long size);
};

} // namespace PDFClowne::Editing
