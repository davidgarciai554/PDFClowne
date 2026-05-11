#pragma once

// Architecture contract for PDF signature operations.
// Visual signature: stamp image/text/date overlay as PDF annotation (ENABLE_SIGNATURES=ON).
// Digital signature: PAdES/CAdES via OpenSSL + PoDoFo (future, ENABLE_PODOFO + OpenSSL).

#include <QString>
#include <QRectF>

namespace PDFClowne {

struct VisualSignatureParams {
    int pageIndex = 0;
    QRectF rect;            // PDF points
    QString imagePath;      // Optional: PNG/JPG import
    QString drawnSvgPath;   // Optional: exported from canvas drawing
    QString signerName;
    QString dateText;
    QString reason;
    QString location;
};

struct DigitalSignatureParams {
    QString pfxPath;        // PFX/P12 certificate file
    QString pfxPassword;
    QString reason;
    QString location;
    QString contactInfo;
};

class PdfSignatureService {
public:
    virtual ~PdfSignatureService() = default;

    // Stamps a visual signature (image/text) as a PDF annotation. No cryptographic binding.
    virtual bool stampVisualSignature(const QString &inputPath,
                                      const QString &outputPath,
                                      const VisualSignatureParams &params) = 0;

    // Applies a real PAdES digital signature. Requires ENABLE_PODOFO + OpenSSL.
    virtual bool applyDigitalSignature(const QString &inputPath,
                                       const QString &outputPath,
                                       const DigitalSignatureParams &params) = 0;

    // Returns JSON array of existing signature fields with validation status.
    virtual QString existingSignaturesJson(const QString &pdfPath) const = 0;

    virtual bool isDigitalSignatureAvailable() const = 0;
};

} // namespace PDFClowne
