import QtQuick
import Elise

// Settings root surface — Caelestia-style: a search field over a scrollable
// list of icon cards on the left, the active page on the right.
//
// Internal router: `activePage` (string) drives the Loader. Pages are
// SettingsPage* QML files registered as Components.
Menu {
    id: root

    property string activePage: "interface"
    property string _query: ""

    // Sections grouped into blocks (each block is a contiguous grouped-rounded
    // list; blocks are separated by a gap). Single source of truth for the
    // sidebar layout + the search filter + the page header label.
    readonly property var _groups: [
        [ { key: "interface",     icon: "qrc:/icons/monitor.svg",   label: "Aparência",     sub: "Tema, mapa, layout" } ],
        [ { key: "conectividade", icon: "qrc:/icons/wifi.svg",      label: "Conectividade", sub: "Wi-Fi, ethernet" },
          { key: "bluetooth",     icon: "qrc:/icons/devices.svg",   label: "Connected devices", sub: "Bluetooth, pareamento" },
          { key: "som",           icon: "qrc:/icons/volume.svg",    label: "Áudio",         sub: "Volume, equalizador" } ],
        [ { key: "mapasOffline",  icon: "qrc:/icons/download.svg",  label: "Mapas offline", sub: "Download de regiões" },
          { key: "veiculo",       icon: "qrc:/icons/car.svg",       label: "Veículo",       sub: "Preferências do carro" } ],
        [ { key: "perfil",        icon: "qrc:/icons/user.svg",      label: "Perfil",        sub: "Conta, foto" },
          { key: "contas",        icon: "qrc:/icons/accounts.svg",  label: "Contas",        sub: "Serviços, login" },
          { key: "sistema",       icon: "qrc:/icons/info.svg",      label: "About",         sub: "Informações, créditos" } ]
    ]
    function _label(key) {
        for (let g = 0; g < _groups.length; ++g)
            for (let i = 0; i < _groups[g].length; ++i)
                if (_groups[g][i].key === key) return _groups[g][i].label
        return ""
    }
    function _matches(s) {
        if (_query === "") return true
        const q = _query.toLowerCase()
        return s.label.toLowerCase().indexOf(q) >= 0
            || s.sub.toLowerCase().indexOf(q) >= 0
    }

    readonly property bool _searching:
        Keyboard.active && Keyboard.title === "Buscar configuração"

    // ── Sidebar ──────────────────────────────────────────────────────────────
    Item {
        id: _sidebar
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left
                  topMargin: Theme.spaceXXL; bottomMargin: Theme.spaceL
                  leftMargin: Theme.spaceL }
        width: Theme.settingsSidebarW

        // Search field
        Rectangle {
            id: _search
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: Theme.btnLarge
            radius: Theme.radiusL
            color: System.surface2
            border.color: root._searching ? System.accent : System.border
            border.width: 1

            SvgIcon {
                id: _searchIcon
                anchors { left: parent.left; leftMargin: Theme.spaceL
                          verticalCenter: parent.verticalCenter }
                source: "qrc:/icons/search.svg"; color: System.textMuted; size: Theme.iconS
            }
            Text {
                anchors { left: _searchIcon.right; leftMargin: Theme.spaceM
                          right: _clearS.left; rightMargin: Theme.spaceS
                          verticalCenter: parent.verticalCenter }
                text: root._query !== "" ? root._query : "Buscar configuração"
                color: root._query !== "" ? System.textPrimary : System.textMuted
                font.pixelSize: Theme.fontMedium
                elide: Text.ElideRight
            }
            Rectangle {
                id: _clearS
                anchors { right: parent.right; rightMargin: Theme.spaceS
                          verticalCenter: parent.verticalCenter }
                visible: root._query !== ""
                width: Theme.btnSmall; height: Theme.btnSmall; radius: width / 2
                color: _csArea.pressed ? System.pressOverlay : "transparent"
                SvgIcon { anchors.centerIn: parent; source: "qrc:/icons/close.svg"
                          color: System.textSecondary; size: Theme.iconXS }
                MouseArea { id: _csArea; anchors.fill: parent
                            onClicked: root._query = "" }
            }
            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: _clearS.visible ? Theme.btnSmall + Theme.spaceS * 2 : 0
                onClicked: Keyboard.show({
                    title: "Buscar configuração", bare: false, initial: root._query,
                    onSubmit: function(t) { root._query = t }
                })
            }
            Connections {
                target: Keyboard
                function onBufferChanged() { if (root._searching) root._query = Keyboard.buffer }
            }
        }

        // Scrollable card list
        Flickable {
            anchors { top: _search.bottom; topMargin: Theme.spaceM
                      left: parent.left; right: parent.right; bottom: parent.bottom
                      rightMargin: Theme.spaceS }
            contentHeight: _list.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: _list
                width: parent.width
                spacing: Theme.spaceL          // gap BETWEEN blocks

                Repeater {
                    model: root._groups
                    delegate: Column {
                        required property var modelData       // a group (array)
                        width: _list.width
                        spacing: 2                            // tight WITHIN a block

                        Repeater {
                            model: parent.modelData
                            SettingsSidebarItem {
                                required property var modelData
                                required property int index
                                readonly property int _n: parent.modelData.length
                                visible:  root._matches(modelData)
                                height:   visible ? 64 : 0
                                icon:     modelData.icon
                                label:    modelData.label
                                sublabel: modelData.sub
                                active:   root.activePage === modelData.key
                                first:    index === 0
                                last:     index === _n - 1
                                onClicked: { root.activePage = modelData.key
                                             if (Keyboard.active) Keyboard.dismiss() }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Right pane: header + active page ──────────────────────────────────────
    function _activeLabel() { return _label(activePage) }

    Item {
        id: _rightPane
        anchors { top: parent.top; bottom: parent.bottom
                  left: _sidebar.right; right: parent.right
                  leftMargin: Theme.spaceXL; topMargin: Theme.spaceXXL
                  rightMargin: Theme.spaceXXL; bottomMargin: Theme.spaceL }

        // Back arrow — shown only when the active page exposes a sub-view
        // (page.canGoBack). Drives page.goBack().
        Rectangle {
            id: _backBtn
            anchors { verticalCenter: _pageTitle.verticalCenter; left: parent.left }
            width: Theme.btnMedium; height: Theme.btnMedium; radius: width / 2
            visible: _pageLoader.item && _pageLoader.item.canGoBack === true
            color: _backArea.pressed ? System.surface2 : "transparent"
            SvgIcon { anchors.centerIn: parent; source: "qrc:/icons/chevron-left.svg"
                      color: System.textPrimary; size: Theme.iconM }
            MouseArea { id: _backArea; anchors.fill: parent
                        onClicked: if (_pageLoader.item) _pageLoader.item.goBack() }
        }

        Text {
            id: _pageTitle
            anchors { top: parent.top
                      left: _backBtn.visible ? _backBtn.right : parent.left
                      leftMargin: _backBtn.visible ? Theme.spaceM : 0
                      right: _closeSpacer.left }
            // Page may override the header title for its sub-views (navTitle);
            // otherwise the section label is used.
            text: (_pageLoader.item && _pageLoader.item.navTitle)
                    ? _pageLoader.item.navTitle : root._activeLabel()
            color: System.textPrimary
            font.pixelSize: Theme.fontTitle + 8
            font.weight: Font.Bold
            elide: Text.ElideRight
        }
        Item { id: _closeSpacer; anchors.right: parent.right; width: Theme.btnMedium; height: 1 }

        Loader {
            id: _pageLoader
            anchors { top: _pageTitle.bottom; topMargin: Theme.spaceL
                      left: parent.left; right: parent.right; bottom: parent.bottom }
            sourceComponent: _pageFor(root.activePage)
        }
    }

    // ── Close button ──────────────────────────────────────────────────────────
    Rectangle {
        anchors { top: parent.top; right: parent.right
                  topMargin: Theme.spaceL; rightMargin: Theme.spaceL }
        width: Theme.btnMedium; height: Theme.btnMedium; radius: width / 2
        z: 20
        color: _closeArea.pressed ? System.surface2 : "transparent"
        SvgIcon { anchors.centerIn: parent; source: "qrc:/icons/close.svg"
                  color: System.textSecondary; size: Theme.iconM }
        MouseArea { id: _closeArea; anchors.fill: parent; onClicked: root.close() }
    }

    // ── Internal router ──────────────────────────────────────────────────────
    function _pageFor(name) {
        switch (name) {
            case "perfil":         return _perfilPage
            case "contas":         return _contasPage
            case "veiculo":        return _veiculoPage
            case "conectividade":  return _conectividadePage
            case "bluetooth":      return _bluetoothPage
            case "mapasOffline":   return _mapasOfflinePage
            case "interface":      return _interfacePage
            case "som":            return _somPage
            case "sistema":        return _sistemaPage
            default:               return _interfacePage
        }
    }

    Component { id: _perfilPage;        SettingsPagePerfil        {} }
    Component { id: _contasPage;        SettingsPageContas        {} }
    Component { id: _veiculoPage;       SettingsPageVeiculo       {} }
    Component { id: _conectividadePage; SettingsPageConectividade {} }
    Component { id: _bluetoothPage;     SettingsPageBluetooth     {} }
    Component { id: _mapasOfflinePage;  SettingsPageMapasOffline  {} }
    Component { id: _interfacePage;     SettingsPageInterface     {} }
    Component { id: _somPage;           SettingsPageSom           {} }
    Component { id: _sistemaPage;       SettingsPageSistema       {} }
}
