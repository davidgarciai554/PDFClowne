$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainQmlPath = Join-Path $root 'src/qml/main.qml'
$catalogPath = Join-Path $root 'src/qml/ShortcutCatalog.js'
$docPath = Join-Path $root 'docs/SHORTCUTS.md'

$mainQml = Get-Content -LiteralPath $mainQmlPath -Raw
$catalog = Get-Content -LiteralPath $catalogPath -Raw
$doc = Get-Content -LiteralPath $docPath -Raw

function Assert-Matches {
    param(
        [string]$Pattern,
        [string]$Message,
        [string]$Source = $mainQml
    )

    if ($Source -notmatch $Pattern) {
        throw $Message
    }
}

Assert-Matches 'import\s+"ShortcutCatalog\.js"\s+as\s+ShortcutCatalog' 'main.qml must import the shared shortcut catalog.'
Assert-Matches 'readonly\s+property\s+var\s+shortcutSections\s*:\s*ShortcutCatalog\.sections' 'main.qml must expose the shared shortcut catalog to the UI.'
Assert-Matches 'id:\s*shortcutsButton' 'The top toolbar must expose a shortcuts button.'
Assert-Matches 'id:\s*shortcutsPopup' 'The app must provide an in-app shortcuts popup.'
Assert-Matches 'function\s+closeDocumentAt\s*\(index\)' 'main.qml must provide a targeted tab close helper.'
Assert-Matches 'acceptedButtons:\s*Qt\.MiddleButton[\s\S]*window\.closeDocumentAt\(documentTab\.index\)' 'Tabs must close on middle-click.'
Assert-Matches 'onClicked:\s*window\.closeDocumentAt\(documentTab\.index\)' 'The tab close button must use the shared close helper.'

$triggers = [regex]::Matches($catalog, 'trigger:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
if ($triggers.Count -lt 10) {
    throw 'The shared shortcut catalog should list the current keyboard shortcuts and tab gestures.'
}

foreach ($trigger in $triggers) {
    if ($doc -notmatch [regex]::Escape($trigger)) {
        throw "The markdown shortcuts reference is missing: $trigger"
    }
}

$keyboardTriggers = @(
    'Ctrl+O',
    'Ctrl+S',
    'Ctrl+Shift+S',
    'Ctrl+R',
    'Ctrl+H',
    'Ctrl+1',
    'Ctrl+2',
    'Ctrl+3',
    'Ctrl+4',
    'Ctrl+F',
    'F3',
    'Shift+F3',
    'Ctrl+L',
    'Ctrl+Shift+F',
    'F11',
    'F5',
    'H',
    'Ctrl+Shift+R',
    'Alt+Left',
    'Alt+Right',
    'F6',
    'Shift+F6',
    'Escape',
    'Right',
    'Left',
    'Space',
    'Backspace',
    'Ctrl+C',
    'Ctrl+Shift+C'
)

foreach ($trigger in $keyboardTriggers) {
    if ($mainQml -notmatch [regex]::Escape($trigger)) {
        throw "main.qml is missing the functional shortcut declaration for: $trigger"
    }
}

Write-Output 'Shortcut catalog static checks passed.'
