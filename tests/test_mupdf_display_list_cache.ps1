$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$renderSourcePath = Join-Path $root 'src/backend/DocumentRenderController.cpp'
$renderSource = Get-Content -LiteralPath $renderSourcePath -Raw

function Assert-Matches {
    param(
        [string]$Pattern,
        [string]$Message
    )

    if ($renderSource -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotMatches {
    param(
        [string]$Pattern,
        [string]$Message
    )

    if ($renderSource -match $Pattern) {
        throw $Message
    }
}

Assert-Matches 'kMuPdfStoreLimitBytes' 'Render worker must define a bounded MuPDF store limit.'
Assert-Matches 'fz_new_context\(nullptr,\s*nullptr,\s*kMuPdfStoreLimitBytes\)' 'Render engine must stop using an unlimited MuPDF store.'
Assert-NotMatches 'fz_new_context\(nullptr,\s*nullptr,\s*FZ_STORE_UNLIMITED\)' 'Render engine must not use FZ_STORE_UNLIMITED for large PDFs.'
Assert-Matches 'struct\s+DisplayListEntry' 'Render worker must have a display-list cache entry.'
Assert-Matches 'fz_display_list\s*\*' 'Display-list cache must store fz_display_list pointers.'
Assert-Matches 'fz_new_display_list_from_page_number\(ctx,\s*doc,\s*pageIndex\)' 'Render worker must build reusable MuPDF display lists from pages.'
Assert-Matches 'fz_new_pixmap_from_display_list\(ctx,\s*displayListEntry->list' 'Render worker must render pages by replaying cached display lists.'
Assert-Matches 'pruneDisplayListCache' 'Render worker must prune stale display lists.'
Assert-Matches 'kMaxDisplayListCachePages' 'Render worker must bound the number of cached display lists.'
Assert-Matches 'fz_drop_display_list' 'Render worker must release cached display lists.'

Write-Output 'MuPDF display-list cache static checks passed.'
