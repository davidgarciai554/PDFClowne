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

$cmake = Read-ProjectFile 'CMakeLists.txt'
$mainCpp = Read-ProjectFile 'src/main.cpp'
$mainQml = Read-ProjectFile 'src/qml/main.qml'
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
$scratchRendererSource = Read-ProjectFile 'src/backend/render/PdfScratchPageRenderer.cpp'
$writerHeader = Read-ProjectFile 'src/backend/pdf/PdfContentWriter.h'
$writerSource = Read-ProjectFile 'src/backend/pdf/PdfContentWriter.cpp'
$saveCoordinatorHeader = Read-ProjectFile 'src/backend/pdf/PdfSaveCoordinator.h'
$saveCoordinatorSource = Read-ProjectFile 'src/backend/pdf/PdfSaveCoordinator.cpp'

Assert-Matches $cmake 'find_package\(Qt6 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Qml Svg\)' `
    'CMake must request the native Qt/QML components used by edit mode.'
Assert-Matches $cmake 'find_package\(Freetype REQUIRED\)' `
    'CMake must require FreeType explicitly.'
Assert-Matches $cmake 'find_package\(harfbuzz CONFIG REQUIRED\)' `
    'CMake must require HarfBuzz explicitly.'
Assert-Matches $cmake 'Freetype::Freetype' `
    'PDFClowne must link FreeType explicitly.'
Assert-Matches $cmake 'harfbuzz::harfbuzz' `
    'PDFClowne must link HarfBuzz explicitly.'
Assert-Matches $cmake 'src/backend/text/PdfTextExtractor\.cpp' `
    'CMake must compile PdfTextExtractor.'
Assert-Matches $cmake 'src/backend/text/PdfFontResolver\.cpp' `
    'CMake must compile PdfFontResolver.'
Assert-Matches $cmake 'src/backend/text/PdfEditSessionController\.cpp' `
    'CMake must compile PdfEditSessionController.'
Assert-Matches $cmake 'src/backend/text/PdfGlyphRunModel\.cpp' `
    'CMake must compile PdfGlyphRunModel.'
Assert-Matches $cmake 'src/backend/render/PdfGlyphOverlayItem\.cpp' `
    'CMake must compile PdfGlyphOverlayItem.'
Assert-Matches $cmake 'src/backend/render/PdfScratchPageRenderer\.cpp' `
    'CMake must compile PdfScratchPageRenderer.'
Assert-Matches $cmake 'src/backend/pdf/PdfContentWriter\.cpp' `
    'CMake must compile PdfContentWriter.'
Assert-Matches $cmake 'src/backend/pdf/PdfSaveCoordinator\.cpp' `
    'CMake must compile PdfSaveCoordinator.'
Assert-Matches $cmake 'src/qml/editor/PdfEditOverlay\.qml' `
    'CMake must package PdfEditOverlay.qml.'

Assert-Matches $mainCpp 'qmlRegisterType<\s*PDFClowne::Editing::PdfEditSessionController\s*>' `
    'main.cpp must register PdfEditSessionController.'
Assert-Matches $mainCpp 'qmlRegisterType<\s*PDFClowne::Render::PdfGlyphOverlayItem\s*>' `
    'main.cpp must register PdfGlyphOverlayItem.'
Assert-Matches $mainQml 'PdfEditSessionController\s*\{\s*\}' `
    'main.qml must dynamically create PdfEditSessionController.'
Assert-Matches $viewer 'PdfEditOverlay\s*\{' `
    'PdfViewer must host the single native edit overlay.'
Assert-NotMatches $viewer '(^|[\s;])EditOverlay\s*\{[\s\S]{0,600}editModeEnabled' `
    'PdfViewer must not route visual PDF text editing through the old EditOverlay.'

Assert-Matches $glyphModelHeader 'struct\s+PdfGlyph\s*\{' `
    'PdfGlyphRunModel must declare PdfGlyph.'
Assert-Matches $glyphModelHeader 'pageIndex[\s\S]*blockIndex[\s\S]*lineIndex[\s\S]*spanIndex[\s\S]*unicode[\s\S]*originalGid[\s\S]*origin[\s\S]*quad[\s\S]*bbox[\s\S]*advance[\s\S]*fontName[\s\S]*fontResourceKey[\s\S]*fontSize[\s\S]*fillColor[\s\S]*wmode[\s\S]*bidiLevel[\s\S]*direction[\s\S]*trm' `
    'PdfGlyph must preserve glyph-level PDF identity and geometry.'
Assert-Matches $glyphModelHeader 'struct\s+PdfRun\s*\{' `
    'PdfGlyphRunModel must declare PdfRun.'
Assert-Matches $glyphModelHeader 'glyphs[\s\S]*plainText[\s\S]*fontResourceKey[\s\S]*fillColor[\s\S]*wmode[\s\S]*bidiLevel[\s\S]*direction[\s\S]*trm' `
    'PdfRun must be grouped by exact PDF shaping identity.'
Assert-Matches $glyphModelHeader 'struct\s+PdfEditableRegion\s*\{' `
    'PdfGlyphRunModel must declare PdfEditableRegion.'
