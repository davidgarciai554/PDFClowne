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

$header = Read-ProjectFile 'src/core/editing/PdfExtractionDebugRenderer.h'
$source = Read-ProjectFile 'src/core/editing/PdfExtractionDebugRenderer.cpp'
$cmake = Read-ProjectFile 'CMakeLists.txt'

Assert-Matches $header 'class\s+PdfExtractionDebugRenderer' 'PdfExtractionDebugRenderer.h must declare the debug renderer class.'
Assert-Matches $header 'static\s+QImage\s+drawTextRunBoxes\(' 'Debug renderer must expose drawTextRunBoxes.'
Assert-Matches $header 'QList\s*<\s*PdfTextRun\s*>' 'Debug renderer must accept extracted PDFium text runs.'
Assert-Matches $source '#include\s+<QPainter>' 'Debug renderer must draw with QPainter.'
Assert-Matches $source 'QPen\s+pen\([\s\S]*,\s*1\.0\)' 'Debug renderer must draw restrained 1px outlines.'
Assert-Matches $source 'QColor\(255,\s*0,\s*0' 'Debug renderer must draw extraction boxes in red.'
Assert-Matches $source 'pageHeightPt\s*-\s*run\.bboxPdf\.top\(\)' 'Debug renderer must invert PDF Y-up coordinates into image Y-down coordinates.'
Assert-Matches $source 'run\.bboxPdf\.left\(\)\s*\*\s*xScale' 'Debug renderer must scale PDF X coordinates to image coordinates.'
Assert-Matches $source 'painter\.drawRect' 'Debug renderer must draw each extracted run rectangle.'
Assert-Matches $cmake 'src/core/editing/PdfExtractionDebugRenderer\.cpp' 'CMakeLists.txt must compile PdfExtractionDebugRenderer.cpp.'
Assert-Matches $cmake 'src/core/editing/PdfExtractionDebugRenderer\.h' 'CMakeLists.txt must list PdfExtractionDebugRenderer.h.'

Write-Output 'PDF extraction debug renderer contract checks passed.'
