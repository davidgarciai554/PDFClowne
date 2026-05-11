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

function Assert-Equals {
    param([int]$Actual, [int]$Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message Expected $Expected, got $Actual."
    }
}

$viewerQml = Read-ProjectFile 'src/qml/PdfViewer.qml'
$editOverlay = Read-ProjectFile 'src/qml/editor/PdfEditOverlay.qml'
$overlayItemHeader = Read-ProjectFile 'src/backend/render/PdfGlyphOverlayItem.h'
$overlayItemSource = Read-ProjectFile 'src/backend/render/PdfGlyphOverlayItem.cpp'

Assert-Matches $viewerQml 'PdfEditOverlay\s*\{[\s\S]*controller:\s*root\.editingController[\s\S]*pageIndex:\s*pageFrame\.pageIndex[\s\S]*pageScale:\s*pagePaper\.pageScale' `
    'PdfViewer must mount PdfEditOverlay with controller, page index, and page scale.'
Assert-Matches $viewerQml 'id:\s*inlinePdfTextLayer[\s\S]{0,120}visible:\s*false' `
    'The previous inline text layer must be disabled.'
Assert-Matches $viewerQml 'id:\s*textEditTapHandler[\s\S]{0,180}enabled:\s*false' `
    'The previous text tap handler must be disabled.'
Assert-NotMatches $viewerQml 'id:\s*activeTextDraftBlockMask|id:\s*activeTextDraftEditor|id:\s*draftMaskRect' `
    'The edit route must not use block masks or a visible QML text widget surface.'
Assert-NotMatches $viewerQml 'EditableTextBox\s*\{|id:\s*phase5BlockOverlay|id:\s*pdfTextBlockOverlay' `
    'The edit route must not keep duplicate QML text overlays.'

Assert-Matches $editOverlay 'PdfGlyphOverlayItem\s*\{' `
    'PdfEditOverlay must use the C++ scene graph glyph overlay.'
Assert-Matches $editOverlay 'controller:\s*root\.controller' `
    'PdfGlyphOverlayItem must receive the edit-session controller.'
Assert-Matches $editOverlay 'Repeater[\s\S]*selectionQuadsJson' `
    'PdfEditOverlay may draw selection geometry, not editable text.'
Assert-Matches $editOverlay 'Repeater[\s\S]*editableRegionsJson' `
    'PdfEditOverlay may expose debug region geometry for hit testing.'
Assert-NotMatches $editOverlay '\bText\s*\{|\bTextEdit\s*\{|\bTextInput\s*\{' `
    'PdfEditOverlay must not paint or edit visible text with Qt text items.'
Assert-NotMatches $editOverlay 'color:\s*"white"|Rectangle\s*\{[\s\S]{0,160}color:\s*"white"' `
    'PdfEditOverlay must not mask original PDF text with white rectangles.'
Assert-Equals ([regex]::Matches($editOverlay, 'TapHandler\s*\{').Count) 1 `
    'PdfEditOverlay must have exactly one pointer capturer.'

Assert-Matches $overlayItemHeader 'class\s+PdfGlyphOverlayItem\s*:\s*public\s+QQuickItem' `
    'PdfGlyphOverlayItem must be a QQuickItem, not a QML text item.'
Assert-Matches $overlayItemSource 'setFlag\(ItemHasContents,\s*true\)' `
    'PdfGlyphOverlayItem must opt into scene graph content.'
Assert-Matches $overlayItemSource 'updatePaintNode' `
    'PdfGlyphOverlayItem must paint through updatePaintNode.'
Assert-NotMatches ($overlayItemHeader + $overlayItemSource) 'QQuickPaintedItem|QRawFont|QGlyphRun' `
    'The final editable text visual path must not use QQuickPaintedItem, QRawFont, or QGlyphRun.'

Write-Output 'PDF inline editor visual contract static checks passed.'
