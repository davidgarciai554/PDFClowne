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

function Assert-NotMatches {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    if ($Content -match $Pattern) {
        throw $Message
    }
}

function Select-SourceSection {
    param(
        [string]$Content,
        [string]$StartMarker,
        [string]$EndMarker,
        [string]$Message
    )

    $startIndex = $Content.IndexOf($StartMarker, [System.StringComparison]::Ordinal)
    if ($startIndex -lt 0) {
        throw $Message
    }

    $endIndex = $Content.IndexOf($EndMarker, $startIndex + $StartMarker.Length, [System.StringComparison]::Ordinal)
    if ($endIndex -lt 0) {
        throw $Message
    }

    $Content.Substring($startIndex, $endIndex - $startIndex)
}

$viewerQml = Read-ProjectFile 'src/qml/PdfViewer.qml'

$inlinePdfTextLayer = Select-SourceSection $viewerQml 'id: inlinePdfTextLayer' 'id: textEditTapHandler' 'PdfViewer.qml must define a PDF-native inline text layer.'
$textBlockOverlay = Select-SourceSection $viewerQml 'id: pdfTextBlockOverlay' 'model: root.annotationsForPage(pageFrame.pageIndex)' 'PdfViewer.qml must define PDF text block overlays before annotation rendering.'

Assert-NotMatches $viewerQml 'id:\s*activeTextDraftBlockMask' 'The active editor must not use a full block mask rectangle.'
Assert-NotMatches $viewerQml 'id:\s*activeTextDraftEditor' 'The active editor must not expose a visible widget rectangle as the main surface.'
Assert-Matches $inlinePdfTextLayer 'anchors\.fill:\s*parent' 'The inline text layer must live in page coordinates instead of inside a clipped text widget.'
Assert-Matches $inlinePdfTextLayer 'root\.draftLineMaskRects\(root\.activeTextDraft' 'The active inline layer must clear only extracted PDF line bounds.'
Assert-Matches $inlinePdfTextLayer 'root\.visualRunsForDraft\(root\.activeTextDraft' 'The active inline layer must render the draft through PDF visual runs.'
Assert-Matches $inlinePdfTextLayer 'Text\s*\{[\s\S]*font\.family:\s*root\.displayFontFamily\(modelData\.fontFaceName' 'The visible text must be painted from per-run font metadata, preferring fontFaceName.'
Assert-Matches $inlinePdfTextLayer 'font\.pixelSize:\s*Math\.max\(6,\s*Number\(modelData\.fontSize' 'The visible text must use per-run PDF font size.'
Assert-Matches $inlinePdfTextLayer 'wrapMode:\s*Text\.NoWrap' 'The visible PDF text layer must not let Qt rewrap runs.'
Assert-Matches $inlinePdfTextLayer 'TextEdit\s*\{[\s\S]*id:\s*draftTextArea' 'The editor must keep a bare TextEdit only for keyboard, IME and undo capture.'
Assert-NotMatches $inlinePdfTextLayer 'TextArea\s*\{[\s\S]*id:\s*draftTextArea' 'The active inline editor must not use TextArea for the editable surface.'
Assert-Matches $inlinePdfTextLayer 'color:\s*"transparent"' 'The TextEdit capture surface must not paint editable text.'
Assert-Matches $inlinePdfTextLayer 'opacity:\s*0\.01' 'The TextEdit capture surface must be effectively invisible.'
Assert-Matches $inlinePdfTextLayer 'cursorVisible:\s*false' 'The TextEdit capture surface must not show its own caret.'
Assert-Matches $inlinePdfTextLayer 'id:\s*pdfNativeCaret' 'The inline editor must draw a custom PDF-native caret.'
Assert-Matches $inlinePdfTextLayer 'root\.caretRectForTextPosition\(root\.activeTextDraft' 'The custom caret must be positioned from PDF text geometry.'
Assert-Matches $inlinePdfTextLayer 'id:\s*activeTextSelectionFrame' 'The active text block must show a PDF Agile style selection frame.'
Assert-Matches $inlinePdfTextLayer 'model:\s*root\.selectionHandleRects\(inlinePdfTextLayer\.draftInputRect\)' 'The active selection frame must expose resize/selection handles around the full text object.'
Assert-Matches $inlinePdfTextLayer 'root\.moveCaretInActiveDraft\(pagePoint\)' 'Clicks inside the active draft must move the caret instead of reopening the block.'
Assert-Matches $inlinePdfTextLayer 'mouse\.accepted\s*=\s*true' 'Clicks inside the active draft must not propagate to the page tap handler.'
Assert-Matches $inlinePdfTextLayer 'textFormat:\s*TextEdit\.PlainText' 'The inline editor must keep the committed text model plain while spans remain in the draft model.'
Assert-Matches $inlinePdfTextLayer 'leftPadding:\s*0[\s\S]*rightPadding:\s*0[\s\S]*topPadding:\s*0[\s\S]*bottomPadding:\s*0' 'The hidden TextEdit must not add padding that shifts keyboard geometry.'
Assert-Matches $inlinePdfTextLayer 'wrapMode:\s*root\.activeTextDraft\s*&&\s*root\.activeTextDraft\.layoutMode\s*===\s*"preserve-lines"[\s\S]*TextEdit\.NoWrap[\s\S]*TextEdit\.WordWrap' 'The hidden TextEdit must preserve original line breaks instead of rewrapping on open.'
Assert-NotMatches $inlinePdfTextLayer 'border\.width:\s*draftTextArea\.activeFocus\s*\?\s*1\s*:\s*0' 'The active editor must not draw a focus border around the PDF text.'
Assert-NotMatches $inlinePdfTextLayer 'background:\s*Rectangle' 'The active inline editor must not install a control background.'
Assert-NotMatches $inlinePdfTextLayer 'draftMaskRect' 'The active inline editor must not anchor itself to a white full-block mask.'

Assert-Matches $textBlockOverlay 'id:\s*pdfTextBlockOverlay' 'Text edit mode must draw discoverable full text object boxes like PDF Agile.'
Assert-Matches $textBlockOverlay 'root\.draftLineMaskRects\(modelData' 'Text object overlays must expose the extracted line boxes inside each block.'
Assert-Matches $textBlockOverlay 'border\.color:\s*root\.colorWithOpacity\(Theme\.accent' 'Inactive text object boxes must use a restrained PDF Agile style outline.'

Write-Output 'PDF inline editor visual contract static checks passed.'
