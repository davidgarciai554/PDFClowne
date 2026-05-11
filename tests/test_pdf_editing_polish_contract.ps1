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

$viewerQml = Read-ProjectFile 'src/qml/PdfViewer.qml'
$editableQml = Read-ProjectFile 'src/qml/EditableTextBox.qml'
$inspectorQml = Read-ProjectFile 'src/qml/EditInspector.qml'
$mainQml = Read-ProjectFile 'src/qml/main.qml'
$controllerHeader = Read-ProjectFile 'src/core/editing/EditingController.h'
$controllerSource = Read-ProjectFile 'src/core/editing/EditingController.cpp'
$modelHeader = Read-ProjectFile 'src/core/editing/TextBlockModel.h'
$modelSource = Read-ProjectFile 'src/core/editing/TextBlockModel.cpp'

Assert-Matches $controllerHeader 'Q_PROPERTY\(bool\s+hasPendingEdits\s+READ\s+hasPendingEdits\s+NOTIFY\s+pendingEditsChanged\)' `
    'EditingController must expose pending text edits to QML saves.'
Assert-Matches $controllerSource 'm_pageBlockCache\.contains\(pageNumber\)' `
    'EditingController must serve repeated page extraction from cache.'
Assert-Matches $controllerSource 'QElapsedTimer' `
    'EditingController must log measurable extraction timing.'
Assert-Matches $modelHeader 'LineRectsRole' `
    'TextBlockModel must expose line rectangles separately from block bboxes.'
Assert-Matches $modelSource '"lineRects"' `
    'TextBlockModel must publish lineRects to QML.'

Assert-Matches $viewerQml 'pdfiumRectToPageRect' `
    'PdfViewer must centralize PDFium PDF-space to page-space conversion.'
Assert-Matches $viewerQml 'visualRect' `
    'PdfViewer edit overlay must keep a separate visualRect.'
Assert-Matches $viewerQml 'hitRect' `
    'PdfViewer edit overlay must keep a separate hitRect.'
Assert-Matches $viewerQml 'editorRect' `
    'PdfViewer edit overlay must keep a separate editorRect.'
Assert-Matches $viewerQml 'pdfiumLineMaskRects' `
    'PdfViewer must mask original rendered text using extracted line rectangles.'
Assert-Matches $viewerQml 'editDebugGeometry' `
    'PdfViewer must provide an optional debug geometry mode.'
Assert-Matches $viewerQml 'root\.editingController\s*===\s*null' `
    'Legacy synchronous overlay must be disabled when EditingController is available.'
Assert-NotMatches $viewerQml 'textElementsForPageAction\(pageIndex\)' `
    'Visual bindings must not trigger synchronous text extraction for arbitrary pages.'

Assert-Matches $editableQml 'visualReplacementActive' `
    'EditableTextBox must declare when the PDF render underneath is being visually replaced.'
Assert-Matches $editableQml 'property color pdfPageBackgroundColor: "#FFFFFFFF"' `
    'EditableTextBox replacement mask must use the PDF page background, not the dark application theme.'
Assert-Matches $editableQml 'property color pdfPageTextColor: "#1C1C2E"' `
    'EditableTextBox edited preview text must use PDF text color, not Theme.text from the dark shell.'
Assert-Matches $editableQml 'if \(root\.visualReplacementActive\) return root\.pdfPageBackgroundColor' `
    'EditableTextBox confirmed edits must keep a page-colored replacement mask visible.'
Assert-Matches $editableQml 'qsTr\("Este bloque de texto no se puede editar"\)' `
    'EditableTextBox visible fallback text must be prepared for i18n.'
Assert-Matches $inspectorQml 'qsTr\("Guardar copia"\)' `
    'EditInspector visible save text must be prepared for i18n.'

Assert-Matches $mainQml 'editingController\.saveDocument\(targetPath,\s*pendingEditSaveIncremental\)' `
    'Guardar copia must call EditingController.saveDocument for PDFium text edits.'
Assert-Matches $mainQml 'completeEditingControllerSave' `
    'main.qml must reopen the saved PDFium-edited copy and restore UI state.'
Assert-Matches $mainQml 'editingController\.hasPendingEdits' `
    'main.qml must treat PDFium text edits as pending document changes.'

Write-Output 'PDF editing polish contract checks passed.'
