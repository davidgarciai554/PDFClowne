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
    "thumbnailSourcesChanged",
    "pageSizesJsonChanged",
    "outlineJsonChanged",
    "pageLinksJsonChanged",
    "pageCountChanged",
    "fileSizeBytesChanged",
    "titleChanged",
    "isLoadedChanged",
    "errorMessageChanged",
    "load",
    "source",
    "renderPage",
    "pageIndex",
    "scale",
    "renderThumbnail",
    "searchPage",
    "query",
    "searchDocument",
    "extractPageText",
    "extractDocumentText",
    "resolveLinkPage",
    "uri",
    "saveRotatedCopy",
    "target",
    "rotationsJson",
    "clear",
    "filePath",
    "previewSource",
    "pageSources",
    "thumbnailSources",
    "pageSizesJson",
    "outlineJson",
    "pageLinksJson",
    "pageCount",
    "fileSizeBytes",
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
      25,   14, // methods
      12,  217, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
      14,       // signalCount

 // signals: name, argc, parameters, tag, flags, initial metatype offsets
       1,    0,  164,    2, 0x06,   13 /* Public */,
       3,    1,  165,    2, 0x06,   14 /* Public */,
       5,    0,  168,    2, 0x06,   16 /* Public */,
       6,    0,  169,    2, 0x06,   17 /* Public */,
       7,    0,  170,    2, 0x06,   18 /* Public */,
       8,    0,  171,    2, 0x06,   19 /* Public */,
       9,    0,  172,    2, 0x06,   20 /* Public */,
      10,    0,  173,    2, 0x06,   21 /* Public */,
      11,    0,  174,    2, 0x06,   22 /* Public */,
      12,    0,  175,    2, 0x06,   23 /* Public */,
      13,    0,  176,    2, 0x06,   24 /* Public */,
      14,    0,  177,    2, 0x06,   25 /* Public */,
      15,    0,  178,    2, 0x06,   26 /* Public */,
      16,    0,  179,    2, 0x06,   27 /* Public */,

 // slots: name, argc, parameters, tag, flags, initial metatype offsets
      17,    1,  180,    2, 0x0a,   28 /* Public */,
      19,    2,  183,    2, 0x0a,   30 /* Public */,
      19,    1,  188,    2, 0x2a,   33 /* Public | MethodCloned */,
      22,    1,  191,    2, 0x0a,   35 /* Public */,
      23,    2,  194,    2, 0x0a,   37 /* Public */,
      25,    1,  199,    2, 0x0a,   40 /* Public */,
      26,    1,  202,    2, 0x0a,   42 /* Public */,
      27,    0,  205,    2, 0x0a,   44 /* Public */,
      28,    1,  206,    2, 0x0a,   45 /* Public */,
      30,    3,  209,    2, 0x0a,   47 /* Public */,
      33,    0,  216,    2, 0x0a,   51 /* Public */,

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
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,

 // slots: parameters
    QMetaType::Bool, QMetaType::QString,   18,
    QMetaType::QString, QMetaType::Int, QMetaType::QReal,   20,   21,
    QMetaType::QString, QMetaType::Int,   20,
    QMetaType::QString, QMetaType::Int,   20,
    QMetaType::QString, QMetaType::Int, QMetaType::QString,   20,   24,
    QMetaType::QString, QMetaType::QString,   24,
    QMetaType::QString, QMetaType::Int,   20,
    QMetaType::QString,
    QMetaType::Int, QMetaType::QString,   29,
    QMetaType::Bool, QMetaType::QString, QMetaType::QString, QMetaType::QString,   18,   31,   32,
    QMetaType::Void,

 // properties: name, type, flags, notifyId, revision
      34, QMetaType::QString, 0x00015001, uint(2), 0,
      35, QMetaType::QString, 0x00015001, uint(3), 0,
      36, QMetaType::QStringList, 0x00015001, uint(4), 0,
      37, QMetaType::QStringList, 0x00015001, uint(5), 0,
      38, QMetaType::QString, 0x00015001, uint(6), 0,
      39, QMetaType::QString, 0x00015001, uint(7), 0,
      40, QMetaType::QString, 0x00015001, uint(8), 0,
      41, QMetaType::Int, 0x00015001, uint(9), 0,
      42, QMetaType::LongLong, 0x00015001, uint(10), 0,
      43, QMetaType::QString, 0x00015001, uint(11), 0,
      44, QMetaType::Bool, 0x00015001, uint(12), 0,
      45, QMetaType::QString, 0x00015001, uint(13), 0,

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
        // property 'thumbnailSources'
        QtPrivate::TypeAndForceComplete<QStringList, std::true_type>,
        // property 'pageSizesJson'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'outlineJson'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'pageLinksJson'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'pageCount'
        QtPrivate::TypeAndForceComplete<int, std::true_type>,
        // property 'fileSizeBytes'
        QtPrivate::TypeAndForceComplete<qint64, std::true_type>,
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
        // method 'thumbnailSourcesChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'pageSizesJsonChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'outlineJsonChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'pageLinksJsonChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'pageCountChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'fileSizeBytesChanged'
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
        // method 'renderPage'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<qreal, std::false_type>,
        // method 'renderPage'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'renderThumbnail'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'searchPage'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'searchDocument'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'extractPageText'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'extractDocumentText'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        // method 'resolveLinkPage'
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
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
        case 5: _t->thumbnailSourcesChanged(); break;
        case 6: _t->pageSizesJsonChanged(); break;
        case 7: _t->outlineJsonChanged(); break;
        case 8: _t->pageLinksJsonChanged(); break;
        case 9: _t->pageCountChanged(); break;
        case 10: _t->fileSizeBytesChanged(); break;
        case 11: _t->titleChanged(); break;
        case 12: _t->isLoadedChanged(); break;
        case 13: _t->errorMessageChanged(); break;
        case 14: { bool _r = _t->load((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 15: { QString _r = _t->renderPage((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<qreal>>(_a[2])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 16: { QString _r = _t->renderPage((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 17: { QString _r = _t->renderThumbnail((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 18: { QString _r = _t->searchPage((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 19: { QString _r = _t->searchDocument((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 20: { QString _r = _t->extractPageText((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 21: { QString _r = _t->extractDocumentText();
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 22: { int _r = _t->resolveLinkPage((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< int*>(_a[0]) = std::move(_r); }  break;
        case 23: { bool _r = _t->saveRotatedCopy((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 24: _t->clear(); break;
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
            if (_q_method_type _q_method = &PdfDocument::thumbnailSourcesChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 5;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::pageSizesJsonChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 6;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::outlineJsonChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 7;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::pageLinksJsonChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 8;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::pageCountChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 9;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::fileSizeBytesChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 10;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::titleChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 11;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::isLoadedChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 12;
                return;
            }
        }
        {
            using _q_method_type = void (PdfDocument::*)();
            if (_q_method_type _q_method = &PdfDocument::errorMessageChanged; *reinterpret_cast<_q_method_type *>(_a[1]) == _q_method) {
                *result = 13;
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
        case 3: *reinterpret_cast< QStringList*>(_v) = _t->thumbnailSources(); break;
        case 4: *reinterpret_cast< QString*>(_v) = _t->pageSizesJson(); break;
        case 5: *reinterpret_cast< QString*>(_v) = _t->outlineJson(); break;
        case 6: *reinterpret_cast< QString*>(_v) = _t->pageLinksJson(); break;
        case 7: *reinterpret_cast< int*>(_v) = _t->pageCount(); break;
        case 8: *reinterpret_cast< qint64*>(_v) = _t->fileSizeBytes(); break;
        case 9: *reinterpret_cast< QString*>(_v) = _t->title(); break;
        case 10: *reinterpret_cast< bool*>(_v) = _t->isLoaded(); break;
        case 11: *reinterpret_cast< QString*>(_v) = _t->errorMessage(); break;
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
        if (_id < 25)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 25;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 25)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 25;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 12;
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
void PdfDocument::thumbnailSourcesChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void PdfDocument::pageSizesJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void PdfDocument::outlineJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void PdfDocument::pageLinksJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}

// SIGNAL 9
void PdfDocument::pageCountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}

// SIGNAL 10
void PdfDocument::fileSizeBytesChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 10, nullptr);
}

// SIGNAL 11
void PdfDocument::titleChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 11, nullptr);
}

// SIGNAL 12
void PdfDocument::isLoadedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 12, nullptr);
}

// SIGNAL 13
void PdfDocument::errorMessageChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 13, nullptr);
}
QT_WARNING_POP
