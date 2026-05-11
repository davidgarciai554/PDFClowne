$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainQmlPath = Join-Path $root 'src/qml/main.qml'
$viewerPath = Join-Path $root 'src/qml/PdfViewer.qml'
$pdfHeaderPath = Join-Path $root 'src/backend/PdfDocument.h'
$pdfSourcePath = Join-Path $root 'src/backend/PdfDocument.cpp'
$obsidianPath = Join-Path $root 'Obsidian/tareas/Fase Edicion.md'

$mainQml = Get-Content -LiteralPath $mainQmlPath -Raw
$viewer = Get-Content -LiteralPath $viewerPath -Raw
$pdfHeader = Get-Content -LiteralPath $pdfHeaderPath -Raw
$pdfSource = Get-Content -LiteralPath $pdfSourcePath -Raw
$obsidian = Get-Content -LiteralPath $obsidianPath -Raw

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

Assert-Matches $pdfHeader 'Q_INVOKABLE\s+QString\s+textEditAt\(int\s+pageIndex,\s*const\s+QPointF\s*&point\);' 'PdfDocument must expose textEditAt so QML can seed editable text from MuPDF structured text.'
Assert-Matches $pdfHeader 'saveEditedCopy\(const\s+QString\s+&source,\s*const\s+QString\s+&target,\s*const\s+QString\s+&pageOrderJson,\s*const\s+QString\s+&rotationsJson,\s*const\s+QString\s+&password\s*=\s*\{\},\s*const\s+QString\s+&annotationsJson\s*=\s*\{\}\s*\)' 'PdfDocument::saveEditedCopy must accept annotation edits without breaking existing callers.'
Assert-Matches $pdfSource 'FZ_STEXT_PRESERVE_SPANS\s*\|\s*FZ_STEXT_COLLECT_STYLES' 'textEditAt must collect span/style data so defaults match the clicked PDF text.'
Assert-Matches $pdfSource 'fz_font_name\(ctx,\s*ch->font\)' 'Text block style extraction must capture the source PDF font for clicked text.'
Assert-Matches $pdfSource 'ch\s*\?\s*ch->size|ch->size' 'Text block style extraction must capture the source PDF text size.'
Assert-Matches $pdfSource 'ch\s*\?\s*ch->argb|ch->argb' 'Text block style extraction must capture the source PDF text color.'
Assert-Matches $pdfSource 'result\s*=\s*buildTextBlockJson\(ctx,\s*pageIndex,\s*block(?:,\s*[^)]*)?\);' 'textEditAt must return the enriched block model produced from clicked MuPDF text.'
Assert-Matches $pdfSource 'pdf_create_annot\(ctx,\s*page,\s*PDF_ANNOT_FREE_TEXT\)' 'Saving text edits must create FreeText annotations.'
Assert-Matches $pdfSource 'pdf_set_annot_default_appearance\(ctx,\s*annot' 'FreeText annotations must persist font, size, and color through MuPDF default appearance.'
Assert-Matches $pdfSource 'pdf_set_annot_rich_contents\(ctx,\s*annot' 'FreeText annotations must persist rich styling for bold, italic, and underline.'
Assert-Matches $pdfSource 'pdf_create_annot\(ctx,\s*page,\s*PDF_ANNOT_HIGHLIGHT\)' 'Highlighter edits must create PDF highlight annotations.'
Assert-Matches $pdfSource 'pdf_set_annot_quad_points\(ctx,\s*annot' 'Highlighter edits must persist exact text selection quads.'
Assert-Matches $pdfSource 'pdf_update_annot\(ctx,\s*annot\)' 'New annotations must synthesize appearances before saving.'
Assert-Matches $pdfSource 'hasAnnotationChanges' 'Saving must treat annotation-only edits as real pending changes.'

