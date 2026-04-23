/****************************************************************************
** Meta object code from reading C++ file 'PdfDocument.h'
**
** Created by: The Qt Meta Object Compiler version 68 (Qt 6.8.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../src/backend/PdfDocument.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'PdfDocument.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 68
#error "This file was generated using the moc from 6.8.3. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN11PdfDocumentE_t {};
} // unnamed namespace


#ifdef QT_MOC_HAS_STRINGDATA
static constexpr auto qt_meta_stringdata_ZN11PdfDocumentE = QtMocHelpers::stringData(
    "PdfDocument",
    "loaded",
    "",
    "loadFailed",
    "error",
    "filePathChanged",
    "previewSourceChanged",
    "pageSourcesChanged",
    "pageCountChanged",
    "titleChanged",
    "isLoadedChanged",
    "errorMessageChanged",
    "load",
    "source",
    "saveRotatedCopy",
    "target",
    "rotationsJson",
    "clear",
    "filePath",
    "previewSource",
    "pageSources",
    "pageCount",
    "title",
    "isLoaded",
    "errorMessage"
);
#else  // !QT_MOC_HAS_STRINGDATA
#error "qtmochelpers.h not found or too old."
#endif // !QT_MOC_HAS_STRINGDATA

Q_CONSTINIT static const uint qt_meta_data_ZN11PdfDocumentE[] = {

 // content:
      12,       // revision
       0,       // classname
       0,    0, // classinfo
      12,   14, // methods
       7,  108, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
       9,       // signalCount

 // signals: name, argc, parameters, tag, flags, initial metatype offsets
       1,    0,   86,    2, 0x06,    8 /* Public */,
       3,    1,   87,    2, 0x06,    9 /* Public */,
       5,    0,   90,    2, 0x06,   11 /* Public */,
       6,    0,   91,    2, 0x06,   12 /* Public */,
       7,    0,   92,    2, 0x06,   13 /* Public */,
       8,    0,   93,    2, 0x06,   14 /* Public */,
       9,    0,   94,    2, 0x06,   15 /* Public */,
      10,    0,   95,    2, 0x06,   16 /* Public */,
      11,    0,   96,    2, 0x06,   17 /* Public */,

 // slots: name, argc, parameters, tag, flags, initial metatype offsets
      12,    1,   97,    2, 0x0a,   18 /* Public */,
      14,    3,  100,    2, 0x0a,   20 /* Public */,
      17,    0,  107,    2, 0x0a,   24 /* Public */,

 // signals: parameters
    QMetaType::Void,
    QMetaType::Void, QMetaType::QString,    4,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,

 // slots: parameters
    QMetaType::Bool, QMetaType::QString,   13,
    QMetaType::Bool, QMetaType::QString, QMetaType::QString, QMetaType::QString,   13,   15,   16,
    QMetaType::Void,

 // properties: name, type, flags, notifyId, revision
      18, QMetaType::QString, 0x00015001, uint(2), 0,
      19, QMetaType::QString, 0x00015001, uint(3), 0,
      20, QMetaType::QStringList, 0x00015001, uint(4), 0,
      21, QMetaType::Int, 0x00015001, uint(5), 0,
      22, QMetaType::QString, 0x00015001, uint(6), 0,
      23, QMetaType::Bool, 0x00015001, uint(7), 0,
      24, QMetaType::QString, 0x00015001, uint(8), 0,

       0        // eod
};

Q_CONSTINIT const QMetaObject PdfDocument::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_meta_stringdata_ZN11PdfDocumentE.offsetsAndSizes,
    qt_meta_data_ZN11PdfDocumentE,
    qt_static_metacall,
    nullptr,
    qt_incomplete_metaTypeArray<qt_meta_tag_ZN11PdfDocumentE_t,
        // property 'filePath'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'previewSource'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'pageSources'
        QtPrivate::TypeAndForceComplete<QStringList, std::true_type>,
        // property 'pageCount'
        QtPrivate::TypeAndForceComplete<int, std::true_type>,
        // property 'title'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'isLoaded'
        QtPrivate::TypeAndForceComplete<bool, std::true_type>,
        // property 'errorMessage'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // Q_OBJECT / Q_GADGET
        QtPrivate::TypeAndForceComplete<PdfDocument, std::true_type>,
        // method 'loaded'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'loadFailed'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'filePathChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'previewSourceChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'pageSourcesChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'pageCountChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'titleChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'isLoadedChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'errorMessageChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'load'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'saveRotatedCopy'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'clear'
        QtPrivate::TypeAndForceComplete<void, std::false_type>
    >,
    nullptr
} };

void PdfDocument::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<PdfDocument *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->loaded(); break;
        case 1: _t->loadFailed((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 2: _t->filePathChanged(); break;
        case 3: _t->previewSourceChanged(); break;
        case 4: _t->pageSourcesChanged(); break;
        case 5: _t->pageCountChanged(); break;
        case 6: _t->titleChanged(); break;
        case 7: _t->isLoadedChanged(); break;
        case 8: _t->errorMessageChanged(); break;
        case 9: { bool _r = _t->load((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 10: { bool _r = _t->saveRotatedCopy((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 11: _t->clear(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        int *result = reinterpret_cast<int *>(_a[0]);
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::loaded; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 0;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)(const QString & );
            if (_q_method_type _q_method = &PdfDocument::loadFailed; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 1;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::filePathChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 2;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::previewSourceChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 3;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::pageSourcesChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 4;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::pageCountChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 5;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::titleChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 6;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::isLoadedChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 7;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::errorMessageChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 8;
                return;
            }
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast< QString*>(_v) = _t->filePath(); break;
        case 1: *reinterpret_cast< QString*>(_v) = _t->previewSource(); break;
        case 2: *reinterpret_cast< QStringList*>(_v) = _t->pageSources(); break;
        case 3: *reinterpret_cast< int*>(_v) = _t->pageCount(); break;
        case 4: *reinterpret_cast< QString*>(_v) = _t->title(); break;
        case 5: *reinterpret_cast< bool*>(_v) = _t->isLoaded(); break;
        case 6: *reinterpret_cast< QString*>(_v) = _t->errorMessage(); break;
        default: break;
        }
    }
}

const QMetaObject *PdfDocument::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *PdfDocument::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_meta_stringdata_ZN11PdfDocumentE.stringdata0))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int PdfDocument::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 12)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 12;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 12)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 12;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 7;
    }
    return _id;
}

// SIGNAL 0
void PdfDocument::loaded()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void PdfDocument::loadFailed(const QString & _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}

// SIGNAL 2
void PdfDocument::filePathChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void PdfDocument::previewSourceChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void PdfDocument::pageSourcesChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void PdfDocument::pageCountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void PdfDocument::titleChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void PdfDocument::isLoadedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void PdfDocument::errorMessageChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}
QT_WARNING_POP
