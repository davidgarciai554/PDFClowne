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
$mainQml = Read-ProjectFile 'src/qml/main.qml'

$draftTextFromLines = Select-SourceSection $viewerQml 'function draftTextFromLines(draft)' 'function prepareRichTextDraft' 'PdfViewer.qml must derive initial editor text from PDF line geometry.'
$visualRunsForDraft = Select-SourceSection $viewerQml 'function visualRunsForDraft(draft, pageSize, paperItem, rotation)' 'function draftTextFromLines' 'PdfViewer.qml must derive a visible PDF text layer from extracted runs.'
$draftHasVisualChanges = Select-SourceSection $viewerQml 'function draftHasVisualChanges(draft)' 'function compactFrameForDraft' 'PdfViewer.qml must know when a draft needs visual replacement.'
$prepareRichTextDraft = Select-SourceSection $viewerQml 'function prepareRichTextDraft(seed)' 'function dirtyRangesForText' 'PdfViewer.qml must prepare rich inline text drafts before editing.'
$textPositionForPoint = Select-SourceSection $viewerQml 'function textPositionForPoint(draft, point)' 'function caretRectForTextPosition' 'PdfViewer.qml must map pointer positions to PDF text offsets.'
$caretRectForTextPosition = Select-SourceSection $viewerQml 'function caretRectForTextPosition(draft, cursorPosition, pageSize, paperItem, rotation)' 'function prepareRichTextDraft' 'PdfViewer.qml must map PDF text offsets to a custom caret rectangle.'
$dirtyRangesForText = Select-SourceSection $viewerQml 'function dirtyRangesForText(originalText, nextText)' 'function updateActiveDraftText(text)' 'PdfViewer.qml must compute dirty ranges for edited PDF text.'
$updateActiveDraftText = Select-SourceSection $viewerQml 'function updateActiveDraftText(text)' 'function startTextEdit' 'PdfViewer.qml must update the active draft text model.'
$startTextEdit = Select-SourceSection $viewerQml 'function startTextEdit(pageIndex, point)' 'function activateTextBlock' 'PdfViewer.qml must start inline editing from a page point.'
$activateTextBlock = Select-SourceSection $viewerQml 'function activateTextBlock(pageIndex, block)' 'function commitActiveTextDraft' 'PdfViewer.qml must activate existing text blocks without shifting them.'
$commitActiveTextDraft = Select-SourceSection $viewerQml 'function commitActiveTextDraft()' 'function updateActiveTextDraftStyle' 'PdfViewer.qml must commit the active inline text draft.'
$updateActiveTextDraftStyle = Select-SourceSection $viewerQml 'function updateActiveTextDraftStyle(stylePatch)' 'function clearTextBlockCache' 'PdfViewer.qml must update inline text style only when the user changes it.'
$commitActiveTextEdit = Select-SourceSection $mainQml 'function commitActiveTextEdit(draft)' 'function commitActiveHighlightFromSelection' 'main.qml must commit rich replacement text edits.'
$prepareActiveTextEdit = Select-SourceSection $mainQml 'function prepareActiveTextEdit(pageIndex, point)' 'function commitActiveTextEdit' 'main.qml must prepare PDF-native inline edits.'

