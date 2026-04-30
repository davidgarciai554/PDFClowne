$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$viewerPath = Join-Path $root 'src/qml/PdfViewer.qml'
$viewerQml = Get-Content -LiteralPath $viewerPath -Raw

function Assert-Matches {
    param(
        [string]$Pattern,
        [string]$Message
    )

    if ($viewerQml -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotMatches {
    param(
        [string]$Pattern,
        [string]$Message
    )

    if ($viewerQml -match $Pattern) {
        throw $Message
    }
}

Assert-Matches 'ListView\s*\{\s*id:\s*viewport' 'PdfViewer must use a virtualized ListView as the main viewport.'
Assert-Matches 'function\s+rowIndexForPage\(' 'PdfViewer must compute row indexes for page navigation.'
Assert-Matches 'positionViewAtIndex\(targetRow,\s*ListView\.Beginning\)' 'PdfViewer jumps must position the virtualized viewport by row index.'
Assert-Matches 'function\s+rowDelegateForRowIndex\(' 'PdfViewer must resolve visible row delegates without traversing the whole document tree.'
Assert-Matches 'cursorShape:\s*root\.handToolEnabled\s*\?\s*\(\s*pressed\s*\?\s*Qt\.ClosedHandCursor\s*:\s*Qt\.OpenHandCursor\s*\)\s*:\s*Qt\.ArrowCursor' 'The pan tool overlay must only show the hand cursor when the hand tool is active.'
Assert-Matches 'cursorShape:\s*root\.handToolEnabled\s*\?\s*Qt\.OpenHandCursor\s*:\s*Qt\.ArrowCursor' 'Link overlays must not show a hand cursor when the hand tool is off.'
Assert-NotMatches 'Column\s*\{\s*id:\s*pagesColumn' 'PdfViewer must not keep the old non-virtualized pagesColumn container.'

Write-Output 'Virtualized PDF viewer static checks passed.'
