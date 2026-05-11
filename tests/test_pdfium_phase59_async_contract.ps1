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
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )
    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$controllerHeader = Read-ProjectFile 'src/core/editing/EditingController.h'
$controllerSource = Read-ProjectFile 'src/core/editing/EditingController.cpp'
$extractWorkerHeader = Read-ProjectFile 'src/core/editing/PdfExtractionWorker.h'
$extractWorkerSource = Read-ProjectFile 'src/core/editing/PdfExtractionWorker.cpp'
$saveWorkerHeader = Read-ProjectFile 'src/core/editing/PdfSaveWorker.h'
$saveWorkerSource = Read-ProjectFile 'src/core/editing/PdfSaveWorker.cpp'
$viewerQml = Read-ProjectFile 'src/qml/PdfViewer.qml'
$editableQml = Read-ProjectFile 'src/qml/EditableTextBox.qml'
$cmake = Read-ProjectFile 'CMakeLists.txt'
$progress = Read-ProjectFile 'docs/PROGRESO_FASE5.md'
$design = Read-ProjectFile 'docs/PHASE5_DESIGN.md'

Assert-Matches $extractWorkerHeader 'class\s+PdfExtractionWorker\s*:\s*public\s+QObject' `
    'Phase 5.9 requires a QObject extraction worker.'
Assert-Matches $saveWorkerHeader 'class\s+PdfSaveWorker\s*:\s*public\s+QObject' `
    'Phase 5.9 requires a QObject save worker.'

Assert-Matches $extractWorkerHeader 'progressChanged\(int,\s*const\s+QString&\)' `
    'Extraction worker must expose progress updates.'
Assert-Matches $saveWorkerHeader 'progressChanged\(int,\s*const\s+QString&\)' `
    'Save worker must expose progress updates.'
Assert-Matches $extractWorkerHeader 'finished\(int,\s*const\s+QList<\s*PdfTextBlock\s*>&,\s*bool\)' `
    'Extraction worker must return blocks and scanned-PDF suspicion.'
Assert-Matches $saveWorkerHeader 'finished\(const\s+QString&\)' `
    'Save worker must report the saved output path.'

Assert-Matches $controllerHeader 'Q_PROPERTY\(bool\s+busy\s+READ\s+isBusy\s+NOTIFY\s+busyChanged\)' `
    'EditingController must expose a busy state to QML.'
Assert-Matches $controllerHeader 'Q_PROPERTY\(int\s+progress\s+READ\s+progress\s+NOTIFY\s+progressChanged\)' `
    'EditingController must expose progress to QML.'
Assert-Matches $controllerHeader 'Q_PROPERTY\(QString\s+statusMessage\s+READ\s+statusMessage\s+NOTIFY\s+statusMessageChanged\)' `
    'EditingController must expose status text to QML.'
Assert-Matches $controllerHeader 'Q_PROPERTY\(bool\s+scannedDocumentSuspected\s+READ\s+scannedDocumentSuspected\s+NOTIFY\s+scannedDocumentSuspectedChanged\)' `
    'EditingController must expose scanned-document detection to QML.'

Assert-Matches $controllerSource 'new\s+QThread\(this\)' `
    'EditingController must run heavy phase 5.9 work on QThread.'
Assert-Matches $controllerSource 'moveToThread\(' `
    'EditingController must move workers to their QThread.'
Assert-Matches $controllerSource 'PdfExtractionWorker' `
    'EditingController must dispatch extraction through PdfExtractionWorker.'
Assert-Matches $controllerSource 'PdfSaveWorker' `
    'EditingController must dispatch saves through PdfSaveWorker.'
Assert-Matches $controllerSource 'if\s*\(\s*block\s*&&\s*!block->isEditable\s*\)' `
    'EditingController must refuse text updates for non-editable blocks.'
Assert-Matches $controllerSource 'tr\(' `
    'New phase 5.9 user-facing C++ strings must be translatable.'
Assert-Matches $controllerSource 'spdlog::(info|warn|error)' `
    'Phase 5.9 critical operations must be logged.'

Assert-Matches $viewerQml 'ProgressBar' `
    'PdfViewer must show progress while extraction/save workers are active.'
Assert-Matches $viewerQml 'editingController\.busy' `
    'PdfViewer progress UI must be driven by EditingController.busy.'
Assert-Matches $viewerQml 'editingController\.scannedDocumentSuspected' `
    'PdfViewer must show an OCR suggestion when a scanned PDF is suspected.'
Assert-Matches $viewerQml 'qsTr\(' `
    'New phase 5.9 QML strings must use qsTr().'
Assert-Matches $editableQml 'nonEditableReason' `
    'EditableTextBox must show or carry the reason when a block is not editable.'

Assert-Matches $cmake 'PdfExtractionWorker\.cpp' `
    'CMake must compile PdfExtractionWorker when PDFium editing is enabled.'
Assert-Matches $cmake 'PdfSaveWorker\.cpp' `
    'CMake must compile PdfSaveWorker when PDFium editing is enabled.'

Assert-Matches $progress 'Sub-fase 5\.9[\s\S]*\*\(completada\)\*' `
    'docs/PROGRESO_FASE5.md must mark sub-phase 5.9 as completed.'
Assert-Matches $design 'QThread[\s\S]*PdfExtractionWorker[\s\S]*PdfSaveWorker' `
    'docs/PHASE5_DESIGN.md must document the phase 5.9 async architecture.'
Assert-Matches $design 'Limitaciones' `
    'docs/PHASE5_DESIGN.md must document known limitations.'

Write-Output 'PDFium phase 5.9 async contract checks passed.'
