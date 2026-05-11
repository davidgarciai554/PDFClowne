#pragma once

// Architecture contract for structural PDF operations.
// Implementation: QPDF-based (requires ENABLE_QPDF=ON).
// Use for: split, merge, reorder, encrypt/decrypt, repair, normalize, inspect objects.

#include <QString>
#include <QStringList>

namespace PDFClowne {

class PdfStructureService {
public:
    virtual ~PdfStructureService() = default;

    virtual bool isAvailable() const = 0;

    // Validates PDF structure. Returns JSON { valid, errors[], warnings[] }.
    virtual QString validateDocument(const QString &path) const = 0;

    // Attempts linearization + repair. Returns false if QPDF cannot fix it.
    virtual bool repairDocument(const QString &inputPath, const QString &outputPath) = 0;

    // Extracts a page range [firstPage, lastPage] (0-based) into a new PDF.
    virtual bool extractPages(const QString &inputPath, const QString &outputPath,
                              int firstPage, int lastPage) = 0;

    // Merges an ordered list of input PDFs into outputPath.
    virtual bool mergeDocuments(const QStringList &inputPaths, const QString &outputPath) = 0;

    // Encrypt with user and owner passwords. permissions: QPDF permission flags.
    virtual bool encryptDocument(const QString &inputPath, const QString &outputPath,
                                 const QString &userPassword, const QString &ownerPassword,
                                 int permissionFlags = 0) = 0;

    virtual bool decryptDocument(const QString &inputPath, const QString &outputPath,
                                 const QString &password) = 0;

    // Normalizes and linearizes for web / reliable save baseline.
    virtual bool normalizeDocument(const QString &inputPath, const QString &outputPath) = 0;
};

} // namespace PDFClowne
