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
$scratchRendererSource = Read-ProjectFile 'src/backend/render/PdfScratchPageRenderer.cpp'
$mainQml = Read-ProjectFile 'src/qml/main.qml'
$controllerSource = Read-ProjectFile 'src/backend/text/PdfEditSessionController.cpp'
$controllerHeader = Read-ProjectFile 'src/backend/text/PdfEditSessionController.h'
$contentWriterHeader = Read-ProjectFile 'src/backend/pdf/PdfContentWriter.h'
$contentWriterSource = Read-ProjectFile 'src/backend/pdf/PdfContentWriter.cpp'

Assert-Matches $viewerQml 'PdfEditOverlay\s*\{[\s\S]*controller:\s*root\.editingController[\s\S]*pageIndex:\s*pageFrame\.pageIndex[\s\S]*pageScale:\s*pagePaper\.pageScale' `
    'PdfViewer must mount PdfEditOverlay with controller, page index, and page scale.'
Assert-Matches $viewerQml 'nativeTextEditToolActive:\s*editTool\s*===\s*"text"\s*\|\|\s*editTool\s*===\s*"block"|nativeTextEditToolActive\s*:\s*editTool\s*===\s*"text"\s*\|\|\s*editTool\s*===\s*"block"|nativeTextEditToolActive\s+.*editTool\s*===\s*"text"\s*\|\|\s*editTool\s*===\s*"block"' `
    'PdfViewer must allow the native edit overlay for both text and block tools.'
Assert-NotMatches $viewerQml 'editTool\s*===\s*"text"\s*&&\s*(root\.)?nativeTextEditToolActive|(root\.)?nativeTextEditToolActive\s*&&\s*(root\.)?editTool\s*===\s*"text"' `
    'Native edit overlay activation must not redundantly require editTool === "text".'
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
Assert-Matches $editOverlay 'suppressFinishForCurrentClick' `
    'PdfEditOverlay must guard against closing the edit session with the same click that opened it.'
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
Assert-NotMatches $overlayItemSource 'scale\s*\(\s*1\s*,\s*-1\s*\)|scale\s*\(\s*-1\s*,\s*1\s*\)|RightToLeft|QTextOption::RightToLeft|setLayoutDirection\s*\(\s*Qt::RightToLeft' `
    'PdfGlyphOverlayItem must not mirror, flip, or force RTL for editable text.'
Assert-Matches $scratchRendererSource 'textMatrixFromVisualSpace' `
    'PdfScratchPageRenderer must convert visual edit coordinates through one explicit text matrix helper.'
Assert-Matches $scratchRendererSource '\[PDF_EDIT_PAINT_TEXT\]' `
    'PdfScratchPageRenderer must keep guarded paint-transform logging for editable text.'

$viewerQmlFull = Read-ProjectFile 'src/qml/PdfViewer.qml'

Assert-NotMatches $viewerQmlFull 'visible\s*:\s*pageImage\.status\s*===\s*Image\.Ready\s*&&\s*root\.editModeEnabled\s*&&\s*root\.nativeTextEditToolActive\s*&&\s*root\.editingController\s*!==\s*null' `
    'PdfEditOverlay must not be visible only when editModeEnabled — confirmed edits must show in view mode too.'
Assert-Matches $viewerQmlFull 'hasPendingEdits' `
    'PdfViewer must consult hasPendingEdits to keep confirmed-edit overlay visible in view mode.'
Assert-Matches $viewerQmlFull 'hasConfirmedEdits\(pageFrame\.pageIndex\)' `
    'PdfViewer must keep confirmed-edit preview visible only on pages that actually have confirmed edits.'
Assert-Matches $viewerQmlFull 'inputEnabled\s*:\s*root\.editModeEnabled' `
    'PdfEditOverlay must receive inputEnabled bound to editModeEnabled so view mode suppresses interaction.'
Assert-Matches $viewerQmlFull 'onEditModeEnabledChanged[\s\S]{0,300}commitActiveText' `
    'Switching to view mode must commit the active edit, not cancel it.'
Assert-NotMatches $viewerQmlFull 'onEditModeEnabledChanged[\s\S]{0,300}cancelActiveEdit' `
    'Switching to view mode must not cancel the active edit.'
Assert-NotMatches $viewerQmlFull 'onEditModeEnabledChanged[\s\S]{0,300}clearSession|onEditModeEnabledChanged[\s\S]{0,300}reset' `
    'Switching to view mode must not clear/reset the native edit session.'
Assert-Matches $mainQml 'onViewModeChanged[\s\S]{0,500}commitActiveText\("ModeChanged"\)' `
    'main.qml must commit native text edits when leaving edit mode.'
Assert-NotMatches $mainQml 'onViewModeChanged[\s\S]{0,500}selectBlock\(""\)|onViewModeChanged[\s\S]{0,500}clearSession|onViewModeChanged[\s\S]{0,500}cancelActive' `
    'main.qml must not clear/cancel native text edits when leaving edit mode.'
Assert-Matches $editOverlay 'property bool inputEnabled' `
    'PdfEditOverlay must expose inputEnabled property to allow read-only paint in view mode.'
Assert-Matches $editOverlay 'enabled\s*:\s*root\.inputEnabled' `
    'PdfEditOverlay TapHandler must be gated on inputEnabled so view mode does not start new sessions.'
