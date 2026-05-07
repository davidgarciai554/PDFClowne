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

$pdfDocumentSource = Read-ProjectFile 'src/backend/PdfDocument.cpp'

$styleFromChar = Select-SourceSection $pdfDocumentSource 'QJsonObject styleFromChar' 'bool sameStyle' 'PdfDocument.cpp must keep styleFromChar for extracting per-character style data.'
$sameStyle = Select-SourceSection $pdfDocumentSource 'bool sameStyle' 'QJsonObject makeSpanObject' 'PdfDocument.cpp must keep sameStyle for grouping style-compatible spans.'
$makeSpanObject = Select-SourceSection $pdfDocumentSource 'QJsonObject makeSpanObject' 'QJsonObject buildTextBlockJson' 'PdfDocument.cpp must keep makeSpanObject for serializing text spans.'
$buildTextBlockJson = Select-SourceSection $pdfDocumentSource 'QJsonObject buildTextBlockJson' 'QJsonArray collectTextBlocks' 'PdfDocument.cpp must keep text block JSON construction in buildTextBlockJson.'

Assert-Matches $styleFromChar 'fz_font_name\(ctx,\s*ch->font\)' 'styleFromChar must read the MuPDF font name for the originating character.'
Assert-Matches $styleFromChar 'style\.insert\(QStringLiteral\("fontFamily"\),\s*fontName\);' 'styleFromChar must expose fontFamily.'
Assert-Matches $styleFromChar 'ch\s*\?\s*ch->size|ch->size' 'styleFromChar must use the MuPDF character size.'
Assert-Matches $styleFromChar 'style\.insert\(QStringLiteral\("fontSize"\)' 'styleFromChar must expose fontSize.'
Assert-Matches $styleFromChar 'ch\s*\?\s*ch->argb|ch->argb' 'styleFromChar must use the MuPDF character color.'
Assert-Matches $styleFromChar 'style\.insert\(QStringLiteral\("color"\)' 'styleFromChar must expose color.'
Assert-Matches $styleFromChar 'style\.insert\(QStringLiteral\("bold"\)' 'styleFromChar must expose bold.'
Assert-Matches $styleFromChar 'style\.insert\(QStringLiteral\("italic"\)' 'styleFromChar must expose italic.'
Assert-Matches $styleFromChar 'style\.insert\(QStringLiteral\("underline"\)' 'styleFromChar must expose underline.'

Assert-Matches $sameStyle 'fontFamily' 'Span coalescing must split when fontFamily changes.'
Assert-Matches $sameStyle 'fontFaceName' 'Span coalescing must split when the source PDF font face changes.'
Assert-Matches $sameStyle 'fontResourceName' 'Span coalescing must split when the source PDF font resource changes.'
Assert-Matches $sameStyle 'fontSize' 'Span coalescing must split when fontSize changes.'
Assert-Matches $sameStyle 'color' 'Span coalescing must split when color changes.'
Assert-Matches $sameStyle 'bold' 'Span coalescing must split when bold changes.'
Assert-Matches $sameStyle 'italic' 'Span coalescing must split when italic changes.'
Assert-Matches $sameStyle 'underline' 'Span coalescing must split when underline changes.'
Assert-Matches $sameStyle 'strikeout' 'Span coalescing must split when strikeout changes.'

Assert-Matches $makeSpanObject 'QJsonObject\s+span\s*=\s*style;' 'Span serialization must start from the extracted style object.'
Assert-Matches $makeSpanObject 'span\.insert\(QStringLiteral\("text"\),\s*text\);' 'Span serialization must preserve the span text.'

