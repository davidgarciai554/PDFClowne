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

$runHeader = Read-ProjectFile 'src/core/editing/PdfTextRun.h'
$lineHeader = Read-ProjectFile 'src/core/editing/PdfTextLine.h'
$blockHeader = Read-ProjectFile 'src/core/editing/PdfTextBlock.h'
$modelHeader = Read-ProjectFile 'src/core/editing/TextBlockModel.h'
$cmake = Read-ProjectFile 'CMakeLists.txt'

Assert-Matches $runHeader 'struct\s+PdfTextRun' 'PdfTextRun.h must define PdfTextRun.'
Assert-Matches $runHeader 'int\s+pageObjectIndex' 'PdfTextRun must keep the original page object index.'
Assert-Matches $runHeader 'QString\s+text' 'PdfTextRun must store Unicode text.'
Assert-Matches $runHeader 'QRectF\s+bboxPdf' 'PdfTextRun must store a PDF-space bbox.'
Assert-Matches $runHeader 'QString\s+fontName' 'PdfTextRun must store the font name.'
Assert-Matches $runHeader 'double\s+fontSize' 'PdfTextRun must store font size.'
Assert-Matches $runHeader 'QColor\s+color' 'PdfTextRun must store fill color.'
Assert-Matches $runHeader 'double\s+rotation' 'PdfTextRun must store rotation.'
Assert-Matches $runHeader 'std::array\s*<\s*double\s*,\s*6\s*>\s+matrix' 'PdfTextRun must store the 6-value PDF text matrix.'
Assert-Matches $runHeader 'int\s+renderMode' 'PdfTextRun must store PDFium render mode.'
Assert-Matches $runHeader 'bool\s+fontIsEmbedded' 'PdfTextRun must store whether the font is embedded.'
Assert-Matches $runHeader 'bool\s+fontIsSubset' 'PdfTextRun must store whether the font is subset.'
Assert-Matches $runHeader 'QString\s+sourceKind' 'PdfTextRun must store where the text was recovered from.'
Assert-Matches $runHeader 'QString\s+editability' 'PdfTextRun must separate native/visual/OCR editability.'
Assert-Matches $runHeader 'QString\s+editStrategy' 'PdfTextRun must store the persistence strategy.'
Assert-Matches $runHeader 'double\s+unicodeQuality' 'PdfTextRun must carry a basic Unicode quality score.'
Assert-Matches $runHeader 'bool\s+isEditable' 'PdfTextRun must carry editable state for filtered/limited text.'
Assert-Matches $runHeader 'QString\s+nonEditableReason' 'PdfTextRun must explain why a run is not editable.'

Assert-Matches $lineHeader 'struct\s+PdfTextLine' 'PdfTextLine.h must define PdfTextLine.'
Assert-Matches $lineHeader 'QList\s*<\s*PdfTextRun\s*>\s+runs' 'PdfTextLine must group text runs.'
Assert-Matches $lineHeader 'QRectF\s+bboxPdf' 'PdfTextLine must store the union bbox.'
Assert-Matches $lineHeader 'double\s+baseline' 'PdfTextLine must store the visual baseline.'

Assert-Matches $blockHeader 'struct\s+PdfTextBlock' 'PdfTextBlock.h must define PdfTextBlock.'
Assert-Matches $blockHeader 'QString\s+blockId' 'PdfTextBlock must store a stable block id.'
Assert-Matches $blockHeader 'int\s+pageNumber' 'PdfTextBlock must store page number.'
Assert-Matches $blockHeader 'QList\s*<\s*PdfTextLine\s*>\s+lines' 'PdfTextBlock must group visual lines.'
Assert-Matches $blockHeader 'QRectF\s+bboxPdf' 'PdfTextBlock must store total bbox.'
Assert-Matches $blockHeader 'QString\s+dominantFontName' 'PdfTextBlock must store dominant font.'
Assert-Matches $blockHeader 'double\s+dominantFontSize' 'PdfTextBlock must store dominant font size.'
Assert-Matches $blockHeader 'QColor\s+dominantColor' 'PdfTextBlock must store dominant color.'
Assert-Matches $blockHeader 'double\s+lineSpacing' 'PdfTextBlock must store line spacing.'
Assert-Matches $blockHeader 'Qt::Alignment\s+alignment' 'PdfTextBlock must store inferred alignment.'
Assert-Matches $blockHeader 'QString\s+sourceKind' 'PdfTextBlock must store where the block text was recovered from.'
Assert-Matches $blockHeader 'QString\s+editability' 'PdfTextBlock must expose native/visual/OCR editability.'
Assert-Matches $blockHeader 'QString\s+editStrategy' 'PdfTextBlock must expose the persistence strategy.'
Assert-Matches $blockHeader 'double\s+unicodeQuality' 'PdfTextBlock must carry a basic Unicode quality score.'
Assert-Matches $blockHeader 'bool\s+isEditable' 'PdfTextBlock must expose editability.'
Assert-Matches $blockHeader 'QString\s+nonEditableReason' 'PdfTextBlock must explain locked blocks.'
Assert-Matches $modelHeader 'recoverableTextCount' 'TextBlockModel must expose recoverable text count for native/visual/OCR states.'

Assert-Matches $cmake 'src/core/editing/PdfTextRun\.h' 'CMakeLists.txt must list PdfTextRun.h.'
Assert-Matches $cmake 'src/core/editing/PdfTextLine\.h' 'CMakeLists.txt must list PdfTextLine.h.'
Assert-Matches $cmake 'src/core/editing/PdfTextBlock\.h' 'CMakeLists.txt must list PdfTextBlock.h.'

Write-Output 'PDF text model contract checks passed.'
