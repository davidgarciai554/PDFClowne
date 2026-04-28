$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Read-ProjectFile {
    param([string]$RelativePath)
    return Get-Content -LiteralPath (Join-Path $root $RelativePath) -Raw
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

$pdfDocumentHeader = Read-ProjectFile 'src/backend/PdfDocument.h'
$pdfDocumentSource = Read-ProjectFile 'src/backend/PdfDocument.cpp'
$mainQml = Read-ProjectFile 'src/qml/main.qml'
$viewerQml = Read-ProjectFile 'src/qml/PdfViewer.qml'

Assert-Matches $pdfDocumentHeader 'Q_PROPERTY\(qint64\s+fileSizeBytes\s+READ\s+fileSizeBytes\s+NOTIFY\s+fileSizeBytesChanged\)' 'PdfDocument must expose fileSizeBytes for heavy PDF detection.'
Assert-Matches $pdfDocumentSource 'm_fileSizeBytes\s*=\s*fileInfo\.size\(\)' 'PdfDocument::load must capture the PDF file size.'
Assert-Matches $mainQml 'heavyPdfSizeThresholdBytes' 'main.qml must define a heavy PDF size threshold.'
Assert-Matches $mainQml 'function\s+activeDocumentUsesProgressiveRendering\(' 'main.qml must decide whether the active document uses progressive rendering.'
Assert-Matches $mainQml 'progressiveRenderingEnabled:\s*window\.activeDocumentUsesProgressiveRendering\(\)' 'PdfViewer must receive progressiveRenderingEnabled from main.qml.'
Assert-Matches $viewerQml 'property\s+bool\s+progressiveRenderingEnabled' 'PdfViewer must expose progressiveRenderingEnabled.'
Assert-Matches $viewerQml 'property\s+real\s+progressivePreviewScale' 'PdfViewer must expose progressivePreviewScale.'
Assert-Matches $viewerQml 'initialPageRenderScale\(' 'PdfViewer must choose an initial preview render scale.'
Assert-Matches $viewerQml 'requestProgressiveHighQualityRender\(' 'PdfViewer must request a high-quality render after the preview.'
Assert-Matches $viewerQml 'effectivePrefetchRadius\(' 'PdfViewer must reduce prefetch pressure while progressive rendering is enabled.'
Assert-Matches $viewerQml 'scale \+ 0\.01 >= renderScale \|\| progressiveRenderingEnabled' 'Progressive previews must release the loading transition before the high-quality render finishes.'

Write-Output 'Progressive PDF rendering static checks passed.'