Assert-Matches $draftTextFromLines 'var\s+lines\s*=\s*draft\.lines\s*\|\|\s*\[\]' 'Inline editor display text must start from the enriched line model when available.'
Assert-Matches $draftTextFromLines 'if\s*\(line\.text\s*!==\s*undefined\)[\s\S]*parts\.push\(String\(line\.text\s*\|\|\s*""\)\)' 'Inline editor display text must preserve each extracted line text.'
Assert-Matches $draftTextFromLines 'var\s+spans\s*=\s*line\.spans\s*\|\|\s*\[\][\s\S]*lineText\s*\+=\s*String\(\(spans\[j\]\s*\|\|\s*\{\}\)\.text\s*\|\|\s*""\)' 'Inline editor display text must fall back to line spans when a line has no direct text.'
Assert-Matches $draftTextFromLines 'return\s+parts\.join\("\\n"\)' 'Inline editor display text must preserve original line breaks.'
Assert-Matches $visualRunsForDraft 'var\s+explicitRuns\s*=\s*draft\.visualRuns[\s\S]*visualDocumentModel[\s\S]*editableDocumentModel' 'The visible inline layer must prefer persisted visual runs when available.'
Assert-Matches $visualRunsForDraft 'var\s+lines\s*=\s*draft\.lines\s*\|\|\s*\[\]' 'The visible inline layer must derive runs from extracted PDF lines.'
Assert-Matches $visualRunsForDraft 'var\s+currentDraftText\s*=\s*String\(draft\.text\s*\|\|\s*draft\.editablePlainText\s*\|\|\s*""\)' 'The visible inline layer must track the current edited text.'
Assert-Matches $visualRunsForDraft 'var\s+editedLines\s*=\s*currentDraftText\.split\("\\n"\)' 'The visible inline layer must render the current edited text while preserving line geometry.'
Assert-Matches $visualRunsForDraft 'layoutLine\.geometryFidelity\s*===\s*"exact"[\s\S]*layoutLine\.line\.visualRuns\s*\|\|\s*layoutLine\.line\.spans' 'The visible inline layer must preserve original PDF visual runs for unmodified lines instead of flattening them.'
Assert-Matches $visualRunsForDraft 'runRectFromSource\(sourceRun,\s*layoutLine\.line' 'Preserved PDF visual runs must keep their source rectangles.'
Assert-Matches $draftHasVisualChanges 'dirty\.length[\s\S]*>\s*0[\s\S]*return\s+true' 'Inline drafts must only replace the PDF render after text/style edits exist.'
Assert-Matches $draftHasVisualChanges 'String\(draft\.text\s*\|\|\s*""\)\s*!==\s*draftOriginalText\(draft\)' 'Inline drafts must detect text changes against the original block text.'
Assert-Matches $visualRunsForDraft 'fontFaceName:\s*span\.fontFaceName\s*\|\|\s*draft\.fontFaceName' 'The visible inline layer must preserve original fontFaceName metadata by run.'
Assert-Matches $visualRunsForDraft 'fontResourceName:\s*span\.fontResourceName\s*\|\|\s*draft\.fontResourceName' 'The visible inline layer must preserve original PDF font resource metadata by run.'
Assert-Matches $visualRunsForDraft 'fontSize:\s*span\.fontSize\s*\|\|\s*draft\.fontSize' 'The visible inline layer must preserve original PDF font size by run.'
Assert-Matches $prepareRichTextDraft 'seed\.originalBlockModel\s*=\s*JSON\.parse\(JSON\.stringify\(seed\)\)' 'Inline text drafts must preserve the original block model at open time.'
Assert-Matches $prepareRichTextDraft 'var\s+lineText\s*=\s*draftTextFromLines\(seed\)' 'Inline text drafts must derive their initial text from original PDF lines.'
Assert-Matches $prepareRichTextDraft 'if\s*\(lineText\.length\s*>\s*0[\s\S]*seed\.text\s*=\s*lineText' 'Inline text drafts must open with preserved line breaks before Qt can rewrap the paragraph.'
Assert-Matches $prepareRichTextDraft 'if\s*\(!seed\.originalText\)[\s\S]*seed\.originalText\s*=\s*String\(seed\.text\s*\|\|\s*""\)' 'Inline text drafts must keep the initial displayed text as the clean no-edit comparison baseline when needed.'
Assert-Matches $prepareRichTextDraft 'editableDocumentModel\s*=\s*\{[\s\S]*plainText:\s*String\(seed\.text\s*\|\|\s*""\)' 'Inline text drafts must create an editable document model with plainText.'
Assert-Matches $prepareRichTextDraft 'spans:\s*seed\.spans\s*\|\|\s*\[\]' 'Inline text drafts must preserve source spans in the editable document model.'
Assert-Matches $prepareRichTextDraft 'lines:\s*seed\.lines\s*\|\|\s*\[\]' 'Inline text drafts must preserve source lines in the editable document model.'
Assert-Matches $prepareRichTextDraft 'visualRuns:\s*seed\.visualRuns\s*\|\|\s*\[\]' 'Inline text drafts must preserve source visual runs in the editable document model.'
Assert-Matches $prepareRichTextDraft 'fidelity:\s*seed\.fidelity\s*\|\|\s*\{\}' 'Inline text drafts must preserve backend fidelity classification.'
Assert-Matches $prepareRichTextDraft 'seed\.visualDocumentModel\s*=\s*\{' 'Inline text drafts must create a visual document model for the PDF-native renderer.'
Assert-Matches $prepareRichTextDraft 'seed\.editablePlainText\s*=\s*String\(seed\.text\s*\|\|\s*""\)' 'Inline text drafts must keep editablePlainText synchronized from open time.'
Assert-Matches $prepareRichTextDraft 'seed\.layoutMode\s*=\s*"preserve-lines"' 'Inline text drafts must default to preserving original line breaks.'
Assert-Matches $prepareRichTextDraft 'seed\.cursorPosition\s*=' 'Inline text drafts must initialize a cursor position.'
Assert-Matches $prepareRichTextDraft 'seed\.selectionStart\s*=' 'Inline text drafts must initialize selectionStart.'
Assert-Matches $prepareRichTextDraft 'seed\.selectionEnd\s*=' 'Inline text drafts must initialize selectionEnd.'
Assert-Matches $prepareRichTextDraft 'seed\.styleSyncLocked\s*=\s*true' 'Inline text drafts opened from PDFs must lock toolbar style sync until the user changes style.'
Assert-Matches $prepareRichTextDraft 'seed\.geometryFidelity\s*=\s*seed\.geometryFidelity\s*\|\|\s*"exact"' 'Inline text drafts must default to exact geometry until an edit requires estimation.'

