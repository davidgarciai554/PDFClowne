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

$pdfDocumentHeader = Read-ProjectFile 'src/backend/PdfDocument.h'
$pdfDocumentSource = Read-ProjectFile 'src/backend/PdfDocument.cpp'

$textBlockExtractionFlags = Select-SourceSection $pdfDocumentSource 'int textBlockExtractionFlags()' 'QString blockKeyForRect' 'PdfDocument.cpp must define textBlockExtractionFlags near the text block extraction pipeline.'
$glyphFromChar = Select-SourceSection $pdfDocumentSource 'QJsonObject glyphFromChar' 'QJsonObject buildTextBlockJson' 'PdfDocument.cpp must serialize glyph geometry before building text block JSON.'
$buildTextBlockJson = Select-SourceSection $pdfDocumentSource 'QJsonObject buildTextBlockJson' 'QJsonArray collectTextBlocks' 'PdfDocument.cpp must keep text block JSON construction in buildTextBlockJson.'
$collectTextBlocks = Select-SourceSection $pdfDocumentSource 'QJsonArray collectTextBlocks' 'QString renderPageToDataUrl' 'PdfDocument.cpp must keep collectTextBlocks as the textBlocksForPage model helper.'
$textBlocksForPage = Select-SourceSection $pdfDocumentSource 'QString PdfDocument::textBlocksForPage' 'QString PdfDocument::textEditAt' 'PdfDocument::textBlocksForPage must be present.'
$textEditAt = Select-SourceSection $pdfDocumentSource 'QString PdfDocument::textEditAt' 'QString PdfDocument::extractPageText' 'PdfDocument::textEditAt must be present.'

Assert-Matches $pdfDocumentHeader 'Q_INVOKABLE\s+QString\s+textBlocksForPage\(int\s+pageIndex\);' 'PdfDocument must expose textBlocksForPage so QML can inspect detected block geometry.'
Assert-Matches $pdfDocumentHeader 'Q_INVOKABLE\s+QString\s+textEditAt\(int\s+pageIndex,\s*const\s+QPointF\s*&point\);' 'PdfDocument must expose textEditAt so clicked inline editing can use the same text block model.'

Assert-Matches $textBlockExtractionFlags 'FZ_STEXT_PRESERVE_SPANS' 'Text block extraction must preserve MuPDF spans.'
Assert-Matches $textBlockExtractionFlags 'FZ_STEXT_COLLECT_STYLES' 'Text block extraction must collect MuPDF style data.'
Assert-Matches $textBlockExtractionFlags 'FZ_STEXT_PRESERVE_WHITESPACE' 'Text block extraction must preserve PDF whitespace for faithful line reconstruction.'
Assert-Matches $textBlockExtractionFlags 'FZ_STEXT_ACCURATE_BBOXES' 'Text block extraction must request accurate block/line/glyph bounding boxes.'
Assert-Matches $textBlockExtractionFlags 'FZ_STEXT_ACCURATE_ASCENDERS' 'Text block extraction must request accurate ascender data for text geometry.'
Assert-Matches $textBlockExtractionFlags 'FZ_STEXT_ACCURATE_SIDE_BEARINGS' 'Text block extraction must request accurate side bearings for glyph placement.'

