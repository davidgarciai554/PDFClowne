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

$header = Read-ProjectFile 'src/core/editing/PdfPageObjectExtractor.h'
$source = Read-ProjectFile 'src/core/editing/PdfPageObjectExtractor.cpp'
$cmake = Read-ProjectFile 'CMakeLists.txt'

Assert-Matches $header 'class\s+PdfPageObjectExtractor' 'PdfPageObjectExtractor.h must declare the extractor class.'
Assert-Matches $header 'explicit\s+PdfPageObjectExtractor\(FPDF_DOCUMENT\s+doc\)' 'Extractor must be constructed from an FPDF_DOCUMENT.'
Assert-Matches $header 'QList\s*<\s*PdfTextRun\s*>\s+extractTextRunsFromPage\(int\s+pageNumber\)' 'Extractor must expose extractTextRunsFromPage.'
Assert-Matches $header 'PdfTextRun\s+extractRun\(FPDF_PAGEOBJECT\s+obj,\s*FPDF_TEXTPAGE\s+textPage,\s*int\s+idx\)' 'Extractor must have an extractRun helper.'
Assert-Matches $header 'QString\s+readUnicodeString\(FPDF_PAGEOBJECT\s+obj,\s*FPDF_TEXTPAGE\s+textPage\)' 'Extractor must have a Unicode read helper.'

Assert-Matches $source 'PDFIUM_LOCK\(\)' 'Every PDFium extraction entry point must acquire PDFIUM_LOCK().'
Assert-Matches $source 'FPDF_LoadPage\(m_doc,\s*pageNumber\)' 'Extractor must load the requested page.'
Assert-Matches $source 'FPDFText_LoadPage\(page(?:\.get\(\))?\)' 'Extractor must load the PDFium text page.'
Assert-Matches $source 'FPDFPage_CountObjects\(page(?:\.get\(\))?\)' 'Extractor must count page objects.'
Assert-Matches $source 'FPDFPage_GetObject\(page(?:\.get\(\))?,\s*i\)' 'Extractor must retrieve page objects by index.'
Assert-Matches $source 'FPDFPageObj_GetType\(obj\)\s*!=\s*FPDF_PAGEOBJ_TEXT' 'Extractor must ignore non-text page objects.'
Assert-Matches $source 'FPDFText_ClosePage\(textPage\)' 'Extractor must close the text page.'
Assert-Matches $source 'FPDF_ClosePage\(page\)' 'Extractor must close the page.'

Assert-Matches $source 'FPDFTextObj_GetText\(obj,\s*textPage,\s*nullptr,\s*0\)' 'readUnicodeString must query required UTF-16 buffer length.'
Assert-Matches $source 'QString::fromUtf16' 'readUnicodeString must convert UTF-16 to QString.'
Assert-Matches $source 'FPDFPageObj_GetBounds\(obj,' 'extractRun must read object bounds.'
Assert-Matches $source 'FPDFTextObj_GetFont\(obj\)' 'extractRun must read the PDFium font handle.'
Assert-Matches $source 'FPDFFont_GetBaseFontName\(font,' 'extractRun must read font name with the installed PDFium API.'
Assert-Matches $source 'FPDFFont_GetIsEmbedded\(font\)' 'extractRun must read whether the font is embedded.'
Assert-Matches $source 'FPDFTextObj_GetFontSize\(obj,' 'extractRun must read font size.'
Assert-Matches $source 'FPDFPageObj_GetFillColor\(obj,' 'extractRun must read fill color.'
Assert-Matches $source 'FPDFPageObj_GetMatrix\(obj,' 'extractRun must read the object matrix.'
Assert-Matches $source 'std::atan2' 'extractRun must derive text rotation from the matrix.'
Assert-Matches $source 'FPDFTextObj_GetTextRenderMode\(obj\)' 'extractRun must read text render mode.'

Assert-Matches $cmake 'src/core/editing/PdfPageObjectExtractor\.cpp' 'CMakeLists.txt must compile PdfPageObjectExtractor.cpp.'
Assert-Matches $cmake 'src/core/editing/PdfPageObjectExtractor\.h' 'CMakeLists.txt must list PdfPageObjectExtractor.h.'

Write-Output 'PDF page object extractor contract checks passed.'
