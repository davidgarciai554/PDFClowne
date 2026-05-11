$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$cmakePath = Join-Path $root 'CMakeLists.txt'
if (-not (Test-Path -LiteralPath $cmakePath)) {
    throw 'Missing CMakeLists.txt'
}

$cmake = Get-Content -LiteralPath $cmakePath -Raw

if ($cmake -notmatch 'TARGET_RUNTIME_DLLS:PDFClowne') {
    throw 'CMake must deploy imported runtime DLLs for PDFClowne so the exe opens by double-click.'
}

if ($cmake -notmatch 'PDFium_LIBRARY') {
    throw 'CMake must copy the PDFium runtime DLL when PDFium editing is enabled.'
}

if ($cmake -notmatch 'copy_if_different[\s\S]*PDFium_LIBRARY') {
    throw 'CMake must copy pdfium.dll beside PDFClowne.exe.'
}

Write-Output 'Windows runtime deployment contract checks passed.'
