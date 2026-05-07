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
$pdfDocumentHeader = Read-ProjectFile 'src/backend/PdfDocument.h'
$pdfDocumentSource = Read-ProjectFile 'src/backend/PdfDocument.cpp'

$sourceTextLinesForDraft = Select-SourceSection $viewerQml 'function sourceTextLinesForDraft(draft)' 'function estimateTextWidth' 'PdfViewer.qml must expose sourceTextLinesForDraft as the editable layout source.'
$editableLineLayout = Select-SourceSection $viewerQml 'function editableLineLayout(draft, sourceLine, editedLineText)' 'function editableLayoutForDraft' 'PdfViewer.qml must build editable line layouts.'
$editableLayoutForDraft = Select-SourceSection $viewerQml 'function editableLayoutForDraft(draft)' 'function visualRunsForDraf' 'PdfViewer.qml must build a single editable layout consumed by render/hit/caret.'
$visualRunsForDraft = Select-SourceSection $viewerQml 'function visualRunsForDraft(draft, pageSize, paperItem, rotation)' 'function draftTextFromLines' 'PdfViewer.qml must render from editable layout.'
$textPositionForPoint = Select-SourceSection $viewerQml 'function textPositionForPoint(draft, point)' 'function caretRectForTextPosition' 'PdfViewer.qml must hit-test from editable layout.'
$caretRectForTextPosition = Select-SourceSection $viewerQml 'function caretRectForTextPosition(draft, cursorPosition, pageSize, paperItem, rotation)' 'function prepareRichTextDraft' 'PdfViewer.qml must place the caret from editable layout.'
$inlinePdfTextLayer = Select-SourceSection $viewerQml 'Item {' 'TapHandler {' 'PdfViewer.qml must contain inline editor visual layer.'

Assert-Matches $pdfDocumentHeader 'Q_INVOKABLE\s+QString\s+textElementsForPage\(int\s+pageIndex\);' 'PdfDocument must expose detected PDF elements, not only raw text block lookup.'
Assert-Matches $pdfDocumentSource 'QString\s+stableTextElementId\(' 'PdfDocument must create stable text element ids for editor state and cache keys.'
Assert-Matches $pdfDocumentSource 'item\.insert\(QStringLiteral\("elementType"\),\s*QStringLiteral\("text"\)\);' 'Text block JSON must identify text elements explicitly.'
Assert-Matches $pdfDocumentSource 'item\.insert\(QStringLiteral\("stableElementId"\)' 'Text block JSON must carry a stable element id.'
Assert-Matches $pdfDocumentSource 'QString PdfDocument::textElementsForPage\(int pageIndex\)' 'PdfDocument must implement textElementsForPage.'
Assert-Matches $pdfDocumentSource 'element\.insert\(QStringLiteral\("editable"\),\s*true\);' 'Detected text elements must be marked editable.'
Assert-Matches $pdfDocumentSource 'element\.insert\(QStringLiteral\("editable"\),\s*false\);' 'Detected non-text elements must be selectable/inspectable without pretending to be editable.'

Assert-Matches $sourceTextLinesForDraft 'start:\s*offset' 'Editable source lines must carry global text start offsets.'
Assert-Matches $sourceTextLinesForDraft 'end:\s*offset\s*\+\s*text\.length' 'Editable source lines must carry global text end offsets.'
Assert-Matches $sourceTextLinesForDraft 'glyphs:\s*glyphs' 'Editable source lines must flatten glyphs for layout/hit-testing.'

Assert-Matches $editableLineLayout 'var\s+insertionPoints\s*=\s*\[\]' 'Editable line layout must produce insertion points for every caret offset.'
Assert-Matches $editableLineLayout 'glyph\.advance' 'Editable line layout must prefer MuPDF glyph advances.'
Assert-Matches $editableLineLayout 'geometryFidelity:\s*editedLineText\s*===\s*originalLineText\s*\?\s*"exact"\s*:\s*"estimated"' 'Edited line layout must classify exact vs estimated geometry.'
Assert-Matches $editableLineLayout 'runs:\s*\[\{' 'Editable line layout must emit renderable runs.'

Assert-Matches $editableLayoutForDraft 'sourceTextLinesForDraft\(draft\)' 'The editable layout must be derived from source PDF lines.'
Assert-Matches $editableLayoutForDraft 'editableLineLayout\(draft,\s*sourceLines\[i\]' 'The editable layout must build each line through editableLineLayout.'
Assert-Matches $editableLayoutForDraft 'geometryFidelity' 'The editable layout must expose geometry fidelity.'

Assert-Matches $visualRunsForDraft 'var\s+layout\s*=\s*editableLayoutForDraft\(draft\)' 'Visible text runs must come from the editable layout engine.'
Assert-Matches $textPositionForPoint 'var\s+layout\s*=\s*editableLayoutForDraft\(draft\)' 'Pointer hit-testing must use the editable layout engine.'
Assert-Matches $textPositionForPoint 'insertionPoints' 'Pointer hit-testing must choose among editable insertion points.'
Assert-Matches $caretRectForTextPosition 'var\s+layout\s*=\s*editableLayoutForDraft\(draft\)' 'Caret placement must use the editable layout engine.'
Assert-Matches $caretRectForTextPosition 'insertionPoints' 'Caret placement must use editable insertion points.'
Assert-Matches $inlinePdfTextLayer 'selectionRectsForDraft' 'Inline editor must render custom selection rectangles from the editable layout.'

Write-Output 'PDF element editing engine contract checks passed.'
