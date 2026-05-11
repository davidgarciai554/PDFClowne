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

$header = Read-ProjectFile 'src/core/editing/EditingController.h'
$source = Read-ProjectFile 'src/core/editing/EditingController.cpp'
$writeBackSource = Read-ProjectFile 'src/core/editing/PdfWriteBackEngine.cpp'
$writeBackHeader = Read-ProjectFile 'src/core/editing/PdfWriteBackEngine.h'
$fontHeader = Read-ProjectFile 'src/core/editing/FontFallbackManager.h'
$fontSource = Read-ProjectFile 'src/core/editing/FontFallbackManager.cpp'
$editInspector = Read-ProjectFile 'src/qml/EditInspector.qml'
$mainQml = Read-ProjectFile 'src/qml/main.qml'
$cmake = Read-ProjectFile 'CMakeLists.txt'

Assert-Matches $header 'QHash<\s*int\s*,\s*QList<\s*PdfTextBlock\s*>\s*>\s+m_pageBlockCache' `
    'EditingController must cache extracted blocks by page so multi-page edits can be saved together.'

Assert-Matches $source 'm_pageBlockCache\.insert\(pageNumber,\s*blocks\)' `
    'extractBlocksForPage must store each page extraction in the page block cache.'

Assert-Matches $source 'const\s+PdfTextBlock\*\s+EditingController::findBlock\(const\s+QString&\s+blockId\)\s+const[\s\S]*m_pageBlockCache' `
    'findBlock must search cached blocks across pages, not just the current page model.'

Assert-Matches $source 'if\s*\(\s*outputPath\.trimmed\(\)\.isEmpty\(\)\s*\)[\s\S]*saveError\(QStringLiteral\("Output path is required' `
    'saveDocument must reject an empty output path instead of silently overwriting the loaded PDF.'

Assert-Matches $source 'QFileInfo\(target\)\.canonicalFilePath\(\)\s*==\s*QFileInfo\(m_loadedFilePath\)\.canonicalFilePath\(\)' `
    'saveDocument must reject saving directly over the loaded PDF; overwrite requires a confirmed safe replacement path.'

Assert-NotMatches $source 'outputPath\.isEmpty\(\)\s*\?\s*m_loadedFilePath\s*:\s*outputPath' `
    'saveDocument must not default an empty output path to m_loadedFilePath.'

Assert-Matches $writeBackSource 'tempOutputPathFor\(const QString& outputPath\)' `
    'PdfWriteBackEngine must save to a temporary PDF path before replacing the target.'

Assert-Matches $writeBackSource 'canOpenWithPdfium\(tempPath\)' `
    'PdfWriteBackEngine must validate the temporary PDF before replacing the target.'

Assert-Matches $writeBackSource 'QFile::rename\(tempPath,\s*outputPath\)' `
    'PdfWriteBackEngine must rename the validated temporary PDF into place.'

Assert-Matches $writeBackHeader 'enum\s+class\s+SaveMode\s*\{\s*Incremental,\s*FullRewrite\s*\}' `
    'PdfWriteBackEngine must expose explicit incremental vs full rewrite save modes.'

Assert-Matches $source 'incremental\s*\?\s*PdfWriteBackEngine::SaveMode::Incremental\s*:\s*PdfWriteBackEngine::SaveMode::FullRewrite' `
    'EditingController::saveDocument must map the UI incremental option to PdfWriteBackEngine::SaveMode.'

Assert-Matches $editInspector 'property\s+bool\s+incrementalSave' `
    'EditInspector must expose the incremental save option to QML.'

Assert-Matches $editInspector 'CheckBox[\s\S]*Guardado incremental' `
    'EditInspector must render a visible incremental/full rewrite save choice.'

Assert-Matches $mainQml 'pendingEditSaveIncremental' `
    'main.qml must remember the requested PDF edit save mode while opening the save dialog.'

Assert-Matches $fontHeader 'QString\s+fontFilePath' `
    'FontFallbackResult must carry an embeddable font file path when one is available.'

Assert-Matches $fontHeader 'bool\s+canEmbed' `
    'FontFallbackResult must distinguish embeddable fallbacks from system-only fallbacks.'

Assert-Matches $fontSource 'DejaVuSans\.ttf' `
    'FontFallbackManager must know the bundled DejaVu Sans filename for future embedding.'

Assert-Matches $fontSource 'NotoSansCJK-Regular\.otf' `
    'FontFallbackManager must know the bundled Noto CJK filename for future embedding.'

Assert-Matches $fontSource 'NotoSansArabic-Regular\.ttf' `
    'FontFallbackManager must know the bundled Noto Arabic filename for future embedding.'

Assert-Matches $writeBackSource 'FPDFText_LoadFont' `
    'PdfWriteBackEngine must embed fallback font bytes with PDFium when a bundled font file is available.'

Assert-Matches $writeBackSource 'FPDFPageObj_CreateTextObj' `
    'PdfWriteBackEngine must create replacement text objects from loaded font handles.'

Assert-Matches $source 'm_fontFallback\.selectFontForText' `
    'EditingController must preserve full FontFallbackResult metadata for write-back, not only the family name.'

Assert-Matches $cmake 'PdfWriteBackIntegrationTest' `
    'CMake must define the PDFium integration test for save-reload and golden image tolerance.'

Write-Output 'PDFium editing persistence contract checks passed.'
