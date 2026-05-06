$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$pdfiumDir = if ($env:PDFium_DIR) { $env:PDFium_DIR } else { 'C:\tmp\pdfium-fase5' }
$pdfPath = Join-Path $root 'PDFTest\01-base.pdf'

if (-not (Test-Path -LiteralPath $pdfPath)) {
    throw "Missing test PDF: $pdfPath"
}

$pdfiumDll = Join-Path $pdfiumDir 'bin\pdfium.dll'
$editHeader = Join-Path $pdfiumDir 'include\fpdf_edit.h'
$textHeader = Join-Path $pdfiumDir 'include\fpdf_text.h'

foreach ($path in @($pdfiumDll, $editHeader, $textHeader)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing PDFium SDK file: $path"
    }
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class PdfiumNative {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SetDllDirectory(string lpPathName);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern void FPDF_InitLibrary();

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern void FPDF_DestroyLibrary();

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    public static extern IntPtr FPDF_LoadDocument(string filePath, string password);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int FPDF_GetPageCount(IntPtr document);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern void FPDF_CloseDocument(IntPtr document);
}
'@

$binDir = Split-Path -Parent $pdfiumDll
if (-not [PdfiumNative]::SetDllDirectory($binDir)) {
    throw "SetDllDirectory failed for PDFium bin dir: $binDir"
}

$document = [IntPtr]::Zero

try {
    [PdfiumNative]::FPDF_InitLibrary()
    $document = [PdfiumNative]::FPDF_LoadDocument($pdfPath, $null)

    if ($document -eq [IntPtr]::Zero) {
        throw "FPDF_LoadDocument returned null for $pdfPath"
    }

    $pageCount = [PdfiumNative]::FPDF_GetPageCount($document)
    if ($pageCount -le 0) {
        throw "FPDF_GetPageCount returned $pageCount"
    }

    Write-Output "PDFium hello world passed: pages=$pageCount"
}
finally {
    if ($document -ne [IntPtr]::Zero) {
        [PdfiumNative]::FPDF_CloseDocument($document)
    }

    [PdfiumNative]::FPDF_DestroyLibrary()
}
