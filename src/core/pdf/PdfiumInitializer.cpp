#include "PdfiumInitializer.h"

#ifdef PDFCLOWNE_ENABLE_PDFIUM_EDITING
#include <fpdfview.h>
#include <spdlog/spdlog.h>
#endif

namespace PDFClowne::Pdf {

PdfiumInitializer& PdfiumInitializer::instance()
{
    static std::once_flag initFlag;
    static PdfiumInitializer* singleton = nullptr;

    std::call_once(initFlag, [] {
        static PdfiumInitializer initializer;
        singleton = &initializer;
    });

    return *singleton;
}

std::recursive_mutex& PdfiumInitializer::apiMutex()
{
    return m_mutex;
}

PdfiumInitializer::PdfiumInitializer()
{
#ifdef PDFCLOWNE_ENABLE_PDFIUM_EDITING
    FPDF_InitLibrary();
    spdlog::info("PDFium library initialized");
#endif
}

PdfiumInitializer::~PdfiumInitializer()
{
#ifdef PDFCLOWNE_ENABLE_PDFIUM_EDITING
    FPDF_DestroyLibrary();
    spdlog::info("PDFium library destroyed");
#endif
}

} // namespace PDFClowne::Pdf
