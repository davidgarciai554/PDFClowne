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

Assert-Matches 'property\s+bool\s+programmaticJumpActive' 'PdfViewer must track programmatic jumps separately from viewport-driven page changes.'
Assert-Matches 'function\s+completeProgrammaticJump\(' 'PdfViewer must explicitly complete programmatic jumps.'
Assert-Matches 'if\s*\(programmaticJumpActive\s*&&\s*closest\s*!==\s*pendingJumpPage\)' 'Viewport updates must ignore old pages while a programmatic jump is still settling.'
Assert-Matches 'programmaticJumpActive\s*=\s*true' 'Jump initiation must arm the programmatic jump guard.'
Assert-Matches 'programmaticJumpActive\s*=\s*false' 'Programmatic jump guard must be released once the target page is stable.'
Assert-Matches 'function\s+completeProgrammaticJump\([\s\S]*syncThumbnailViewport\(\)' 'Completing a programmatic jump must also recenter the thumbnail list.'
Assert-Matches 'thumbnailList\.contentY\s*=\s*centeredY' 'Thumbnail sync must set contentY explicitly so large jumps really scroll the left list.'
Assert-Matches 'highlightRangeMode:\s*ListView\.ApplyRange' 'Thumbnail list must apply a highlight range without forcing empty space at the edges.'
Assert-Matches 'positionMode\s*=\s*ListView\.Beginning' 'Thumbnail sync must snap near-start pages to the beginning instead of centering them with blank space.'
Assert-Matches 'positionMode\s*=\s*ListView\.End' 'Thumbnail sync must snap near-end pages to the end instead of over-centering them.'

Write-Output 'Virtualized PDF navigation guard static checks passed.'
