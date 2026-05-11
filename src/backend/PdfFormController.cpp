// PdfFormController.cpp — AcroForm fill implementation via PoDoFo 0.10.x.
// All PoDoFo calls are guarded by PDFCLOWNE_ENABLE_PODOFO.
// When the flag is absent, every method returns false/empty (clean stub).
//
// PoDoFo API notes (0.10.x, vcpkg):
//   PdfField::GetWidget(unsigned)         → PdfAnnotationWidget&
//   PdfAnnotationWidget::GetRect()        → PdfRect  (bottom-left origin)
//   PdfAnnotationWidget::GetPage()        → PdfPage* (may be nullptr)
//   PdfTextField::GetText()               → PoDoFo::nullable<PdfString>
//   PdfCheckBox::IsChecked()              → bool
//   PdfComboBox::GetSelectedItemText()    → PoDoFo::nullable<PdfString>
//   PdfMemDocument::Save(path)            → writes incremental update
//   Y-flip: screenY = pageH - pdfBottom - fieldH  (mapPageRect expects top-left)

#include "PdfFormController.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#ifdef PDFCLOWNE_ENABLE_PODOFO
#include <podofo/podofo.h>
#endif

PdfFormController::PdfFormController(QObject *parent)
    : QObject(parent)
{}

PdfFormController::~PdfFormController() = default;

// ─────────────────────────────────────────────────────────────────────────────
// Queries
// ─────────────────────────────────────────────────────────────────────────────

bool PdfFormController::isAvailable() const
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    return true;
#else
    return false;
#endif
}

QString PdfFormController::fieldsJson() const { return m_fieldsJson; }
bool    PdfFormController::isDirty()    const { return m_dirty; }

int PdfFormController::fieldCount() const
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    return m_fields.size();
#else
    return 0;
#endif
}

bool PdfFormController::hasSignatureFields() const
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    for (const auto &f : m_fields)
        if (f.type == QLatin1String("signature"))
            return true;
#endif
    return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Load
// ─────────────────────────────────────────────────────────────────────────────

