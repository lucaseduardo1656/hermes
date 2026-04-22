/****************************************************************************
** Meta object code from reading C++ file 'NetworkBackend.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../NetworkBackend.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'NetworkBackend.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.0. It"
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
struct qt_meta_tag_ZN14NetworkBackendE_t {};
} // unnamed namespace

template <> constexpr inline auto NetworkBackend::qt_create_metaobjectdata<qt_meta_tag_ZN14NetworkBackendE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "NetworkBackend",
        "wifiChanged",
        "",
        "wifiScanningChanged",
        "wifiNetworksChanged",
        "wifiConnectError",
        "reason",
        "btChanged",
        "setWifiEnabled",
        "enabled",
        "wifiScan",
        "wifiConnect",
        "ssid",
        "password",
        "wifiDisconnect",
        "setBtEnabled",
        "btRefreshPaired",
        "pollWifi",
        "pollBt",
        "wifiEnabled",
        "wifiConnected",
        "wifiSsid",
        "wifiIp",
        "wifiSignal",
        "wifiScanning",
        "wifiNetworks",
        "QVariantList",
        "btEnabled",
        "btName",
        "btPaired"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'wifiChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'wifiScanningChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'wifiNetworksChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'wifiConnectError'
        QtMocHelpers::SignalData<void(const QString &)>(5, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 6 },
        }}),
        // Signal 'btChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'setWifiEnabled'
        QtMocHelpers::SlotData<void(bool)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 9 },
        }}),
        // Slot 'wifiScan'
        QtMocHelpers::SlotData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'wifiConnect'
        QtMocHelpers::SlotData<void(const QString &, const QString &)>(11, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 12 }, { QMetaType::QString, 13 },
        }}),
        // Slot 'wifiDisconnect'
        QtMocHelpers::SlotData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'setBtEnabled'
        QtMocHelpers::SlotData<void(bool)>(15, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 9 },
        }}),
        // Slot 'btRefreshPaired'
        QtMocHelpers::SlotData<void()>(16, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'pollWifi'
        QtMocHelpers::SlotData<void()>(17, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'pollBt'
        QtMocHelpers::SlotData<void()>(18, 2, QMC::AccessPrivate, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'wifiEnabled'
        QtMocHelpers::PropertyData<bool>(19, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'wifiConnected'
        QtMocHelpers::PropertyData<bool>(20, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'wifiSsid'
        QtMocHelpers::PropertyData<QString>(21, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'wifiIp'
        QtMocHelpers::PropertyData<QString>(22, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'wifiSignal'
        QtMocHelpers::PropertyData<int>(23, QMetaType::Int, QMC::DefaultPropertyFlags, 0),
        // property 'wifiScanning'
        QtMocHelpers::PropertyData<bool>(24, QMetaType::Bool, QMC::DefaultPropertyFlags, 1),
        // property 'wifiNetworks'
        QtMocHelpers::PropertyData<QVariantList>(25, 0x80000000 | 26, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 2),
        // property 'btEnabled'
        QtMocHelpers::PropertyData<bool>(27, QMetaType::Bool, QMC::DefaultPropertyFlags, 4),
        // property 'btName'
        QtMocHelpers::PropertyData<QString>(28, QMetaType::QString, QMC::DefaultPropertyFlags, 4),
        // property 'btPaired'
        QtMocHelpers::PropertyData<QVariantList>(29, 0x80000000 | 26, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 4),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<NetworkBackend, qt_meta_tag_ZN14NetworkBackendE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject NetworkBackend::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14NetworkBackendE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14NetworkBackendE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN14NetworkBackendE_t>.metaTypes,
    nullptr
} };

void NetworkBackend::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<NetworkBackend *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->wifiChanged(); break;
        case 1: _t->wifiScanningChanged(); break;
        case 2: _t->wifiNetworksChanged(); break;
        case 3: _t->wifiConnectError((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 4: _t->btChanged(); break;
        case 5: _t->setWifiEnabled((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1]))); break;
        case 6: _t->wifiScan(); break;
        case 7: _t->wifiConnect((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 8: _t->wifiDisconnect(); break;
        case 9: _t->setBtEnabled((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1]))); break;
        case 10: _t->btRefreshPaired(); break;
        case 11: _t->pollWifi(); break;
        case 12: _t->pollBt(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (NetworkBackend::*)()>(_a, &NetworkBackend::wifiChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (NetworkBackend::*)()>(_a, &NetworkBackend::wifiScanningChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (NetworkBackend::*)()>(_a, &NetworkBackend::wifiNetworksChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (NetworkBackend::*)(const QString & )>(_a, &NetworkBackend::wifiConnectError, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (NetworkBackend::*)()>(_a, &NetworkBackend::btChanged, 4))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->wifiEnabled(); break;
        case 1: *reinterpret_cast<bool*>(_v) = _t->wifiConnected(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->wifiSsid(); break;
        case 3: *reinterpret_cast<QString*>(_v) = _t->wifiIp(); break;
        case 4: *reinterpret_cast<int*>(_v) = _t->wifiSignal(); break;
        case 5: *reinterpret_cast<bool*>(_v) = _t->wifiScanning(); break;
        case 6: *reinterpret_cast<QVariantList*>(_v) = _t->wifiNetworks(); break;
        case 7: *reinterpret_cast<bool*>(_v) = _t->btEnabled(); break;
        case 8: *reinterpret_cast<QString*>(_v) = _t->btName(); break;
        case 9: *reinterpret_cast<QVariantList*>(_v) = _t->btPaired(); break;
        default: break;
        }
    }
}

const QMetaObject *NetworkBackend::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *NetworkBackend::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14NetworkBackendE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int NetworkBackend::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 13)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 13;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 13)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 13;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 10;
    }
    return _id;
}

// SIGNAL 0
void NetworkBackend::wifiChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void NetworkBackend::wifiScanningChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void NetworkBackend::wifiNetworksChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void NetworkBackend::wifiConnectError(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 3, nullptr, _t1);
}

// SIGNAL 4
void NetworkBackend::btChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}
QT_WARNING_POP
