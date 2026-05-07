$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Read-ProjectFile {
    param([string]$RelativePath)
    Get-Content -LiteralPath (Join-Path $root $RelativePath) -Raw
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

Assert-Matches $pdfDocumentHeader 'Q_PROPERTY\(QString\s+selectionText\s+READ\s+selectionText\s+NOTIFY\s+selectionChanged\)' 'PdfDocument must expose selectionText from MuPDF.'
Assert-Matches $pdfDocumentHeader 'Q_PROPERTY\(QString\s+selectionGeometryJson\s+READ\s+selectionGeometryJson\s+NOTIFY\s+selectionChanged\)' 'PdfDocument must expose selectionGeometryJson from MuPDF.'
Assert-Matches $pdfDocumentHeader 'Q_PROPERTY\(int\s+selectionPage\s+READ\s+selectionPage\s+NOTIFY\s+selectionChanged\)' 'PdfDocument must expose selectionPage from MuPDF.'
Assert-Matches $pdfDocumentHeader 'void\s+beginSelection\(int\s+pageIndex,\s*const\s+QPointF\s*&point\)' 'PdfDocument must provide beginSelection.'
Assert-Matches $pdfDocumentHeader 'void\s+updateSelection\(int\s+pageIndex,\s*const\s+QPointF\s*&point\)' 'PdfDocument must provide updateSelection.'
Assert-Matches $pdfDocumentHeader 'void\s+endSelection\(\)' 'PdfDocument must provide endSelection.'
Assert-Matches $pdfDocumentHeader 'void\s+clearSelection\(\)' 'PdfDocument must provide clearSelection.'

Assert-Matches $pdfDocumentSource 'fz_snap_selection\(ctx,\s*textPage,\s*&anchor,\s*&cursor,\s*FZ_SELECT_WORDS\)' 'MuPDF selection must snap to word boundaries.'
Assert-Matches $pdfDocumentSource 'fz_highlight_selection\(ctx,\s*textPage,\s*anchor,\s*cursor,\s*quads\.data\(\),\s*quads\.size\(\)\)' 'MuPDF selection must compute highlight quads.'
Assert-Matches $pdfDocumentSource 'fz_copy_selection\(ctx,\s*textPage,\s*anchor,\s*cursor,\s*0\)' 'MuPDF selection must extract copied text from the same snapped selection.'

Assert-Matches $mainQml 'selectedText:\s*pdfDocument\.selectionText' 'main.qml must pass MuPDF selectionText into PdfViewer.'
Assert-Matches $mainQml 'selectionGeometryJson:\s*pdfDocument\.selectionGeometryJson' 'main.qml must pass MuPDF selection geometry into PdfViewer.'
Assert-Matches $mainQml 'selectionPageIndex:\s*window\.activeSelectionVisualPageIndex\(\)' 'main.qml must pass MuPDF selection page into PdfViewer after mapping source pages to visible pages.'
Assert-Matches $mainQml 'beginSelectionAction:\s*window\.beginActiveSelection' 'main.qml must route beginSelection through source-page mapping before the backend.'
Assert-Matches $mainQml 'updateSelectionAction:\s*window\.updateActiveSelection' 'main.qml must route updateSelection through source-page mapping before the backend.'
Assert-Matches $mainQml 'endSelectionAction:\s*pdfDocument\.endSelection' 'main.qml must route endSelection to the backend.'
Assert-Matches $mainQml 'clearSelectionAction:\s*pdfDocument\.clearSelection' 'main.qml must route clearSelection to the backend.'

Assert-Matches $viewerQml 'property\s+string\s+selectionGeometryJson' 'PdfViewer must accept MuPDF selection geometry JSON.'
Assert-Matches $viewerQml 'property\s+int\s+selectionPageIndex' 'PdfViewer must know which page owns the current selection.'
Assert-Matches $viewerQml 'property\s+var\s+beginSelectionAction' 'PdfViewer must expose a beginSelection callback.'
Assert-Matches $viewerQml 'property\s+var\s+updateSelectionAction' 'PdfViewer must expose an updateSelection callback.'
Assert-Matches $viewerQml 'property\s+var\s+endSelectionAction' 'PdfViewer must expose an endSelection callback.'
Assert-Matches $viewerQml 'function\s+selectionPaths\(' 'PdfViewer must convert MuPDF selection JSON into PathMultiline paths.'
Assert-Matches $viewerQml 'paths:\s*root\.selectionPaths\(\)' 'PdfViewer must render MuPDF selection paths instead of QtQuick\.Pdf selection\.geometry.'

Write-Output 'MuPDF text selection static checks passed.'
