$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -match $Pattern) {
        throw $Message
    }
}

$providerHeader = Join-Path $root 'src/backend/PdfRenderImageProvider.h'
$providerSource = Join-Path $root 'src/backend/PdfRenderImageProvider.cpp'
$mainSource = Join-Path $root 'src/main.cpp'
$renderSource = Join-Path $root 'src/backend/DocumentRenderController.cpp'
$qmlSource = Join-Path $root 'src/qml/PdfViewer.qml'

if (-not (Test-Path -LiteralPath $providerHeader)) {
    throw 'PdfRenderImageProvider.h must exist.'
}

if (-not (Test-Path -LiteralPath $providerSource)) {
    throw 'PdfRenderImageProvider.cpp must exist.'
}

Assert-Contains $providerHeader 'class\s+PdfRenderImageProvider\s*:\s*public\s+QQuickImageProvider' 'Provider must derive from QQuickImageProvider.'
Assert-Contains $providerSource 'ForceAsynchronousImageLoading' 'Provider must force asynchronous image loading.'
Assert-Contains $providerSource 'requestImage' 'Provider must implement requestImage.'
Assert-Contains $mainSource 'addImageProvider\(\s*QStringLiteral\("pdf-render"\)' 'main.cpp must register image://pdf-render.'
Assert-Contains $renderSource 'storeImage\(' 'DocumentRenderController must store rendered QImages in the provider.'
Assert-NotContains $renderSource 'data:image/png;base64' 'DocumentRenderController must not emit PNG base64 data URLs for rendered pages.'
Assert-Contains $qmlSource 'asynchronous:\s*true' 'PdfViewer Image items must request asynchronous image loading.'

Write-Output 'Pdf render image provider static checks passed.'
