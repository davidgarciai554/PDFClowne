#include "FileWriter.h"

#include <spdlog/spdlog.h>

namespace PDFClowne::Editing {

FileWriter::FileWriter(const QString& path)
    : m_file(path)
{
    if (!m_file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        spdlog::error("FileWriter: cannot open '{}' for writing: {}",
                      path.toStdString(),
                      m_file.errorString().toStdString());
        return;
    }
    m_fw.version    = 1;
    m_fw.WriteBlock = &FileWriter::writeBlock;
}

FileWriter::~FileWriter()
{
    if (m_file.isOpen())
        m_file.close();
}

bool FileWriter::isOpen() const
{
    return m_file.isOpen();
}

FPDF_FILEWRITE* FileWriter::handle()
{
    return m_file.isOpen() ? &m_fw : nullptr;
}

// static
int CALLBACK FileWriter::writeBlock(FPDF_FILEWRITE* fw, const void* data,
                                     unsigned long size)
{
    // Recover the FileWriter instance via pointer arithmetic.
    FileWriter* self = reinterpret_cast<FileWriter*>(
        reinterpret_cast<char*>(fw) - offsetof(FileWriter, m_fw));
    const qint64 written = self->m_file.write(
        static_cast<const char*>(data), static_cast<qint64>(size));
    return written == static_cast<qint64>(size) ? 1 : 0;
}

} // namespace PDFClowne::Editing