Assert-Matches $textPositionForPoint 'lineForTextPosition' 'Pointer hit-testing must share the same line model used by caret placement.'
Assert-Matches $textPositionForPoint 'glyphForTextPosition' 'Pointer hit-testing must inspect glyph geometry, not just the block rectangle.'
Assert-Matches $textPositionForPoint 'charStart' 'Pointer hit-testing must use normalized glyph charStart offsets.'
Assert-Matches $textPositionForPoint 'charEnd' 'Pointer hit-testing must use normalized glyph charEnd offsets.'
Assert-Matches $caretRectForTextPosition 'lineForTextPosition\(draft,\s*cursorPosition\)' 'Caret placement must locate the source PDF line for the current cursor position.'
Assert-Matches $caretRectForTextPosition 'glyphForTextPosition\(line,\s*cursorPosition\)' 'Caret placement must locate the source PDF glyph for the current cursor position.'
Assert-Matches $caretRectForTextPosition 'mapPageRect\(caretRect' 'Caret placement must map PDF geometry to the viewport.'

Assert-Matches $dirtyRangesForText 'if\s*\(original\s*===\s*next\)[\s\S]*return\s*\[\]' 'Unchanged inline edits must keep dirtyRanges empty.'
Assert-Matches $dirtyRangesForText 'while\s*\(prefix\s*<\s*original\.length[\s\S]*original\.charAt\(prefix\)\s*===\s*next\.charAt\(prefix\)' 'Dirty range detection must keep the unchanged prefix out of the dirty range.'
Assert-Matches $dirtyRangesForText 'while\s*\(suffix\s*<\s*original\.length\s*-\s*prefix[\s\S]*original\.charAt\(original\.length\s*-\s*suffix\s*-\s*1\)\s*===\s*next\.charAt\(next\.length\s*-\s*suffix\s*-\s*1\)' 'Dirty range detection must keep the unchanged suffix out of the dirty range.'
Assert-Matches $dirtyRangesForText 'originalEnd:\s*Math\.max\(prefix,\s*original\.length\s*-\s*suffix\)' 'Dirty ranges must retain the matching source range end for later rich-span preservation.'

