$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Read-ProjectFile {
    param([string]$RelativePath)

    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $RelativePath"
    }

    Get-Content -LiteralPath $path -Raw
}

function Assert-Matches {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$header = Read-ProjectFile 'src/core/pdf/PdfiumInitializer.h'
$source = Read-ProjectFile 'src/core/pdf/PdfiumInitializer.cpp'
$cmake = Read-ProjectFile 'CMakeLists.txt'

Assert-Matches $header 'class\s+PdfiumInitializer' 'PdfiumInitializer.h must declare the PdfiumInitializer singleton.'
Assert-Matches $header 'static\s+PdfiumInitializer&\s+instance\(\)' 'PdfiumInitializer must expose a static instance() accessor.'
Assert-Matches $header 'std::recursive_mutex&\s+apiMutex\(\)' 'PdfiumInitializer must expose the global recursive PDFium API mutex.'
Assert-Matches $header 'std::recursive_mutex\s+m_mutex' 'PdfiumInitializer must store a recursive mutex for nested PDFium operations.'
Assert-Matches $header '#define\s+PDFIUM_LOCK\(\)' 'PdfiumInitializer.h must define PDFIUM_LOCK().'
Assert-Matches $header 'std::lock_guard\s*<\s*std::recursive_mutex\s*>' 'PDFIUM_LOCK() must acquire the recursive mutex with lock_guard.'

Assert-Matches $source 'std::once_flag' 'PdfiumInitializer.cpp must use std::once_flag for thread-safe initialization.'
Assert-Matches $source 'std::call_once' 'PdfiumInitializer::instance() must initialize through std::call_once.'
Assert-Matches $source 'FPDF_InitLibrary\(\)' 'PdfiumInitializer constructor must initialize PDFium.'
Assert-Matches $source 'FPDF_DestroyLibrary\(\)' 'PdfiumInitializer destructor must destroy PDFium.'

Assert-Matches $cmake 'src/core/pdf/PdfiumInitializer\.cpp' 'CMakeLists.txt must compile PdfiumInitializer.cpp.'
Assert-Matches $cmake 'src/core/pdf/PdfiumInitializer\.h' 'CMakeLists.txt must list PdfiumInitializer.h.'
Assert-Matches $cmake 'target_compile_definitions\(PDFClowne\s+PRIVATE\s+PDFCLOWNE_ENABLE_PDFIUM_EDITING=1\)' 'CMake must define PDFCLOWNE_ENABLE_PDFIUM_EDITING when the feature is enabled.'

Write-Output 'PDFium initializer contract checks passed.'
