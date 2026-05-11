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

$cmake = Read-ProjectFile 'CMakeLists.txt'
$mainCpp = Read-ProjectFile 'src/main.cpp'
$viewer = Read-ProjectFile 'src/qml/PdfViewer.qml'
$editOverlay = Read-ProjectFile 'src/qml/editor/PdfEditOverlay.qml'
$glyphModelHeader = Read-ProjectFile 'src/backend/text/PdfGlyphRunModel.h'
$extractorHeader = Read-ProjectFile 'src/backend/text/PdfTextExtractor.h'
$extractorSource = Read-ProjectFile 'src/backend/text/PdfTextExtractor.cpp'
$fontResolverHeader = Read-ProjectFile 'src/backend/text/PdfFontResolver.h'
$controllerHeader = Read-ProjectFile 'src/backend/text/PdfEditSessionController.h'
$controllerSource = Read-ProjectFile 'src/backend/text/PdfEditSessionController.cpp'
$overlayItemHeader = Read-ProjectFile 'src/backend/render/PdfGlyphOverlayItem.h'
$overlayItemSource = Read-ProjectFile 'src/backend/render/PdfGlyphOverlayItem.cpp'
$scratchRendererHeader = Read-ProjectFile 'src/backend/render/PdfScratchPageRenderer.h'
$writerHeader = Read-ProjectFile 'src/backend/pdf/PdfContentWriter.h'
$writerSource = Read-ProjectFile 'src/backend/pdf/PdfContentWriter.cpp'
$saveCoordinatorHeader = Read-ProjectFile 'src/backend/pdf/PdfSaveCoordinator.h'

Assert-Matches $cmake 'find_package\(Freetype REQUIRED\)' 'CMake must require FreeType explicitly for PDF text editing.'
Assert-Matches $cmake 'find_package\(harfbuzz CONFIG REQUIRED\)' 'CMake must require HarfBuzz explicitly for PDF text editing.'
Assert-Matches $cmake 'Freetype::Freetype' 'PDFClowne must link FreeType explicitly.'
Assert-Matches $cmake 'harfbuzz::harfbuzz' 'PDFClowne must link HarfBuzz explicitly.'
Assert-Matches $cmake 'src/backend/text/PdfEditSessionController\.cpp' 'CMake must compile PdfEditSessionController.cpp.'
Assert-Matches $cmake 'src/backend/render/PdfGlyphOverlayItem\.cpp' 'CMake must compile PdfGlyphOverlayItem.cpp.'
Assert-Matches $cmake 'src/qml/editor/PdfEditOverlay\.qml' 'CMake must package the single edit overlay QML file.'

Assert-Matches $mainCpp 'qmlRegisterType<\s*PDFClowne::Editing::PdfEditSessionController\s*>' 'main.cpp must register PdfEditSessionController.'
Assert-Matches $mainCpp 'qmlRegisterType<\s*PDFClowne::Render::PdfGlyphOverlayItem\s*>' 'main.cpp must register PdfGlyphOverlayItem.'

Assert-Matches $glyphModelHeader 'struct\s+PdfGlyph\s*\{' 'PdfGlyphRunModel must declare PdfGlyph.'
Assert-Matches $glyphModelHeader 'pageIndex[\s\S]*blockIndex[\s\S]*lineIndex[\s\S]*spanIndex[\s\S]*unicode[\s\S]*originalGid[\s\S]*origin[\s\S]*quad[\s\S]*bbox[\s\S]*advance[\s\S]*fontName[\s\S]*fontResourceKey[\s\S]*fontSize[\s\S]*fillColor[\s\S]*wmode[\s\S]*bidiLevel[\s\S]*direction[\s\S]*trm' 'PdfGlyph must preserve glyph-level PDF identity and geometry.'
Assert-Matches $glyphModelHeader 'struct\s+PdfRun\s*\{' 'PdfGlyphRunModel must declare PdfRun.'
Assert-Matches $glyphModelHeader 'glyphs[\s\S]*plainText[\s\S]*fontResourceKey[\s\S]*fillColor[\s\S]*wmode[\s\S]*bidiLevel[\s\S]*direction[\s\S]*trm' 'PdfRun must be grouped by exact PDF shaping identity.'
Assert-Matches $glyphModelHeader 'struct\s+PdfEditableRegion\s*\{' 'PdfGlyphRunModel must declare PdfEditableRegion.'
Assert-Matches $glyphModelHeader 'glyphRange[\s\S]*unionQuad[\s\S]*baselineStart[\s\S]*baselineEnd[\s\S]*box[\s\S]*script[\s\S]*language' 'PdfEditableRegion must keep editable geometry separate from paragraphs.'

