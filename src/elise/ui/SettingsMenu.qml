import QtQuick
import Elise

// Settings root surface.
//
// Layout:
//   ┌──────────────────────────┬──────────────────────────────────────┐
//   │ [pill]                   │                                      │
//   │ ┌──┐ Convidado ▼     📶 │                                      │
//   │ ├──────────────────────┤ │                                      │
//   │ - Perfil                 │   <active page>                      │
//   │ - Contas                 │                                      │
//   │ - Veículo                │                                      │
//   │ - Conectividade          │                                      │
//   │ - Interface              │                                      │
//   │ - Som                    │                                      │
//   │ - Sistema                │                                      │
//   └──────────────────────────┴──────────────────────────────────────┘
//
// The sidebar hosts the user/connectivity summary directly above the menu
// list. The right pane is a clean Loader for the active page.
//
// Internal router: `activePage` (string) drives the Loader. Pages are
// SettingsPage* QML files registered as Components.
Menu {
    id: root

    // Internal navigation state (router).
    property string activePage: "perfil"

    // ── Sidebar ──────────────────────────────────────────────────────────────
    Rectangle {
        id: _sidebar
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: Theme.settingsSidebarW
        color: System.surface

        // Right-edge hairline divider
        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: Theme.borderHairline
            color: System.border
        }

        // User + connectivity strip (just below the drag pill area)
        SettingsSidebarHeader {
            id: _sidebarHeader
            anchors {
                top: parent.top; topMargin: Theme.spaceXXL
                left: parent.left; right: parent.right
            }
            // TODO: bind userName to ProfileController when ready
            userName:   "Convidado"
            connOnline: Settings.network.online
            onProfileMenuRequested: {
                // TODO: open profile picker
            }
        }

        // Menu list
        Column {
            anchors {
                top: _sidebarHeader.bottom; topMargin: Theme.spaceM
                left: parent.left; right: parent.right
            }
            spacing: 2

            SettingsSidebarItem {
                icon: "qrc:/icons/user.svg";        label: "Perfil"
                active: root.activePage === "perfil"
                onClicked: root.activePage = "perfil"
            }
            SettingsSidebarItem {
                icon: "qrc:/icons/accounts.svg";    label: "Contas"
                active: root.activePage === "contas"
                onClicked: root.activePage = "contas"
            }
            SettingsSidebarItem {
                icon: "qrc:/icons/car.svg";         label: "Veículo"
                active: root.activePage === "veiculo"
                onClicked: root.activePage = "veiculo"
            }
            SettingsSidebarItem {
                icon: "qrc:/icons/wifi.svg";        label: "Conectividade"
                active: root.activePage === "conectividade"
                onClicked: root.activePage = "conectividade"
            }
            SettingsSidebarItem {
                icon: "qrc:/icons/bluetooth.svg";   label: "Bluetooth"
                active: root.activePage === "bluetooth"
                onClicked: root.activePage = "bluetooth"
            }
            SettingsSidebarItem {
                icon: "qrc:/icons/monitor.svg";     label: "Interface"
                active: root.activePage === "interface"
                onClicked: root.activePage = "interface"
            }
            SettingsSidebarItem {
                icon: "qrc:/icons/volume.svg";      label: "Som"
                active: root.activePage === "som"
                onClicked: root.activePage = "som"
            }
            SettingsSidebarItem {
                icon: "qrc:/icons/info.svg";        label: "Sistema"
                active: root.activePage === "sistema"
                onClicked: root.activePage = "sistema"
            }
        }
    }

    // ── Right pane: active page ──────────────────────────────────────────────
    Loader {
        anchors { top: parent.top; bottom: parent.bottom
                  left: _sidebar.right; right: parent.right }
        sourceComponent: _pageFor(root.activePage)
    }

    // ── Internal router ──────────────────────────────────────────────────────
    function _pageFor(name) {
        switch (name) {
            case "perfil":         return _perfilPage
            case "contas":         return _contasPage
            case "veiculo":        return _veiculoPage
            case "conectividade":  return _conectividadePage
            case "bluetooth":      return _bluetoothPage
            case "interface":      return _interfacePage
            case "som":            return _somPage
            case "sistema":        return _sistemaPage
            default:               return _perfilPage
        }
    }

    Component { id: _perfilPage;        SettingsPagePerfil        {} }
    Component { id: _contasPage;        SettingsPageContas        {} }
    Component { id: _veiculoPage;       SettingsPageVeiculo       {} }
    Component { id: _conectividadePage; SettingsPageConectividade {} }
    Component { id: _bluetoothPage;     SettingsPageBluetooth     {} }
    Component { id: _interfacePage;     SettingsPageInterface     {} }
    Component { id: _somPage;           SettingsPageSom           {} }
    Component { id: _sistemaPage;       SettingsPageSistema       {} }
}
