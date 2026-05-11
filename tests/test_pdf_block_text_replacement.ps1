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

Assert-Matches $pdfDocumentHeader 'Q_INVOKABLE\s+QString\s+textBlocksForPage\(int\s+pageIndex\);' 'PdfDocument must expose textBlocksForPage so QML can show paragraph/block edit zones.'
Assert-Matches $pdfDocumentSource 'QString\s+PdfDocument::textBlocksForPage\(int\s+pageIndex\)' 'PdfDocument must implement textBlocksForPage.'
Assert-Matches $pdfDocumentSource 'int\s+textBlockExtractionFlags\(\)' 'Text block extraction must centralize MuPDF structured-text precision flags for the fidelity work.'
Assert-Matches $pdfDocumentSource 'FZ_STEXT_PRESERVE_WHITESPACE' 'Text block extraction must preserve whitespace before block replacement rewrites are refined.'
Assert-Matches $pdfDocumentSource 'FZ_STEXT_ACCURATE_BBOXES' 'Text block extraction must request accurate bounding boxes before block replacement rewrites are refined.'
Assert-Matches $pdfDocumentSource 'style\.insert\(QStringLiteral\("fontFamily"\),\s*fontName\);' 'Detected text blocks must preserve the original font family name for inline editing.'
Assert-Matches $pdfDocumentSource 'item\.insert\(QStringLiteral\("text"\),\s*blockText\);' 'Detected text blocks must preserve the original block text without trimming it.'
Assert-Matches $pdfDocumentSource 'PDF_ANNOT_REDACT' 'Saving a real text replacement must create redaction annotations or equivalent text removal primitives.'
Assert-Matches $pdfDocumentSource 'pdf_apply_redaction|pdf_redact_page' 'Saving a real text replacement must remove the original PDF text from the page content.'
Assert-Matches $pdfDocumentSource 'QVector<ReplacementTextRun>\s+replacementRunsFromEnrichedModel' 'Saving a block replacement must compose from the enriched line/span model before falling back to ad-hoc wrapping.'
Assert-Matches $pdfDocumentSource 'firstReusableFontResource\(ctx,\s*page,\s*run\.style,\s*edit\)' 'Saving a block replacement must try to reuse a page font resource before creating fallback fonts.'
Assert-Matches $pdfDocumentSource 'bool\s+pdfLiteralLatin1EscapedString\(const\s+QString\s+&text,\s*QByteArray\s+\*escaped\)' 'Saving a block replacement must validate literal-string encoding instead of silently replacing unsupported glyphs.'
Assert-Matches $pdfDocumentSource 'Replacement text contains characters this PDF text composer cannot encode safely yet' 'Saving must fail explicitly when replacement text cannot be encoded safely by the current composer.'
Assert-Matches $pdfDocumentSource 'bool\s+isBase14FontName\(const\s+QString\s+&fontName\)' 'Page font reuse must be limited to known simple Base14 resources until custom font encodings are resolved.'
Assert-Matches $pdfDocumentSource 'subtypeName\s*!=\s*"Type1"[\s\S]*return\s+false;' 'Page font reuse must reject TrueType/Type3/custom-encoded fonts instead of emitting Latin bytes through arbitrary encodings.'
Assert-Matches $pdfDocumentSource 'pdf_page_transform maps Fitz page coordinates back to PDF user space' 'The replacement text matrix must document the MuPDF coordinate direction used when appending raw page content.'
Assert-Matches $pdfDocumentSource 'ensureBase14FontResource' 'Saving a block replacement may use Base14 only through an explicit fallback path.'
Assert-Matches $pdfDocumentSource 'fallbackReplacementRuns[\s\S]*wrapTextForRect' 'Approximate wrapping must be isolated to the fallback replacement path.'
Assert-Matches $pdfDocumentSource 'pdf_add_stream|pdf_update_stream' 'Saving a real text replacement must write regenerated text back into the page content stream.'
Assert-Matches $mainQml '"replaceTextBlock"' 'main.qml must still commit existing block text edits as real replacement edits.'
Assert-Matches $mainQml 'draft\.type\s*===\s*"freeText"[\s\S]*\?\s*"freeText"\s*:\s*"replaceTextBlock"' 'main.qml must reserve FreeText only for explicit free-text insertion, not normal block replacement.'
Assert-Matches $mainQml 'fontFamily:\s*String\(draft\.fontFamily\s*\|\|\s*editFontFamily\s*\|\|\s*"Helvetica"\)' 'Block replacements must preserve the detected draft font family when committing edits.'
Assert-Matches $mainQml 'fontSize:\s*Math\.max\(6,\s*Math\.min\(144,\s*Number\(draft\.fontSize\s*\|\|\s*editFontSize\)' 'Block replacements must preserve the draft font size when committing edits.'
Assert-Matches $mainQml 'if \(!seed\.fontFamily\)\s*seed\.fontFamily = editFontFamily' 'Preparing a text edit must not overwrite an already detected font family.'
Assert-Matches $mainQml 'var text = String\(draft\.text \|\| ""\)[\s\S]*if \(text\.trim\(\)\.length === 0\)' 'Committing a text edit must preserve original whitespace while still rejecting visually empty edits.'
Assert-Matches $mainQml 'Shortcut \{ sequence: "Ctrl\+Z"; enabled: \(!pdfViewer \|\| !pdfViewer\.inlineTextEditingActive\)' 'Global Ctrl+Z must be disabled while inline text editing is active.'
Assert-Matches $viewerQml 'property\s+var\s+textBlocksForPageAction:\s*null' 'PdfViewer must accept a callback for detected text blocks.'
Assert-Matches $viewerQml 'readonly property bool inlineTextEditingActive:\s*!!activeTextDraft' 'PdfViewer must expose when inline text editing is active.'
Assert-Matches $viewerQml 'function\s+pageTextBlocks\(pageIndex\)' 'PdfViewer must cache and expose detected edit blocks per page.'
Assert-Matches $viewerQml 'function\s+mapPageRect\(rect,\s*pageSize,\s*imageItem,\s*rotation\)[\s\S]*return \{\s*x: imageItem\.x \+ \(rectX / pageWidth\) \* imageWidth,' 'Mapping block rectangles must use page coordinates directly because the page container already handles visual rotation.'
Assert-Matches $viewerQml 'model:\s*root\.pageTextBlocks\(pageFrame\.pageIndex\)' 'PdfViewer must render visible edit zones for detected text blocks.'
Assert-Matches $viewerQml 'function\s+hasReplacementForBlock\(pageIndex,\s*blockKey\)' 'PdfViewer must know when a detected block already has a replacement preview.'
Assert-Matches $viewerQml '!\s*root\.hasReplacementForBlock\(pageFrame\.pageIndex,\s*modelData\.blockKey\)' 'PdfViewer must hide the original detected box when a replacement already exists for that block.'
Assert-Matches $viewerQml 'parent\.replacementBlock[\s\S]*root\.draftLineMaskRects\(annotationDelegateComponent\.modelData' 'ReplaceTextBlock preview must clear extracted line bounds instead of drawing a full text box.'
Assert-Matches $viewerQml 'parent\.replacementBlock[\s\S]*root\.visualRunsForDraft\(annotationDelegateComponent\.modelData' 'ReplaceTextBlock preview must repaint committed text from PDF visual runs.'
Assert-Matches $viewerQml 'id:\s*inlinePdfTextLayer' 'The inline text editor must use a PDF-native visual layer while editing.'
Assert-Matches $viewerQml 'root\.visualRunsForDraft\(root\.activeTextDraft' 'The inline editor must render visible text from detected PDF runs, not the hidden TextEdit.'
Assert-Matches $viewerQml 'font\.family:\s*root\.displayFontFamily\(modelData\.fontFaceName' 'The inline editor must render using the detected run font face before falling back.'
Assert-Matches $viewerQml 'draft\.fontFamily = activeTextDraft\.fontFamily \|\| editFontFamily' 'The inline editor must commit the active draft font family instead of forcing the global toolbar font.'
Assert-Matches $viewerQml 'TextEdit\s*\{[\s\S]*id:\s*draftTextArea[\s\S]*color:\s*"transparent"[\s\S]*opacity:\s*0\.01' 'The inline editor input widget must be invisible instead of showing a separate text box.'
Assert-Matches $viewerQml 'leftPadding:\s*0[\s\S]*topPadding:\s*0[\s\S]*bottomPadding:\s*0' 'The inline editor must align text to the original block without extra padding.'
Assert-Matches $viewerQml '\(event\.modifiers & Qt\.ControlModifier\) && event\.key === Qt\.Key_Z[\s\S]*draftTextArea\.undo\(\)' 'Ctrl+Z must undo inside the inline text editor.'
Assert-Matches $viewerQml '\(event\.modifiers & Qt\.ControlModifier\) && event\.key === Qt\.Key_Y[\s\S]*draftTextArea\.redo\(\)' 'Ctrl+Y must redo inside the inline text editor.'
Assert-Matches $viewerQml 'annotationDelegateComponent\.modelData\.type === "replaceTextBlock"[\s\S]*root\.activateTextBlock\(pageFrame\.pageIndex,\s*annotationDelegateComponent\.modelData\)' 'Clicking an existing replacement block must reopen in-place editing.'

Write-Output 'PDF block text replacement static checks passed.'