Assert-Matches $glyphModelHeader 'glyphRange[\s\S]*unionQuad[\s\S]*baselineStart[\s\S]*baselineEnd[\s\S]*box[\s\S]*script[\s\S]*language' `
    'PdfEditableRegion must keep editable geometry separate from paragraph reconstruction.'

Assert-Matches $extractorHeader 'class\s+PdfTextExtractor' `
    'PdfTextExtractor must be the extraction boundary.'
Assert-Matches $extractorSource 'FZ_STEXT_PRESERVE_SPANS' `
    'PdfTextExtractor must preserve spans.'
Assert-Matches $extractorSource 'FZ_STEXT_PRESERVE_LIGATURES' `
    'PdfTextExtractor must preserve ligatures.'
Assert-Matches $extractorSource 'FZ_STEXT_ACCURATE_BBOXES' `
    'PdfTextExtractor must request accurate bboxes.'
Assert-Matches $extractorSource 'FZ_STEXT_ACCURATE_ASCENDERS' `
    'PdfTextExtractor must request accurate ascenders.'
Assert-Matches $extractorSource 'FZ_STEXT_ACCURATE_SIDE_BEARINGS' `
    'PdfTextExtractor must request accurate side bearings.'
Assert-Matches $extractorSource 'FZ_STEXT_COLLECT_STYLES' `
    'PdfTextExtractor must collect styles.'
Assert-Matches $extractorSource 'resourceKey\(pageObjectRef,\s*resourceName,\s*fontXref\)' `
    'PdfTextExtractor must build font identity from page object, resource name, and xref.'

Assert-Matches $fontResolverHeader 'requiresSubstitute' `
    'PdfFontResolver must mark runs with missing embedded font programs.'
Assert-Matches $controllerHeader 'class\s+PdfEditSessionController\s*:\s*public\s+QObject' `
    'PdfEditSessionController must be the single edit pipeline controller.'
Assert-Matches $controllerHeader 'beginSession' `
    'PdfEditSessionController must expose beginSession for first-click editing.'
Assert-Matches $controllerHeader 'QInputMethodEvent|inputMethodCommit' `
    'PdfEditSessionController/PdfGlyphOverlayItem must own keyboard and IME state outside visible QML text.'
Assert-Matches $controllerSource 'renderRedactedBase' `
    'PdfEditSessionController must use a redacted scratch base after mutation.'
Assert-Matches $controllerSource 'renderGlyphOverlay' `
    'PdfEditSessionController must use MuPDF-rendered glyph overlay after mutation.'

Assert-Matches $overlayItemHeader 'class\s+PdfGlyphOverlayItem\s*:\s*public\s+QQuickItem' `
    'PdfGlyphOverlayItem must be a QQuickItem.'
Assert-Matches $overlayItemSource 'ItemHasContents' `
    'PdfGlyphOverlayItem must opt into scene graph painting.'
Assert-Matches $overlayItemSource 'updatePaintNode' `
    'PdfGlyphOverlayItem must paint through updatePaintNode.'
Assert-NotMatches ($overlayItemHeader + $overlayItemSource) 'QQuickPaintedItem|QRawFont|QGlyphRun' `
    'The edit renderer must not use QQuickPaintedItem, QRawFont, or QGlyphRun as the final visual path.'

Assert-Matches ($scratchRendererHeader + $scratchRendererSource) 'pdf_redact_page|PDF_REDACT_TEXT_REMOVE' `
    'PdfScratchPageRenderer must remove original text through MuPDF redaction.'
Assert-Matches $scratchRendererSource 'hb_blob_create[\s\S]*hb_face_create[\s\S]*hb_font_create[\s\S]*hb_buffer_add_utf8[\s\S]*hb_shape' `
    'PdfScratchPageRenderer must shape replacement text with HarfBuzz.'
Assert-Matches $scratchRendererSource 'fz_new_text|fz_show_glyph|fz_fill_text' `
    'PdfScratchPageRenderer must rasterize replacement text through MuPDF text drawing.'
Assert-Matches ($writerHeader + $writerSource) 'BT[\s\S]*Tf[\s\S]*Tm[\s\S]*Tj|TJ' `
    'PdfContentWriter must own generated PDF text operators.'
Assert-Matches ($saveCoordinatorHeader + $saveCoordinatorSource) 'tempPdfPathFor[\s\S]*canOpenAsPdf[\s\S]*replaceFileWithBackup' `
    'PdfSaveCoordinator must preserve temp-validate-replace save semantics.'

Assert-Matches $editOverlay 'PdfGlyphOverlayItem\s*\{' `
    'PdfEditOverlay must use the C++ scene graph glyph overlay.'
Assert-Matches $editOverlay 'TapHandler\s*\{' `
    'PdfEditOverlay must use one root pointer capturer.'
Assert-Matches $editOverlay 'forceActiveFocus\(Qt\.MouseFocusReason\)' `
    'PdfEditOverlay must focus synchronously on first click.'
Assert-NotMatches $editOverlay '\bText\s*\{|\bTextEdit\s*\{|\bTextInput\s*\{' `
    'PdfEditOverlay must not paint visible editable text with Qt text items.'

Write-Output 'Native edit mode architecture static checks passed.'