Assert-Matches $makeSpanObject 'span\.insert\(QStringLiteral\("glyphs"\),\s*glyphs\);' 'Enriched spans must include glyphs so style ranges can be redrawn without flattening to plain text.'
Assert-Matches $makeSpanObject 'span\.insert\(QStringLiteral\("bbox"\),\s*rectToJson\(bbox\)\);' 'Enriched spans must expose their geometry bbox.'
Assert-Matches $makeSpanObject 'span\.insert\(QStringLiteral\("start"\),\s*start\);' 'Enriched spans must expose the block text start offset.'
Assert-Matches $makeSpanObject 'span\.insert\(QStringLiteral\("end"\),\s*end\);' 'Enriched spans must expose the block text end offset.'
Assert-Matches $makeSpanObject 'span\.insert\(QStringLiteral\("lineIndex"\),\s*lineIndex\);' 'Enriched spans must expose their source line index.'
Assert-Matches $makeSpanObject 'span\.insert\(QStringLiteral\("font"\),\s*fontMetadataFromStyle\(style\)\);' 'Enriched spans must include explicit font metadata derived from the original PDF style.'
Assert-Matches $makeSpanObject 'span\.insert\(QStringLiteral\("textState"\),\s*unknownTextStateJson\(\)\);' 'Enriched spans must include explicit textState metadata, even when exact PDF operators are unknown.'

Assert-Matches $buildTextBlockJson 'const\s+QJsonObject\s+charStyle\s*=\s*styleFromChar\(ctx,\s*ch(?:,\s*[^)]*)?\);' 'buildTextBlockJson must derive span styles from individual MuPDF characters.'
Assert-Matches $buildTextBlockJson 'currentGlyphs\.append\(glyph\);' 'buildTextBlockJson must attach glyph geometry to the active style span.'
Assert-Matches $buildTextBlockJson 'makeSpanObject\([\s\S]*currentGlyphs' 'buildTextBlockJson must serialize enriched spans with glyph geometry.'
Assert-Matches $buildTextBlockJson 'spans\.append\(span\);|spans\.append\(makeSpanObject\(' 'buildTextBlockJson must serialize style spans.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("spans"\),\s*spans\);' 'The block model must expose spans.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("fontFamily"\),\s*fallbackStyle\.value\(QStringLiteral\("fontFamily"\)\)\);' 'The block model must expose a fallback fontFamily.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("fontFaceName"\),\s*fallbackStyle\.value\(QStringLiteral\("fontFaceName"\)\)\);' 'The block model must expose a fallback fontFaceName.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("fontResourceName"\),\s*fallbackStyle\.value\(QStringLiteral\("fontResourceName"\)\)\);' 'The block model must expose a fallback fontResourceName.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("fontSize"\),\s*fallbackStyle\.value\(QStringLiteral\("fontSize"\)\)\);' 'The block model must expose a fallback fontSize.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("color"\),\s*fallbackStyle\.value\(QStringLiteral\("color"\)\)\);' 'The block model must expose a fallback color.'
Assert-Matches $buildTextBlockJson 'QStringLiteral\("fontResourceName"\)|QStringLiteral\("fontFaceName"\)' 'The enriched style model must preserve original PDF font resource identity when it can be inferred.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("fidelity"\),\s*fidelityMetadataFromStyle\(fallbackStyle\)\);' 'The block model must expose conservative fidelity metadata.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("font"\),\s*fontMetadataFromStyle\(fallbackStyle\)\);' 'The block model must expose explicit original font metadata.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("textState"\),\s*unknownTextStateJson\(\)\);' 'The block model must expose explicit textState metadata.'
Assert-Matches $buildTextBlockJson 'QJsonArray\s+visualRuns' 'The block model must collect visualRuns for rendering spans over the PDF.'
Assert-Matches $buildTextBlockJson 'visualRunFromSpan\(span,\s*line,' 'Visual runs must be derived from each serialized span and its MuPDF line geometry.'
Assert-Matches $buildTextBlockJson 'item\.insert\(QStringLiteral\("visualRuns"\),\s*visualRuns\);' 'The block model must expose visualRuns.'

Write-Output 'PDF text block style model static checks passed.'
