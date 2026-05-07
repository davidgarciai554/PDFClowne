$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainQmlPath = Join-Path $root 'src/qml/main.qml'
$searchHeaderPath = Join-Path $root 'src/backend/DocumentSearchController.h'
$searchSourcePath = Join-Path $root 'src/backend/DocumentSearchController.cpp'
$renderHeaderPath = Join-Path $root 'src/backend/DocumentRenderController.h'
$renderSourcePath = Join-Path $root 'src/backend/DocumentRenderController.cpp'
$pdfSourcePath = Join-Path $root 'src/backend/PdfDocument.cpp'

$mainQml = Get-Content -LiteralPath $mainQmlPath -Raw
$searchHeader = Get-Content -LiteralPath $searchHeaderPath -Raw
$searchSource = Get-Content -LiteralPath $searchSourcePath -Raw
$renderHeader = Get-Content -LiteralPath $renderHeaderPath -Raw
$renderSource = Get-Content -LiteralPath $renderSourcePath -Raw
$pdfSource = Get-Content -LiteralPath $pdfSourcePath -Raw

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
Assert-Matches $searchHeader 'Q_INVOKABLE\s+void\s+cancelSearchSync\(\);' 'DocumentSearchController must expose a synchronous search cancellation hook for save transactions.'
Assert-Matches $searchSource 'void\s+DocumentSearchController::cancelSearchSync\(\)\s*\{[\s\S]*QMetaObject::invokeMethod\(m_worker,\s*\[worker\s*=\s*m_worker\]\(\)\s*\{\s*worker->cancelSearches\(\);\s*\},\s*Qt::BlockingQueuedConnection\);[\s\S]*setBusy\(false\);[\s\S]*\}' 'Synchronous search cancellation must block until the worker is idle and its PDF handles are released.'
Assert-Matches $searchSource 'void\s+cancelSearches\(\)\s*\{\s*\+\+m_sequence;\s*\}' 'The search worker must invalidate any in-flight or queued searches during save.'
Assert-Matches $mainQml 'function\s+performDocumentSaveTransaction\(index,\s*target,\s*refreshAfterSave\)' 'Save flow must be encapsulated in a dedicated transaction helper.'
Assert-Matches $mainQml 'documentSearchController\.cancelSearchSync\(\)' 'Save transactions must quiesce the search pipeline before writing PDFs.'
Assert-Matches $mainQml 'documentRenderController\.releaseDocumentSync\(doc\.path,\s*sessionId\)' 'Overwrite save must synchronously release the active render session before saving.'
Assert-Matches $mainQml 'function\s+performDocumentSaveTransaction\(index,\s*target,\s*refreshAfterSave\)\s*\{[\s\S]*try\s*\{[\s\S]*pdfDocument\.saveEditedCopy\([\s\S]*finally\s*\{[\s\S]*setDocumentSaveInProgress\(doc\.path,\s*false\)' 'Save transactions must always release the temporary save lock even if saving throws or fails.'
Assert-Matches $mainQml 'function\s+isDocumentSaveInProgress\(path\)' 'Overwrite save must expose a save lock lookup by document path.'
Assert-Matches $mainQml 'function\s+restoreDocumentAfterFailedSave\(index,\s*password,\s*sessionId\)' 'Overwrite save must restore the active backend after a failed overwrite attempt.'
Assert-Matches $mainQml 'function\s+requestActivePageRender\(pageIndex,\s*scale\)\s*\{[\s\S]*if\s*\(isDocumentSaveInProgress\(doc\.path\)\)\s*return[\s\S]*documentRenderController\.requestPageRender' 'Active page renders must be paused while an overwrite save is in progress.'
Assert-Matches $mainQml 'function\s+requestActiveThumbnailRender\(pageIndex\)\s*\{[\s\S]*if\s*\(isDocumentSaveInProgress\(doc\.path\)\)\s*return[\s\S]*documentRenderController\.requestThumbnailRender' 'Thumbnail renders must be paused while an overwrite save is in progress.'
Assert-Matches $mainQml 'setDocumentSaveInProgress\(doc\.path,\s*true\)' 'Overwrite save must lock the document against new render requests before writing.'
Assert-Matches $mainQml 'setDocumentSaveInProgress\(doc\.path,\s*false\)' 'Overwrite save must always release the temporary save lock after writing.'
Assert-Matches $mainQml 'documentRenderController\.markDocumentOpened\(doc\.path,\s*sessionId,\s*password\)' 'Overwrite save must restore the render session if the save fails.'
Assert-Matches $mainQml 'if\s*\(!refreshActiveDocumentFromDisk\(\)\)\s*\{\s*restoreDocumentAfterFailedSave\(index,\s*password,\s*sessionId\)' 'Overwrite save must treat a failed post-save refresh as a failed save and restore the active backend.'
Assert-Matches $mainQml 'if\s*\(overwriteCurrent\)\s*restoreDocumentAfterFailedSave\(index,\s*password,\s*sessionId\)' 'Overwrite save must restore the active backend after a failed overwrite save.'
Assert-Matches $pdfSource 'pdf_needs_password\(ctx,\s*doc\)' 'Password-protected PDFs must still be detected during save.'
Assert-Matches $pdfSource 'pdf_authenticate_password' 'Saving a protected PDF must authenticate with the active password.'

Write-Output 'PDF overwrite save static checks passed.'
