$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Read-ProjectFile {
    param([string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $RelativePath"
    }
    Get-Content -LiteralPath $path -Raw
}

function Assert-Matches {
    param([string]$Content, [string]$Pattern, [string]$Message)
    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotMatches {
    param([string]$Content, [string]$Pattern, [string]$Message)
    if ($Content -match $Pattern) {
        throw $Message
    }
}

$theme = Read-ProjectFile 'src/qml/Theme.qml'
$cmake = Read-ProjectFile 'CMakeLists.txt'
$editToolbar = Read-ProjectFile 'src/qml/EditToolbar.qml'
$contextToolbar = Read-ProjectFile 'src/qml/EditingToolbar.qml'
$inspector = Read-ProjectFile 'src/qml/EditInspector.qml'
$editableBox = Read-ProjectFile 'src/qml/EditableTextBox.qml'
$viewer = Read-ProjectFile 'src/qml/PdfViewer.qml'
$progress = Read-ProjectFile 'docs/PROGRESO_FASE5.md'

foreach ($component in @(
    'PclToolButton.qml',
    'PclButton.qml',
    'PclComboBox.qml',
    'PclSpinBox.qml',
    'PclCheckBox.qml',
    'PclColorSwatch.qml'
)) {
    $content = Read-ProjectFile "src/qml/$component"
    Assert-Matches $cmake "src/qml/$component" "CMake must include $component in the QML module."
    Assert-Matches $content 'Theme\.' "$component must use Theme tokens."
}

$toolButton = Read-ProjectFile 'src/qml/PclToolButton.qml'
Assert-NotMatches $toolButton 'property\s+bool\s+checked' 'PclToolButton.qml must use Button.checked and must not override the final checked property.'

foreach ($token in @(
    'controlHeight',
    'compactControlHeight',
    'iconButtonSize',
    'controlFill',
    'controlFillHover',
    'controlFillPressed',
    'controlDisabled',
    'focusRing',
    'editSelection',
    'editSelectionSoft'
)) {
    Assert-Matches $theme $token "Theme.qml must expose $token for unified edit UI styling."
}

Assert-Matches $editToolbar 'PclToolButton' 'EditToolbar.qml must use PclToolButton for edit tools.'
Assert-Matches $contextToolbar 'PclToolButton' 'EditingToolbar.qml must use PclToolButton for contextual actions.'
Assert-Matches $inspector 'PclComboBox' 'EditInspector.qml must use PclComboBox instead of native ComboBox.'
Assert-Matches $inspector 'PclSpinBox' 'EditInspector.qml must use PclSpinBox instead of native SpinBox.'
Assert-Matches $inspector 'PclButton' 'EditInspector.qml must use PclButton for actions.'
Assert-Matches $inspector 'PclCheckBox' 'EditInspector.qml must use PclCheckBox for incremental save.'
Assert-Matches $inspector 'PclColorSwatch' 'EditInspector.qml must use PclColorSwatch for color.'

Assert-NotMatches $inspector '\bComboBox\s*\{' 'EditInspector.qml must not instantiate native ComboBox directly.'
Assert-NotMatches $inspector '\bSpinBox\s*\{' 'EditInspector.qml must not instantiate native SpinBox directly.'
Assert-NotMatches $inspector '\bCheckBox\s*\{' 'EditInspector.qml must not instantiate native CheckBox directly.'
Assert-NotMatches $contextToolbar '#F5F5F5|#BDBDBD|#333' 'EditingToolbar.qml must not keep the old light hardcoded palette.'
Assert-NotMatches $editableBox '#FFF8E1|#FFF3E0|#FFB300|#FB8C00|#2196F3|#4CAF50' 'EditableTextBox.qml edit styling must use Theme tokens instead of old hardcoded bright colors.'
Assert-NotMatches $viewer '#FFF8E1|#FFB300|#5D4500' 'PdfViewer.qml phase 5 notices must use Theme tokens instead of hardcoded warning colors.'

Assert-Matches $progress 'La UI de edición no coincide[\s\S]*corregido técnicamente[\s\S]*pendiente de verificación del usuario' `
    'PROGRESO_FASE5.md must keep the user-reported UI mismatch as pending user verification.'

Write-Output 'Edit UI style contract checks passed.'