Assert-Matches $updateActiveDraftText 'activeTextDraft\.editableDocumentModel\.plainText\s*=\s*text' 'Updating inline text must keep editableDocumentModel.plainText current.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.editableDocumentModel\.spans\s*=\s*activeTextDraft\.spans\s*\|\|\s*\[\]' 'Updating inline text must not drop original spans.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.editableDocumentModel\.lines\s*=\s*activeTextDraft\.lines\s*\|\|\s*\[\]' 'Updating inline text must not drop original line geometry.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.editablePlainText\s*=\s*text' 'Updating inline text must keep editablePlainText current.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.visualDocumentModel\.plainText\s*=\s*text' 'Updating inline text must keep visualDocumentModel.plainText current.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.visualDocumentModel\.visualRuns\s*=\s*activeTextDraft\.visualRuns\s*\|\|\s*\[\]' 'Updating inline text must not drop visual run metadata.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.visualDocumentModel\.fidelity\s*=\s*activeTextDraft\.fidelity\s*\|\|\s*\{\}' 'Updating inline text must not drop fidelity metadata.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.dirtyRanges\s*=\s*dirtyRangesForText\(originalText,\s*text\)' 'Updating inline text must mark only the changed range instead of dirtying the whole block.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.editableDocumentModel\.dirtyRanges\s*=\s*activeTextDraft\.dirtyRanges' 'Updating inline text must mirror dirtyRanges into the editable document model.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.visualDocumentModel\.dirtyRanges\s*=\s*activeTextDraft\.dirtyRanges' 'Updating inline text must mirror dirtyRanges into the visual document model.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.cursorPosition\s*=\s*Math\.max\(0,\s*Math\.min\(String\(text\s*\|\|\s*""\)\.length,\s*activeTextDraft\.cursorPosition' 'Text updates must keep the custom caret inside the edited text.'
Assert-Matches $updateActiveDraftText 'activeTextDraft\.geometryFidelity\s*=\s*activeTextDraft\.dirtyRanges\.length\s*>\s*0\s*\?\s*"estimated"\s*:\s*"exact"' 'Text edits must mark geometry as estimated once text diverges from extracted glyph geometry.'

Assert-Matches $startTextEdit 'if\s*\(activeTextDraft\s*&&\s*pointInsideRect\(point,\s*activeTextDraft\.rect' 'Clicking inside the active draft must not commit and reopen the same text block.'
Assert-Matches $startTextEdit 'moveCaretInActiveDraft\(point\)' 'Clicking inside the active draft must only move the caret.'
Assert-Matches $activateTextBlock 'if\s*\(activeTextDraft\s*&&\s*String\(activeTextDraft\.blockKey\s*\|\|\s*""\)\s*===\s*String\(block\.blockKey' 'Re-activating the same block must not commit and recreate the draft.'
Assert-Matches $activateTextBlock 'return' 'Re-activating the same block must return after moving focus/caret state.'

