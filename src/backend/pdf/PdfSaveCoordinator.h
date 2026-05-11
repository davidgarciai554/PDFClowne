#pragma once

#include <QString>

#include <functional>

namespace PDFClowne::Editing {

class PdfSaveCoordinator {
public:
    using WriteCallback = std::function<bool(const QString &tempPath, QString *error)>;

    struct SaveResult {
        bool ok = false;
        QString finalPath;
        QString backupPath;
        QString error;
    };

    // Transaction contract: write temp -> validate -> backup -> replace.
    SaveResult saveAsCopy(const QString &targetPath, const WriteCallback &writer) const;
    SaveResult replaceOriginalTransaction(const QString &originalPath,
                                          const WriteCallback &writer,
                                          bool keepUserBackup) const;

    static QString tempPdfPathFor(const QString &targetPath);
    static bool canOpenAsPdf(const QString &path, QString *error);
    static bool replaceFileWithBackup(const QString &sourcePath,
                                      const QString &replacementPath,
                                      QString *backupPath,
                                      QString *error);
};

} // namespace PDFClowne::Editing
