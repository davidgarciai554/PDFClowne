#pragma once

// Architecture contract for PDF AcroForm operations.
// Future implementation: PoDoFo-based (requires ENABLE_PODOFO=ON, ENABLE_FORMS=ON).
// XFA forms are NOT supported — AcroForm only.

#include <QString>

namespace PDFClowne {

struct PdfFieldInfo {
    QString id;
    QString name;
    QString type;       // "text" | "checkbox" | "radio" | "combo" | "list" | "signature"
    QString value;
    QString defaultValue;
    bool readOnly = false;
    bool required = false;
    int pageIndex = 0;
    double x = 0, y = 0, width = 0, height = 0;  // PDF points
};

class PdfFormService {
public:
    virtual ~PdfFormService() = default;

    virtual bool loadDocument(const QString &path) = 0;

    // Returns JSON array of PdfFieldInfo.
    virtual QString fieldsJson() const = 0;

    virtual bool setTextValue(const QString &fieldId, const QString &value) = 0;
    virtual bool setCheckState(const QString &fieldId, bool checked) = 0;
    virtual bool setRadioValue(const QString &groupName, const QString &optionValue) = 0;
    virtual bool setComboValue(const QString &fieldId, const QString &value) = 0;

    // Saves filled form. Returns false if output path is invalid or write fails.
    virtual bool saveFilled(const QString &outPath) = 0;

    virtual bool hasSignatureFields() const = 0;
};

} // namespace PDFClowne