bool PdfFormController::loadForms(const QString &pdfPath)
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    clear();

    m_doc = std::make_unique<PoDoFo::PdfMemDocument>();
    try {
        m_doc->Load(pdfPath.toStdString());
    } catch (const PoDoFo::PdfError &e) {
        m_doc.reset();
        emit loadFailed(QString::fromStdString(e.what()));
        return false;
    } catch (...) {
        m_doc.reset();
        emit loadFailed(QStringLiteral("Unknown error loading PDF for forms"));
        return false;
    }

    PoDoFo::PdfAcroForm *acroForm = m_doc->GetAcroForm();
    if (!acroForm || acroForm->GetFieldCount() == 0) {
        emit fieldsChanged();
        return true;
    }

    const unsigned count = acroForm->GetFieldCount();
    for (unsigned i = 0; i < count; ++i) {
        PoDoFo::PdfField *fieldPtr = nullptr;
        try {
            fieldPtr = &acroForm->GetFieldAt(i);
        } catch (...) {
            continue;
        }
        if (!fieldPtr) continue;
        PoDoFo::PdfField &field = *fieldPtr;

        FieldEntry entry;
        entry.index    = static_cast<int>(i);
        entry.id       = QString::number(i);
        entry.readOnly = field.IsReadOnly();
        entry.required = field.IsRequired();

        try {
            entry.name = QString::fromStdString(field.GetFullName());
        } catch (...) {}

        const auto ft = field.GetType();
        switch (ft) {
        case PoDoFo::PdfFieldType::TextField:
            entry.type = QStringLiteral("text");
            try {
                auto text = static_cast<PoDoFo::PdfTextField &>(field).GetText();
                if (text.has_value())
                    entry.value = QString::fromStdString(std::string(text->GetString()));
            } catch (...) {}
            break;

        case PoDoFo::PdfFieldType::CheckBox:
            entry.type = QStringLiteral("checkbox");
            try {
                entry.value = static_cast<PoDoFo::PdfCheckBox &>(field).IsChecked()
                              ? QStringLiteral("true") : QStringLiteral("false");
            } catch (...) {}
            break;

        case PoDoFo::PdfFieldType::RadioButton:
            entry.type = QStringLiteral("radio");
            break;

        case PoDoFo::PdfFieldType::ComboBox:
            entry.type = QStringLiteral("combo");
            try {
                auto sel = static_cast<PoDoFo::PdfComboBox &>(field).GetSelectedItemText();
                if (sel.has_value())
                    entry.value = QString::fromStdString(std::string(sel->GetString()));
            } catch (...) {}
            break;

        case PoDoFo::PdfFieldType::ListBox:
            entry.type = QStringLiteral("list");
            break;

        case PoDoFo::PdfFieldType::Signature:
            entry.type = QStringLiteral("signature");
            break;

        default:
            entry.type = QStringLiteral("unknown");
            break;
        }

        // Rect from first widget — flip Y from PDF bottom-left to screen top-left
        try {
            if (field.GetWidgetCount() > 0) {
                PoDoFo::PdfAnnotationWidget &widget = field.GetWidget(0);
                const PoDoFo::PdfRect rect = widget.GetRect();
                const PoDoFo::PdfPage *page = widget.GetPage();
                if (page) {
                    entry.pageIndex = static_cast<int>(
                        m_doc->GetPages().GetPageIndex(*page));
                    const double pageH = page->GetRect().GetHeight();
                    entry.x = rect.GetLeft();
                    entry.w = rect.GetWidth();
                    entry.h = rect.GetHeight();
                    entry.y = pageH - rect.GetBottom() - rect.GetHeight();
                }
            }
        } catch (...) {}

        m_fields.append(entry);
    }

    rebuildJson();
    emit fieldsChanged();
    return true;

#else
    Q_UNUSED(pdfPath)
    emit loadFailed(QStringLiteral("Forms not available — build with ENABLE_PODOFO=ON"));
    return false;
#endif
}

// ─────────────────────────────────────────────────────────────────────────────
// Setters
// ─────────────────────────────────────────────────────────────────────────────

bool PdfFormController::setTextValue(const QString &fieldId, const QString &value)
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    if (!m_doc) return false;
    bool ok = false;
    const int idx = fieldId.toInt(&ok);
    if (!ok || idx < 0 || idx >= m_fields.size()) return false;

    try {
        PoDoFo::PdfField &field = m_doc->GetAcroForm()->GetFieldAt(
            static_cast<unsigned>(idx));
        if (field.GetType() != PoDoFo::PdfFieldType::TextField)
            return false;
        static_cast<PoDoFo::PdfTextField &>(field).SetText(value.toStdString());
        m_fields[idx].value = value;
        m_dirty = true;
        rebuildJson();
        emit fieldsChanged();
        emit dirtyChanged();
        return true;
    } catch (const PoDoFo::PdfError &e) {
        emit loadFailed(QString::fromStdString(e.what()));
    }
#else
    Q_UNUSED(fieldId) Q_UNUSED(value)
#endif
    return false;
}

bool PdfFormController::setCheckState(const QString &fieldId, bool checked)
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    if (!m_doc) return false;
    bool ok = false;
    const int idx = fieldId.toInt(&ok);
    if (!ok || idx < 0 || idx >= m_fields.size()) return false;

    try {
        PoDoFo::PdfField &field = m_doc->GetAcroForm()->GetFieldAt(
            static_cast<unsigned>(idx));
        if (field.GetType() != PoDoFo::PdfFieldType::CheckBox)
            return false;
        static_cast<PoDoFo::PdfCheckBox &>(field).SetChecked(checked);
        m_fields[idx].value = checked ? QStringLiteral("true") : QStringLiteral("false");
        m_dirty = true;
        rebuildJson();
        emit fieldsChanged();
        emit dirtyChanged();
        return true;
    } catch (const PoDoFo::PdfError &e) {
        emit loadFailed(QString::fromStdString(e.what()));
    }
