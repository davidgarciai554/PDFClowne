$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$pdfHeaderPath = Join-Path $root 'src/backend/PdfDocument.h'
$pdfSourcePath = Join-Path $root 'src/backend/PdfDocument.cpp'
$mainQmlPath = Join-Path $root 'src/qml/main.qml'
$renderSourcePath = Join-Path $root 'src/backend/DocumentRenderController.cpp'
$searchSourcePath = Join-Path $root 'src/backend/DocumentSearchController.cpp'

$pdfHeader = Get-Content -LiteralPath $pdfHeaderPath -Raw
$pdfSource = Get-Content -LiteralPath $pdfSourcePath -Raw
$mainQml = Get-Content -LiteralPath $mainQmlPath -Raw
$renderSource = Get-Content -LiteralPath $renderSourcePath -Raw
$searchSource = Get-Content -LiteralPath $searchSourcePath -Raw

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

Assert-Matches $pdfHeader 'Q_PROPERTY\(bool\s+passwordRequired\s+READ\s+passwordRequired\s+NOTIFY\s+passwordRequiredChanged\)' 'PdfDocument must expose whether the current PDF requires a password.'
Assert-Matches $pdfHeader 'Q_PROPERTY\(QString\s+password\s+READ\s+password\s+WRITE\s+setPassword\s+NOTIFY\s+passwordChanged\)' 'PdfDocument must expose the active password to QML.'
Assert-Matches $pdfHeader 'bool\s+load\(const\s+QString\s+&source,\s*const\s+QString\s+&password\s*=\s*\{\}\s*\);' 'PdfDocument::load must accept an optional password.'
Assert-Matches $pdfHeader 'Q_INVOKABLE\s+bool\s+retryWithPassword\(const\s+QString\s+&password\);' 'PdfDocument must expose retryWithPassword for protected PDFs.'
Assert-Matches $pdfSource 'fz_authenticate_password' 'PdfDocument must authenticate password-protected PDFs through MuPDF.'
Assert-Matches $pdfSource 'password-protected PDF' 'PdfDocument must preserve explicit password-protection errors.'
Assert-Matches $mainQml 'id:\s*passwordDialog' 'main.qml must define a dedicated password popup for protected PDFs.'
Assert-Matches $mainQml 'TextField\s*\{\s*id:\s*passwordField' 'The password popup must include a password text field.'
Assert-Matches $mainQml 'function\s+showPasswordDialog\(' 'main.qml must centralize password prompting so protected PDFs can always ask again.'
Assert-Matches $mainQml 'function\s+loadPdfWithPasswordPrompt\(' 'main.qml must expose a reusable load helper that can reopen the password dialog.'
Assert-Matches $mainQml 'window\.openProtectedPdf\(' 'main.qml must route protected PDFs through a password entry flow.'
Assert-Matches $mainQml 'pdfDocument\.retryWithPassword\(' 'Password submissions must retry opening the protected PDF.'
Assert-Matches $mainQml 'text:\s*"Introducir contrasena"' 'The password popup must use a themed title consistent with the rest of the app.'
Assert-Matches $mainQml 'passwordDialog\.inlineError\s*=\s*"La contrasena no es correcta\. Prueba de nuevo\."' 'Wrong passwords must keep the dialog open and allow another attempt.'
Assert-Matches $mainQml 'if\s*\(\s*pdfDocument\.passwordRequired\s*\)\s*\{\s*showPasswordDialog\(' 'Any protected-document load failure must reopen the password dialog instead of dead-ending.'
Assert-Matches $mainQml 'function\s+shouldShowGlobalPdfError\(' 'main.qml must distinguish password errors from global document errors.'
Assert-Matches $mainQml 'visible:\s*window\.shouldShowGlobalPdfError\(\)' 'The home screen must hide password errors from the global banner.'
Assert-Matches $mainQml 'text:\s*window\.shouldShowGlobalPdfError\(\)\s*\?\s*pdfDocument\.errorMessage' 'Global status text must ignore password-entry failures.'
Assert-Matches $renderSource 'fz_needs_password\(m_ctx,\s*m_doc\)' 'DocumentRenderController must still guard background render opens against protected PDFs.'
Assert-Matches $searchSource 'fz_needs_password\(ctx,\s*doc\)' 'DocumentSearchController must still guard background search opens against protected PDFs.'

Write-Output 'Password-protected PDF flow static checks passed.'
