$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainQmlPath = Join-Path $root 'src/qml/main.qml'
$renderHeaderPath = Join-Path $root 'src/backend/DocumentRenderController.h'
$renderSourcePath = Join-Path $root 'src/backend/DocumentRenderController.cpp'

$mainQml = Get-Content -LiteralPath $mainQmlPath -Raw
$renderHeader = Get-Content -LiteralPath $renderHeaderPath -Raw
$renderSource = Get-Content -LiteralPath $renderSourcePath -Raw

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

Assert-Matches $renderHeader 'Q_INVOKABLE\s+void\s+releaseDocumentSync\(const\s+QString\s+&filePath,\s+int\s+sessionId\);' 'DocumentRenderController must expose a synchronous release for overwrite saves.'
Assert-Matches $renderSource 'QMetaObject::invokeMethod\(m_worker,\s*\[worker\s*=\s*m_worker,\s*filePath,\s*sessionId\]\(\)\s*\{\s*worker->releaseDocument\(filePath,\s*sessionId\);\s*\},\s*Qt::BlockingQueuedConnection\);' 'Synchronous release must block until the worker has closed the PDF handles.'
Assert-Matches $mainQml 'documentRenderController\.releaseDocumentSync\(doc\.path,\s*doc\.renderSessionId\s*\|\|\s*0\)' 'Overwrite save must synchronously release the active render session before saving.'
Assert-Matches $mainQml 'documentRenderController\.markDocumentOpened\(doc\.path,\s*doc\.renderSessionId\s*\|\|\s*0\)' 'Overwrite save must restore the render session if the save fails.'

Write-Output 'PDF overwrite save static checks passed.'