Assert-Matches $extractorHeader 'class\s+PdfTextExtractor' 'PdfTextExtractor must be the extraction boundary.'
Assert-Matches $extractorSource 'FZ_STEXT_PRESERVE_SPANS' 'PdfTextExtractor must preserve spans.'
Assert-Matches $extractorSource 'FZ_STEXT_PRESERVE_LIGATURES' 'PdfTextExtractor must preserve ligatures.'
Assert-Matches $extractorSource 'FZ_STEXT_ACCURATE_BBOXES' 'PdfTextExtractor must request accurate bboxes.'
Assert-Matches $extractorSource 'FZ_STEXT_ACCURATE_ASCENDERS' 'PdfTextExtractor must request accurate ascenders.'
Assert-Matches $extractorSource 'FZ_STEXT_ACCURATE_SIDE_BEARINGS' 'PdfTextExtractor must request accurate side bearings.'
Assert-Matches $extractorSource 'FZ_STEXT_COLLECT_STYLES' 'PdfTextExtractor must collect styles.'
Assert-Matches $extractorSource 'fontResourceKey' 'PdfTextExtractor must emit stable font resource keys, not family-only grouping.'

Assert-Matches $fontResolverHeader 'requiresSubstitute' 'PdfFontResolver must mark runs with missing embedded font programs.'
Assert-Matches $controllerHeader 'class\s+PdfEditSessionController\s*:\s*public\s+QObject' 'PdfEditSessionController must be the single edit pipeline controller.'
Assert-Matches $controllerHeader 'beginSession' 'PdfEditSessionController must expose beginSession for first-click editing.'
Assert-Matches $controllerHeader 'QInputMethodEvent|inputMethod' 'PdfEditSessionController must own keyboard/IME state outside visible QML text.'
Assert-Matches $controllerSource 'saveAsCopy|replaceOriginalTransaction' 'PdfEditSessionController must save through the temp/validated save coordinator.'
Assert-Matches $controllerSource 'pdf_redact_page' 'PdfEditSessionController must redact original text before writing replacement streams.'
Assert-Matches $controllerSource 'pdf_save_document' 'PdfEditSessionController must write a real edited PDF document.'
Assert-NotMatches $controllerSource 'writer tipografico MuPDF esta preparado' 'PdfEditSessionController.saveDocument must not be a non-writing stub.'

Assert-Matches $overlayItemHeader 'class\s+PdfGlyphOverlayItem\s*:\s*public\s+QQuickItem' 'PdfGlyphOverlayItem must be a QQuickItem.'
Assert-Matches $overlayItemSource 'ItemHasContents' 'PdfGlyphOverlayItem must opt into scene graph painting.'
Assert-Matches $overlayItemSource 'updatePaintNode' 'PdfGlyphOverlayItem must paint through updatePaintNode.'
Assert-NotMatches $overlayItemHeader 'QQuickPaintedItem' 'PdfGlyphOverlayItem must not use QQuickPaintedItem.'
Assert-NotMatches $overlayItemSource 'QQuickPaintedItem' 'PdfGlyphOverlayItem must not use QQuickPaintedItem.'
Assert-NotMatches ($glyphModelHeader + $extractorHeader + $fontResolverHeader + $controllerHeader + $overlayItemHeader + $overlayItemSource) 'QRawFont|QGlyphRun' 'The edit renderer must not use QRawFont or QGlyphRun as the final visual clone path.'

Assert-Matches $scratchRendererHeader 'redact|Redact|redaction|Redaction' 'PdfScratchPageRenderer must model redacted scratch-page rendering.'
Assert-Matches ($writerHeader + $writerSource) 'BT[\s\S]*Tf[\s\S]*Tm[\s\S]*Tj|TJ' 'PdfContentWriter must own generated PDF text content operators.'
Assert-Matches $writerSource '\srg\\n' 'PdfContentWriter must emit fill color into the replacement text stream.'
Assert-Matches $saveCoordinatorHeader 'temp|backup|replace|transaction' 'PdfSaveCoordinator must preserve temp-validate-replace save semantics.'

Assert-NotMatches $editOverlay '\bText\s*\{|\bTextEdit\s*\{|\bTextInput\s*\{' 'PdfEditOverlay.qml must not paint/edit visible text with Qt text items.'
Assert-Matches $editOverlay 'PdfGlyphOverlayItem\s*\{' 'PdfEditOverlay.qml must use the C++ scene graph glyph overlay.'
Assert-Matches $editOverlay 'TapHandler\s*\{' 'PdfEditOverlay.qml must use one root pointer capturer.'
Assert-Matches $editOverlay 'forceActiveFocus\(Qt\.MouseFocusReason\)' 'PdfEditOverlay.qml must focus synchronously on first click.'

Assert-NotMatches $viewer 'EditableTextBox\s*\{' 'PdfViewer must no longer instantiate the old editable text overlay.'
Assert-NotMatches $viewer 'id:\s*phase5BlockOverlay' 'PdfViewer must remove the duplicated phase 5 block overlay.'
Assert-Matches $viewer 'PdfEditOverlay\s*\{' 'PdfViewer must host the single edit overlay.'

Write-Output 'PdfEditSessionController architecture contract checks passed.'