#else
    Q_UNUSED(fieldId) Q_UNUSED(checked)
#endif
    return false;
}

bool PdfFormController::setRadioValue(const QString &groupName, const QString &optionValue)
{
    // TODO: radio group iteration requires walking the Kids array in the AcroForm dict.
    // Deferred to Phase 1.1 — the overlay already shows radio fields visually.
    Q_UNUSED(groupName)
    Q_UNUSED(optionValue)
    return false;
}

bool PdfFormController::setComboValue(const QString &fieldId, const QString &value)
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    if (!m_doc) return false;
    bool ok = false;
    const int idx = fieldId.toInt(&ok);
    if (!ok || idx < 0 || idx >= m_fields.size()) return false;

    try {
        PoDoFo::PdfField &field = m_doc->GetAcroForm()->GetFieldAt(
            static_cast<unsigned>(idx));
        if (field.GetType() != PoDoFo::PdfFieldType::ComboBox)
            return false;
        static_cast<PoDoFo::PdfComboBox &>(field).SetCurrentValueByIndex(
            static_cast<int>(value.toInt()));  // fallback: treat value as index string
        m_fields[idx].value = value;
        m_dirty = true;
        rebuildJson();
        emit fieldsChanged();
        emit dirtyChanged();
        return true;
    } catch (...) {
        // If int-index fails, try setting via text value (not all PoDoFo builds expose this)
        emit loadFailed(QStringLiteral("Combo setter: index-based set failed. Check PoDoFo API."));
    }
#else
    Q_UNUSED(fieldId) Q_UNUSED(value)
#endif
    return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Save
// ─────────────────────────────────────────────────────────────────────────────

bool PdfFormController::saveFilled(const QString &outPath)
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    if (!m_doc) return false;
    try {
        m_doc->Save(outPath.toStdString());
        m_dirty = false;
        emit dirtyChanged();
        return true;
    } catch (const PoDoFo::PdfError &e) {
        emit loadFailed(QString::fromStdString(e.what()));
    } catch (...) {
        emit loadFailed(QStringLiteral("Unknown error saving filled PDF"));
    }
#else
    Q_UNUSED(outPath)
    emit loadFailed(QStringLiteral("Forms not available — build with ENABLE_PODOFO=ON"));
#endif
    return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

void PdfFormController::clear()
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    m_fields.clear();
    m_doc.reset();
#endif
    m_dirty = false;
    m_fieldsJson = QStringLiteral("[]");
    emit fieldsChanged();
    emit dirtyChanged();
}

void PdfFormController::rebuildJson()
{
#ifdef PDFCLOWNE_ENABLE_PODOFO
    QJsonArray arr;
    for (const FieldEntry &f : std::as_const(m_fields)) {
        QJsonObject obj;
        obj[QStringLiteral("id")]        = f.id;
        obj[QStringLiteral("name")]      = f.name;
        obj[QStringLiteral("type")]      = f.type;
        obj[QStringLiteral("value")]     = f.value;
        obj[QStringLiteral("readOnly")]  = f.readOnly;
        obj[QStringLiteral("required")]  = f.required;
        obj[QStringLiteral("pageIndex")] = f.pageIndex;

        QJsonObject rect;
        rect[QStringLiteral("x")]      = f.x;
        rect[QStringLiteral("y")]      = f.y;
        rect[QStringLiteral("width")]  = f.w;
        rect[QStringLiteral("height")] = f.h;
        obj[QStringLiteral("rect")]    = rect;

        arr.append(obj);
    }
    m_fieldsJson = QString::fromUtf8(
        QJsonDocument(arr).toJson(QJsonDocument::Compact));
#endif
}
