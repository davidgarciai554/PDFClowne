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
    param([string]$Content, [string]$Pattern, [string]$Message)
    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotMatches {
    param([string]$Content, [string]$Pattern, [string]$Message)
    if ($Content -match $Pattern) {
        throw $Message
    }
}

$mainQml = Read-ProjectFile 'src/qml/main.qml'
$viewerQml = Read-ProjectFile 'src/qml/PdfViewer.qml'
$editOverlay = Read-ProjectFile 'src/qml/editor/PdfEditOverlay.qml'

Assert-Matches $mainQml 'property\s+var\s+editingController:\s+null' `
    'main.qml must keep the optional edit-session controller in a nullable property.'
Assert-Matches $mainQml 'Qt\.createQmlObject\([\s\S]*import\s+PDFClowne\.Editing;[\s\S]*PdfEditSessionController\s*\{\s*\}' `
    'main.qml must instantiate PdfEditSessionController dynamically.'
Assert-NotMatches $mainQml 'Qt\.createQmlObject\([\s\S]*import\s+PDFClowne\.Editing;[\s\S]*\bEditingController\s*\{' `
    'main.qml must not instantiate the old PDFium EditingController as the edit pipeline.'
Assert-Matches $mainQml 'editingController:\s+window\.editingController' `
    'main.qml must pass PdfEditSessionController into PdfViewer.'
Assert-Matches $mainQml 'function\s+requestEditExtractionForActivePage\(\)' `
    'main.qml must expose an explicit edit extraction request function.'
Assert-Matches $mainQml 'loadDocumentWithPassword\(pdfDocument\.filePath,\s*pdfDocument\.password\s*\|\|\s*""\)' `
    'Entering edit mode must load the active PDF into PdfEditSessionController with the active password.'
Assert-Matches $mainQml 'extractBlocksForPage\(sourcePage\)' `
    'Entering edit mode must extract glyph regions for the active page through PdfEditSessionController.'
Assert-Matches $mainQml 'onActivePageIndexChanged:[\s\S]*requestEditExtractionForActivePage\(\)' `
    'Changing page while editing must request extraction for the active page.'
Assert-Matches $mainQml 'onViewModeChanged:[\s\S]*requestEditExtractionForActivePage\(\)' `
    'Entering edit mode must request extraction for the active page.'

Assert-Matches $viewerQml 'PdfEditOverlay\s*\{' `
    'PdfViewer must host the single edit overlay.'
Assert-NotMatches $viewerQml 'EditableTextBox\s*\{' `
    'PdfViewer must not instantiate the old visible QML text editor.'
Assert-NotMatches $viewerQml 'id:\s*phase5BlockOverlay' `
    'PdfViewer must not keep the duplicated phase 5 block overlay.'
Assert-NotMatches $viewerQml 'id:\s*pdfTextBlockOverlay' `
    'PdfViewer must not keep the old PDF text block overlay route.'
Assert-Matches $viewerQml 'id:\s*textEditTapHandler[\s\S]{0,180}enabled:\s*false' `
    'The old page-level text tap handler must be disabled when PdfEditOverlay owns pointer capture.'
Assert-Matches $viewerQml 'function\s+pageTextBlocks\(pageIndex\)[\s\S]*if\s*\(\s*editingController\s*\)[\s\S]*return\s+\[\]' `
    'PdfViewer.pageTextBlocks must avoid the synchronous MuPDF fallback when PdfEditSessionController is available.'
Assert-NotMatches $viewerQml 'textElementsForPageAction\(pageIndex\)' `
    'PdfViewer must not synchronously extract arbitrary rendered pages from visual bindings.'

Assert-Matches $editOverlay 'TapHandler\s*\{' `
    'PdfEditOverlay must own the single text-edit pointer capturer.'
Assert-Matches $editOverlay 'controller\.beginSession\(' `
    'A first click on PdfEditOverlay must begin the edit session.'
Assert-Matches $editOverlay 'forceActiveFocus\(Qt\.MouseFocusReason\)' `
    'PdfEditOverlay must grant focus synchronously in the same input event.'
Assert-NotMatches $editOverlay 'Qt\.callLater' `
    'PdfEditOverlay must not defer focus with Qt.callLater.'

Write-Output 'Edit mode entry stability contract checks passed.'