Assert-Matches $editOverlay 'onVisibleChanged' `
    'PdfEditOverlay must refresh controller metrics when becoming visible to restore confirmed-edit layer.'
Assert-Matches $controllerHeader 'Q_PROPERTY\(bool\s+hasPendingEdits\s+READ\s+hasPendingEdits\s+NOTIFY\s+pendingEditsChanged\)' `
    'PdfEditSessionController must notify QML when confirmed edit pending state changes.'
Assert-NotMatches $controllerSource 'regenerateEditLayer\s*\(\)\s*\{[\s\S]{0,500}if\s*\(\s*!m_active\s*\)\s*\{[\s\S]{0,120}return' `
    'regenerateEditLayer must not return just because editing is inactive; confirmed edits still need painting.'
Assert-Matches $controllerSource 'ClickedOutside' `
    'Clicking outside active text must commit, not clear, the active edit.'
Assert-Matches $controllerSource 'clearEditLayerIfNoVisibleEdits' `
    'The controller must only clear the visual layer when there are no active or confirmed edits for the page.'
Assert-Matches $mainQml 'var\s+overwriteCurrent\s*=\s*requestedOverwriteCurrent\s*\|\|\s*isSameFilePath\(sourcePath,\s*targetPath\)' `
    'Normal Guardar must force overwriteCurrent when requested or when source and target are the same PDF.'
Assert-Matches $mainQml 'editingController\.saveDocument\(targetPath,\s*overwriteCurrent\)' `
    'Normal Guardar must route native text edits through PdfEditSessionController.saveDocument with overwrite detection.'
Assert-Matches $mainQml 'function\s+saveActiveDocumentRotated[\s\S]{0,260}saveDocumentChanges\(activeDocumentIndex,\s*currentPath,\s*true\)' `
    'The main Save action must share the saveDocumentChanges pipeline used for native text edits.'
Assert-Matches $mainQml 'editingController\.hasPendingEdits\s*\|\|\s*editingController\.active' `
    'The Save action must be enabled for an active uncommitted native text edit.'
Assert-Matches $mainQml 'documentRenderController\.releaseDocumentSync[\s\S]{0,900}pdfDocument\.clear\(\)' `
    'Overwrite saves with native text edits must release render handles and clear PdfDocument before replacing the current PDF.'
Assert-Matches $mainQml 'pdfDocument\.clear\(\)[\s\S]{0,900}editingController\.saveDocument\(targetPath,\s*overwriteCurrent\)' `
    'In-place native text save must clear PdfDocument before calling editingController.saveDocument so Windows releases the original PDF handle.'
Assert-NotMatches $mainQml 'pdfDocument\.close\(|pdfDocument\.open\(' `
    'main.qml must use PdfDocument.clear/load, not close/open.'
Assert-Matches $mainQml 'pdfViewer\.commitActiveEditor\(\)[\s\S]{0,600}editingController\.commitActiveText\("SaveRequestedFromMain"\)' `
    'Guardar must commit the active native text editor before closing PdfDocument.'
Assert-Matches $mainQml 'documentRenderController\.releaseDocumentSync\([^\)]*\)[\s\S]{0,900}pdfDocument\.clear\(\)' `
    'Guardar must release render controller and clear PdfDocument before replacing the original PDF.'
Assert-Matches $mainQml 'function\s+completeEditingControllerSave[\s\S]*pdfDocument\.clear\(\)[\s\S]{0,500}pdfDocument\.load\(targetPath' `
    'After native save completes, main.qml must reload the saved PDF from disk.'
Assert-Matches ($contentWriterHeader + $contentWriterSource) 'visualBaselineToPdfBaseline|buildReplacementTextStream' `
    'PdfContentWriter must expose explicit visual-to-PDF export geometry helpers.'
Assert-Matches $contentWriterSource 'zoomUsed=false devicePixelRatioUsed=false' `
    'Text export logs must prove zoom/device pixel ratio are not part of physical PDF font sizing.'
Assert-NotMatches $contentWriterSource '1\s+1\s+1\s+rg[\s\S]{0,120}re\\n[\s\S]{0,80}f\\n' `
    'Physical PDF text export must not paint an extra white rectangle behind edited text.'
Assert-NotMatches $controllerSource 'buildRedactionCoverStream\(' `
    'Physical PDF text export must not append a white cover stream; original text removal must be handled by text redaction only.'
Assert-NotMatches $controllerSource 'expandVisualRedactionRect' `
    'Physical PDF text export must not use expanded visual redaction rectangles that can cover adjacent lines.'
Assert-NotMatches $contentWriterSource 'const QTransform &tm = first\.trm|number\(tm\.m11\(\)\)|number\(tm\.dy\(\)\)' `
    'Physical PDF export must not reuse the preview/extraction transform as the final PDF Tm.'
Assert-Matches $controllerSource 'buildReplacementTextStream' `
    'Physical PDF export must use PdfContentWriter for replacement text streams.'
Assert-Matches $controllerSource 'buildReplacementTextStream\(\s*run,\s*edit\.replacementText,\s*fontPlan,\s*pageHeight,' `
    'Physical PDF text export must pass page height to convert visual baseline into PDF user space.'
Assert-NotMatches $controllerSource 'visualQuadToPdfQuad' `
    'Redaction quads must stay in MuPDF extraction space; only replacement text baseline is converted for PDF content.'
Assert-NotMatches $controllerSource 'buildReplacementTextStream\(run,\s*edit\.replacementText,\s*fontPlan\)' `
    'Physical export must not use the old writer overload without page-height conversion.'

Write-Output 'PDF inline editor visual contract static checks passed.'
