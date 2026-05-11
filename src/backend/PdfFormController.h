#pragma once

// PdfFormController — AcroForm fill layer (Phase 1).
// Engine: PoDoFo 0.10.x (vcpkg). Compiled only when PDFCLOWNE_ENABLE_PODOFO=1.
// Stub (isAvailable=false, all ops no-op) when PoDoFo is absent.

#include <QJsonArray>
#include <QObject>
#include <QString>
#include <QVector>

#ifdef PDFCLOWNE_ENABLE_PODOFO
#include <memory>
namespace PoDoFo { class PdfMemDocument; }
#endif

class PdfFormController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available      READ isAvailable       CONSTANT)
    Q_PROPERTY(QString fieldsJson  READ fieldsJson        NOTIFY fieldsChanged)
    Q_PROPERTY(bool dirty          READ isDirty           NOTIFY dirtyChanged)
    Q_PROPERTY(bool hasSignatureFields READ hasSignatureFields NOTIFY fieldsChanged)
    Q_PROPERTY(int fieldCount      READ fieldCount        NOTIFY fieldsChanged)

public:
    explicit PdfFormController(QObject *parent = nullptr);
    ~PdfFormController() override;

    bool isAvailable() const;
    QString fieldsJson() const;
    bool isDirty() const;
    bool hasSignatureFields() const;
    int fieldCount() const;

    Q_INVOKABLE bool loadForms(const QString &pdfPath);
    Q_INVOKABLE bool setTextValue(const QString &fieldId, const QString &value);
    Q_INVOKABLE bool setCheckState(const QString &fieldId, bool checked);
    Q_INVOKABLE bool setRadioValue(const QString &groupName, const QString &optionValue);
    Q_INVOKABLE bool setComboValue(const QString &fieldId, const QString &value);
    Q_INVOKABLE bool saveFilled(const QString &outPath);
    Q_INVOKABLE void clear();

signals:
    void fieldsChanged();
    void dirtyChanged();
    void loadFailed(const QString &error);

private:
    void rebuildJson();

    QString m_fieldsJson = QStringLiteral("[]");
    bool m_dirty = false;

#ifdef PDFCLOWNE_ENABLE_PODOFO
    struct FieldEntry {
        int index = 0;
        QString id;
        QString name;
        QString type;
        QString value;
        bool readOnly = false;
        bool required = false;
        int pageIndex = 0;
        double x = 0, y = 0, w = 0, h = 0;  // top-left PDF coords (Y already flipped)
    };

    std::unique_ptr<PoDoFo::PdfMemDocument> m_doc;
    QVector<FieldEntry> m_fields;
#endif
};
