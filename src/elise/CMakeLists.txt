cmake_minimum_required(VERSION 3.16)
project(elise VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Svg Network Multimedia Location Positioning Sql)

find_package(PkgConfig REQUIRED)
pkg_check_modules(SDBUS_CPP REQUIRED IMPORTED_TARGET sdbus-c++)
pkg_check_modules(MPV      REQUIRED IMPORTED_TARGET mpv)

# HermesIpc is optional in dev (host build without buildroot may not have it).
# When available, we use it to generate proxy stubs from canonical XML; when
# not, the controllers fall back to string-based dispatch on raw IProxy.
find_package(HermesIpc QUIET)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(elise
    main.cpp
    core/SystemController.h
    core/SystemController.cpp
    core/PlayerController.h
    core/PlayerController.cpp
    core/NavigationController.h
    core/NavigationController.cpp
    core/settings/SettingsController.h
    core/settings/SettingsController.cpp
    core/settings/SystemInfoController.h
    core/settings/SystemInfoController.cpp
    core/settings/NetworkController.h
    core/settings/NetworkController.cpp
    core/settings/BluetoothController.h
    core/settings/BluetoothController.cpp
    core/settings/AppearanceController.h
    core/settings/AppearanceController.cpp
    core/settings/AudioController.h
    core/settings/AudioController.cpp
    core/settings/OfflineMapsController.h
    core/settings/OfflineMapsController.cpp
    core/GpsController.h
    core/GpsController.cpp
    core/RoadInfoController.h
    core/RoadInfoController.cpp
)

set_source_files_properties(ui/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)
set_source_files_properties(ui/Keyboard.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)
set_source_files_properties(ui/ActionSheet.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)
set_source_files_properties(ui/MapBridge.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(elise
    URI Elise
    VERSION 1.0
    QML_FILES
        ui/Main.qml
        ui/CarMap.qml
        ui/MapSearchBar.qml
        ui/PlayerCard.qml
        ui/NavigationOverlay.qml
        ui/NotificationLayer.qml
        ui/GlobalInputBlocker.qml
        ui/SvgIcon.qml
        ui/Theme.qml
        ui/Fab.qml
        ui/Menu.qml
        ui/SettingsMenu.qml
        ui/SettingsSidebarItem.qml
        ui/SettingsSidebarHeader.qml
        ui/SettingsCard.qml
        ui/SettingsRow.qml
        ui/SettingsAction.qml
        ui/SettingsToggle.qml
        ui/SettingsPagePerfil.qml
        ui/SettingsPageContas.qml
        ui/SettingsPageVeiculo.qml
        ui/SettingsPageConectividade.qml
        ui/SettingsPageWifiList.qml
        ui/SettingsPageBluetooth.qml
        ui/SettingsPageBluetoothList.qml
        ui/SoftKeyboard.qml
        ui/KeyboardKey.qml
        ui/Keyboard.qml
        ui/ActionSheet.qml
        ui/MapBridge.qml
        ui/SettingsPageMapasOffline.qml
        ui/CompassRose.qml
        ui/ActionSheetView.qml
        ui/TrackList.qml
        ui/TrackCarousel.qml
        ui/SettingsPageInterface.qml
        ui/SettingsPageSom.qml
        ui/SettingsSlider.qml
        ui/SettingsPageSistema.qml
        ui/SignalBars.qml
)

qt_add_resources(elise "elise_icons"
    PREFIX "/icons"
    BASE "icons"
    FILES
        icons/play.svg
        icons/pause.svg
        icons/skip-back.svg
        icons/skip-forward.svg
        icons/search.svg
        icons/bluetooth.svg
        icons/usb.svg
        icons/radio.svg
        icons/chevron-up.svg
        icons/chevron-down.svg
        icons/close.svg
        icons/arrow-straight.svg
        icons/arrow-left.svg
        icons/arrow-right.svg
        icons/music-note.svg
        icons/heart.svg
        icons/refresh.svg
        icons/download.svg
        icons/settings.svg
        icons/user.svg
        icons/accounts.svg
        icons/car.svg
        icons/wifi.svg
        icons/monitor.svg
        icons/volume.svg
        icons/info.svg
        icons/chevron-right.svg
        icons/backspace.svg
        icons/mic.svg
        icons/eye.svg
        icons/eye-off.svg
        icons/lock.svg
        icons/speed-camera.svg
        icons/fuel.svg
        icons/charging.svg
        icons/food.svg
        icons/hospital.svg
        icons/pharmacy.svg
        icons/place.svg
        icons/shopping.svg
        icons/supermarket.svg
        icons/bank.svg
        icons/lodging.svg
        icons/phone.svg
        icons/globe.svg
        icons/star.svg
        icons/clock.svg
)

target_link_libraries(elise PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Svg
    Qt6::Network
    Qt6::Multimedia
    Qt6::Location
    Qt6::Positioning
    Qt6::Sql
    PkgConfig::SDBUS_CPP
    PkgConfig::MPV
)

# Generate the org.hermes.System1 client proxy from the canonical XML.
# Only wired when hermes-ipc is available (Buildroot installs it; pure host
# dev builds without the package skip codegen and rely on the runtime
# string-based proxy in SystemInfoController).
if (HermesIpc_FOUND)
    hermes_ipc_generate(
        TARGET    elise
        INTERFACE org.hermes.System1
        PROXY
    )
endif()

install(TARGETS elise DESTINATION /usr/bin)
