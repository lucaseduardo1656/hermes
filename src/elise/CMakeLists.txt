cmake_minimum_required(VERSION 3.16)
project(elise VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Svg Network Multimedia)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(elise
    main.cpp
    core/SystemController.h
    core/SystemController.cpp
    core/PlayerController.h
    core/PlayerController.cpp
    core/NavigationController.h
    core/NavigationController.cpp
)

set_source_files_properties(ui/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(elise
    URI Elise
    VERSION 1.0
    QML_FILES
        ui/Main.qml
        ui/MapView.qml
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
        ui/SettingsPageInterface.qml
        ui/SettingsPageSom.qml
        ui/SettingsPageSistema.qml
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
)

target_link_libraries(elise PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Svg
    Qt6::Network
    Qt6::Multimedia
)

install(TARGETS elise DESTINATION /usr/bin)
