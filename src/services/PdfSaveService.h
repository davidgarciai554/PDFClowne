#pragma once

// Architecture contract for safe PDF save operations.
// Current implementation: PdfDocument::saveEditedCopy + replaceOriginalSafely (src/backend/).
// Strategy: always write to temp → validate → rename. Never overwrite original directly.

#include <QString>

namespace PDFClowne {

struct SaveOptions {
    bool createBackup = true;       // Keep .bak copy of original before overwrite
    bool validateAfterWrite = true; // Try to open temp before replacing original
    bool saveAsCopy = true;         // Default: save to new path, not overwrite original
    QString pageOrderJson;          // Optional reorder
    QString rotationsJson;          // Optional per-page rotations
    QString annotationsJson;        // Optional annotations to embed
    QString password;
};

class PdfSaveService {
public:
    virtual ~PdfSaveService() = default;

    // Saves to outputPath. Safe: writes temp first, validates, renames.
    virtual bool saveAs(const QString &sourcePath, const QString &outputPath,
                        const SaveOptions &options = {}) = 0;

    // Overwrites the original. Writes temp → validate → backup original → rename.
    // WARNING: irreversible if backup=false and rename succeeds.
    virtual bool saveInPlace(const QString &sourcePath,
                             const SaveOptions &options = {}) = 0;

    // Lightweight check: can the file at path be opened as a valid PDF?
    virtual bool canOpenAsPdf(const QString &path) const = 0;
};

} // namespace PDFClowne
