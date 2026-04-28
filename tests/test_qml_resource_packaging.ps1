$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$cmakePath = Join-Path $root 'CMakeLists.txt'
$cmake = Get-Content -LiteralPath $cmakePath -Raw

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

Assert-Matches $cmake 'src/qml/ShortcutCatalog\.js' 'ShortcutCatalog.js must be packaged with the QML module so the app can start from the built executable.'

Write-Output 'QML resource packaging static checks passed.'