Assert-Matches $mainQml 'property\s+string\s+activeEditTool:\s*"text"' 'main.qml must track the active edit tool.'
Assert-Matches $mainQml 'property\s+bool\s+editBoldEnabled:\s*false' 'main.qml must expose bold state for PDF text edits.'
Assert-Matches $mainQml 'property\s+bool\s+editItalicEnabled:\s*false' 'main.qml must expose italic state for PDF text edits.'
Assert-Matches $mainQml 'property\s+bool\s+editUnderlineEnabled:\s*false' 'main.qml must expose underline state for PDF text edits.'
Assert-Matches $mainQml 'editAnnotationsJson:\s*"\[\]"' 'New documents must initialize editable annotation state.'
Assert-Matches $mainQml 'editAnnotations:\s*parseJsonArray\(doc\.editAnnotationsJson' 'Undo/redo snapshots must include annotation edits.'
Assert-Matches $mainQml 'doc\.editAnnotationsJson\s*\|\|\s*"\[\]"' 'Save transactions must pass pending annotation edits to the backend.'
Assert-Matches $mainQml 'function\s+prepareActiveTextEdit\(pageIndex,\s*point\)' 'main.qml must seed text edits from the clicked PDF location.'
Assert-Matches $mainQml 'function\s+commitActiveTextEdit\(draft\)' 'main.qml must commit edited text annotations.'
Assert-Matches $mainQml 'function\s+commitActiveHighlightFromSelection\(\)' 'main.qml must create highlighter annotations from selection geometry.'
Assert-Matches $mainQml 'function\s+eraseActiveEditAnnotation\(annotationId\)' 'main.qml must erase pending edit annotations.'
Assert-Matches $mainQml 'activeEditTool\s*=\s*"highlight"' 'The edit toolbar must expose a highlighter mode.'
Assert-Matches $mainQml 'activeEditTool\s*=\s*"erase"' 'The edit toolbar must expose an eraser mode.'
Assert-Matches $mainQml 'editBoldEnabled\s*=\s*!editBoldEnabled' 'The edit toolbar must include bold toggling.'
Assert-Matches $mainQml 'editItalicEnabled\s*=\s*!editItalicEnabled' 'The edit toolbar must include italic toggling.'
Assert-Matches $mainQml 'editUnderlineEnabled\s*=\s*!editUnderlineEnabled' 'The edit toolbar must include underline toggling.'

Assert-Matches $viewer 'property\s+string\s+viewMode:\s*"view"' 'PdfViewer must expose a view/edit mode switch.'
Assert-Matches $viewer 'readonly property bool editModeEnabled:\s*viewMode\s*===\s*"edit"' 'PdfViewer must derive editModeEnabled from viewMode.'
Assert-Matches $viewer 'property\s+string\s+editTool:\s*"text"' 'PdfViewer must receive the active edit tool.'
Assert-Matches $viewer 'property\s+var\s+editAnnotations:\s*\[\]' 'PdfViewer must render pending annotation edits.'
Assert-Matches $viewer 'property\s+var\s+textEditSeedAction:\s*null' 'PdfViewer must request MuPDF text defaults on click.'
Assert-Matches $viewer 'property\s+var\s+commitTextEditAction:\s*null' 'PdfViewer must send text edits back to the document model.'
Assert-Matches $viewer 'property\s+var\s+commitHighlightAction:\s*null' 'PdfViewer must commit highlighter edits from selection.'
Assert-Matches $viewer 'property\s+var\s+eraseAnnotationAction:\s*null' 'PdfViewer must support erasing pending annotations.'
Assert-Matches $viewer 'editModeEnabled\s*&&\s*root\.editTool\s*===\s*"text"' 'Text editing gestures must be gated by the Edit toolbar mode.'
Assert-Matches $viewer 'root\.editTool\s*===\s*"highlight"' 'Highlight gestures must be gated by highlighter mode.'
Assert-Matches $viewer 'editModeEnabled\s*&&\s*root\.editTool\s*===\s*"erase"' 'Erase gestures must be gated by eraser mode.'
Assert-Matches $viewer 'annotationDelegateComponent' 'PdfViewer must render pending text and highlighter annotations in the page UI.'
Assert-Matches $viewer 'commitActiveTextDraft\(\)' 'PdfViewer must provide an explicit way to finish text edits.'
Assert-Matches $viewer 'Canvas\s*\{[\s\S]*id:\s*thumbnailTrashIcon' 'The thumbnail delete action must include an integrated trash icon.'
Assert-NotMatches $viewer 'text:\s*"Eliminar pagina"\s*[\r\n]+\s*enabled:' 'The thumbnail delete action must not be plain text only.'

Assert-Matches $obsidian 'Eliminar paginas.*menu de miniaturas' 'Obsidian phase notes must mention page deletion from the thumbnail menu.'
Assert-Matches $obsidian 'Texto editable.*FreeText' 'Obsidian phase notes must document text editing as persisted FreeText annotations.'
Assert-Matches $obsidian 'Rotulador.*Highlight' 'Obsidian phase notes must document highlighter annotations.'
Assert-Matches $obsidian 'Borrador.*anotaciones pendientes' 'Obsidian phase notes must document erasing pending annotations.'

Write-Output 'PDF edit annotation tools static checks passed.'