Assert-Matches $textBlocksForPage 'options\.flags\s*=\s*textBlockExtractionFlags\(\);' 'textBlocksForPage must use the centralized fidelity extraction flags.'
Assert-Matches $textBlocksForPage 'blocks\s*=\s*collectTextBlocks\(ctx,\s*pageIndex,\s*textPage(?:,\s*[^)]*)?\);' 'textBlocksForPage must use collectTextBlocks instead of building a separate block model.'
Assert-Matches $textEditAt 'options\.flags\s*=\s*textBlockExtractionFlags\(\);' 'textEditAt must use the same fidelity extraction flags as textBlocksForPage.'
Assert-Matches $textEditAt 'result\s*=\s*buildTextBlockJson\(ctx,\s*pageIndex,\s*block(?:,\s*[^)]*)?\);' 'textEditAt must return the same enriched block model that textBlocksForPage emits.'
Assert-Matches $collectTextBlocks 'buildTextBlockJson\(ctx,\s*pageIndex,\s*block(?:,\s*[^)]*)?\)' 'collectTextBlocks must serialize blocks through buildTextBlockJson.'

Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("rect"\),\s*rectToJson\(block->bbox\)\);' 'The block model must keep the block bbox in page coordinates.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("originalRect"\),\s*rectToJson\(block->bbox\)\);' 'The block model must preserve the original block bbox for replacement previews.'
Assert-Matches $buildTextBlockJson 'QJsonArray\s+lines' 'The block model must include a lines array.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("lines"\),' 'The block model must serialize lines.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("lineCount"\),\s*lines\.size\(\)\);' 'The block model must expose a lineCount matching the serialized lines.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("glyphCount"\),\s*glyphCount\);' 'The block model must expose glyphCount for fidelity checks and replacement previews.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("writingMode"\),\s*paragraphWritingMode\);' 'The block model must expose paragraph writing mode inferred from MuPDF line wmode.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("paragraphDirection"\),\s*pointToJson\(paragraphDirection\)\);' 'The block model must expose paragraph direction inferred from MuPDF line dir.'
Assert-Matches $buildTextBlockJson 'line->bbox' 'Each serialized line must use MuPDF line bbox data.'
Assert-Matches $buildTextBlockJson 'QStringLiteral\("bbox"\)' 'Each serialized line must expose its bbox.'
Assert-Matches $buildTextBlockJson 'line->wmode' 'Each serialized line must preserve MuPDF writing mode.'
Assert-Matches $buildTextBlockJson 'QStringLiteral\("wmode"\)' 'Each serialized line must expose wmode.'
Assert-Matches $buildTextBlockJson 'line->dir' 'Each serialized line must preserve the MuPDF baseline direction.'
Assert-Matches $buildTextBlockJson 'QStringLiteral\("dir"\)' 'Each serialized line must expose dir.'
Assert-Matches $buildTextBlockJson 'line->first_char\s*\?\s*line->first_char->origin\s*:\s*fz_make_point\(line->bbox\.x0,\s*line->bbox\.y1\)' 'Line baselineOrigin must come from the first glyph origin with a bbox fallback.'
Assert-Matches $buildTextBlockJson 'QStringLiteral\("baselineOrigin"\)' 'Each serialized line must expose baselineOrigin.'
Assert-Matches $buildTextBlockJson 'lineObject\.insert\(QStringLiteral\("spans"\),\s*lineSpans\);' 'Each serialized line must expose its enriched style spans.'
Assert-Matches $buildTextBlockJson 'QJsonObject\s+glyph\s*=\s*glyphFromChar\(ctx,\s*line,\s*ch,\s*rune\);' 'buildTextBlockJson must serialize each MuPDF character through glyphFromChar.'
Assert-Matches $glyphFromChar 'ch->origin' 'Each serialized glyph must preserve its MuPDF origin.'
Assert-Matches $glyphFromChar 'QStringLiteral\("origin"\)' 'Each serialized glyph must expose origin.'
Assert-Matches $glyphFromChar 'ch->quad' 'Each serialized glyph must preserve its MuPDF quad.'
Assert-Matches $glyphFromChar 'quadPathToJson\(' 'Glyph quads must be serialized as four-point paths, not collapsed rectangles.'
Assert-Matches $glyphFromChar 'QStringLiteral\("quad"\)' 'Each serialized glyph must expose quad.'
Assert-Matches $glyphFromChar 'QStringLiteral\("advance"\)' 'Each serialized glyph must expose advance so later composition can avoid ad-hoc wrapping.'
Assert-Matches $glyphFromChar 'QStringLiteral\("charStart"\)' 'Each serialized glyph must expose charStart for PDF-native caret hit-testing.'
Assert-Matches $glyphFromChar 'QStringLiteral\("charEnd"\)' 'Each serialized glyph must expose charEnd for PDF-native caret hit-testing.'
Assert-Matches $buildTextBlockJson 'glyph\.insert\(QStringLiteral\("charStart"\),\s*blockText\.length\(\)\);' 'buildTextBlockJson must stamp each glyph with its block-text start offset before appending the rune.'
Assert-Matches $buildTextBlockJson 'glyph\.insert\(QStringLiteral\("charEnd"\),\s*blockText\.length\(\)\s*\+\s*rune\.length\(\)\);' 'buildTextBlockJson must stamp each glyph with its block-text end offset before appending the rune.'

Write-Output 'PDF text block geometry static checks passed.'
