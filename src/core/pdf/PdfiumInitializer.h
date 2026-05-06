#pragma once

#include <mutex>

namespace PDFClowne::Pdf {

class PdfiumInitializer {
public:
    static PdfiumInitializer& instance();

    std::recursive_mutex& apiMutex();

    PdfiumInitializer(const PdfiumInitializer&) = delete;
    PdfiumInitializer& operator=(const PdfiumInitializer&) = delete;

private:
    PdfiumInitializer();
    ~PdfiumInitializer();

    std::recursive_mutex m_mutex;
};

} // namespace PDFClowne::Pdf

#define PDFCLOWNE_DETAIL_JOIN_IMPL(left, right) left##right
#define PDFCLOWNE_DETAIL_JOIN(left, right) PDFCLOWNE_DETAIL_JOIN_IMPL(left, right)

#define PDFIUM_LOCK() \
    std::lock_guard<std::recursive_mutex> PDFCLOWNE_DETAIL_JOIN(_pdfiumLock, __LINE__)( \
        PDFClowne::Pdf::PdfiumInitializer::instance().apiMutex())
