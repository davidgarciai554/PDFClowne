#include "PdfEditFontDecision.h"
#include "PdfTextEditSaveTestUtils.h"

#include <QCoreApplication>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    Q_UNUSED(argv)

    PDFClowne::Editing::PdfFontResolver::ResolvedFont resolved;
    resolved.originalSubsetName = QStringLiteral("ABCDEF+Montserrat-Bold");
    resolved.debugFamilyName = QStringLiteral("Montserrat-Bold");
    resolved.fontProgram = QByteArray("not-a-real-font-but-rejected-before-validation");

    PDFClowne::Editing::PdfEditFontDecisionService service;
    const PDFClowne::Editing::PdfEditFontDecision decision =
        service.decideFontForEditedText(resolved,
                                        QStringLiteral("Backend y Arquitectura"),
                                        true,
                                        false);

    if (!decision.subsetOriginalRejected)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Subset original font was not rejected."));
    if (!decision.useBundledFallback)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Subset rejection did not select bundled fallback."));
    if (decision.useEmbeddedOriginal)
        return PdfTextEditSaveTestUtils::fail(QStringLiteral("Subset original font was still selected."));

    return 0;
}