Assert-Matches $commitActiveTextDraft 'draft\.originalBlockModel\s*=\s*activeTextDraft\.originalBlockModel\s*\|\|\s*\{\}' 'Committing inline text must carry the original block model to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.editableDocumentModel\s*=\s*activeTextDraft\.editableDocumentModel' 'Committing inline text must carry the editable document model to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.visualDocumentModel\s*=\s*activeTextDraft\.visualDocumentModel' 'Committing inline text must carry the visual document model to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.editablePlainText\s*=\s*activeTextDraft\.editablePlainText\s*\|\|\s*draft\.text' 'Committing inline text must carry editablePlainText to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.visualRuns\s*=\s*activeTextDraft\.visualRuns\s*\|\|\s*\[\]' 'Committing inline text must carry visualRuns to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.fidelity\s*=\s*activeTextDraft\.fidelity\s*\|\|\s*\{\}' 'Committing inline text must carry fidelity metadata to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.dirtyRanges\s*=\s*activeTextDraft\.dirtyRanges\s*\|\|\s*\[\]' 'Committing inline text must carry dirtyRanges to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.cursorPosition\s*=\s*activeTextDraft\.cursorPosition' 'Committing inline text must carry cursorPosition to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.selectionStart\s*=\s*activeTextDraft\.selectionStart' 'Committing inline text must carry selectionStart to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.selectionEnd\s*=\s*activeTextDraft\.selectionEnd' 'Committing inline text must carry selectionEnd to main.qml.'
Assert-Matches $commitActiveTextDraft 'draft\.geometryFidelity\s*=\s*activeTextDraft\.geometryFidelity' 'Committing inline text must carry geometry fidelity to main.qml.'
Assert-Matches $updateActiveTextDraftStyle 'styleSyncLocked' 'Style updates must ignore toolbar synchronization while opening PDF-native text.'
Assert-Matches $updateActiveTextDraftStyle 'draft\.styleSyncLocked\s*=\s*false' 'A real style update must unlock future user-driven styling.'
Assert-Matches $commitActiveTextEdit 'originalBlockModel:\s*draft\.originalBlockModel\s*\|\|\s*\{\}' 'Replacement edits must persist originalBlockModel.'
Assert-Matches $commitActiveTextEdit 'editableDocumentModel:\s*draft\.editableDocumentModel\s*\|\|\s*\{' 'Replacement edits must persist editableDocumentModel.'
Assert-Matches $commitActiveTextEdit 'visualDocumentModel:\s*draft\.visualDocumentModel\s*\|\|\s*\{' 'Replacement edits must persist visualDocumentModel.'
Assert-Matches $commitActiveTextEdit 'editablePlainText:\s*String\(draft\.editablePlainText\s*\|\|\s*text\)' 'Replacement edits must persist editablePlainText.'
Assert-Matches $commitActiveTextEdit 'visualRuns:\s*draft\.visualRuns\s*\|\|\s*\[\]' 'Replacement edits must persist visualRuns.'
Assert-Matches $commitActiveTextEdit 'fidelity:\s*draft\.fidelity\s*\|\|\s*\{\}' 'Replacement edits must persist fidelity metadata.'
Assert-Matches $commitActiveTextEdit 'dirtyRanges:\s*draft\.dirtyRanges\s*\|\|\s*\[\]' 'Replacement edits must persist dirtyRanges for partial rich edits.'
Assert-Matches $commitActiveTextEdit 'cursorPosition:\s*Number\(draft\.cursorPosition' 'Replacement edits must persist cursorPosition.'
Assert-Matches $commitActiveTextEdit 'selectionStart:\s*Number\(draft\.selectionStart' 'Replacement edits must persist selectionStart.'
Assert-Matches $commitActiveTextEdit 'selectionEnd:\s*Number\(draft\.selectionEnd' 'Replacement edits must persist selectionEnd.'
Assert-Matches $commitActiveTextEdit 'geometryFidelity:\s*String\(draft\.geometryFidelity' 'Replacement edits must persist geometry fidelity.'
Assert-Matches $prepareActiveTextEdit 'syncingPdfTextStyle\s*=\s*true' 'Opening a PDF text block must guard toolbar style synchronization.'
Assert-Matches $prepareActiveTextEdit 'syncingPdfTextStyle\s*=\s*false' 'Opening a PDF text block must release toolbar style synchronization after seed defaults are set.'
Assert-Matches $prepareActiveTextEdit 'seed\.pdfFontFamily' 'Opening a PDF text block must preserve the original PDF font identity separately from toolbar normalized fonts.'

Write-Output 'PDF inline editor state static checks passed.'
