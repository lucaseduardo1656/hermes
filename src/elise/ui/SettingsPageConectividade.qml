import QtQuick
import Elise

// Page: Conectividade — Wi-Fi (top-level), Bluetooth (TODO), Hotspot (TODO).
//
// Two-state internal router:
//   * "main"  — overview card with toggle + Conectado info + Redes link
//   * "list"  — full list of available networks (SettingsPageWifiList)
//
// Password input is delegated to the global `Keyboard` singleton (mounted
// in Main.qml at top z) — any page in the system can request input the
// same way, so the keyboard surface is unified.
Item {
    id: root
    clip: true

    property string view: "main"      // "main" | "list"

    function _onNetworkOptions(n) {
        const ssid = n.ssid
        const isCurrent = ssid === Settings.network.currentSsid
        const items = []

        if (isCurrent) {
            items.push({ label: "Desconectar",
                         onSelected: function() { Settings.network.disconnectCurrent() } })
        } else if (n.saved) {
            items.push({ label: "Conectar",
                         onSelected: function() { Settings.network.reconnectSaved(ssid) } })
        } else if (n.security === "none") {
            items.push({ label: "Conectar",
                         onSelected: function() { Settings.network.connectOpen(ssid) } })
        } else {
            items.push({ label: "Conectar com senha",
                         onSelected: function() { _onNetworkTap(n) } })
        }

        if (n.saved) {
            items.push({ label: "Esquecer rede", destructive: true,
                         onSelected: function() { Settings.network.forgetSsid(ssid) } })
        }

        items.push({ label: "Detalhes",
                     onSelected: function() {
                         // Placeholder — future: open a detail page with
                         // BSSID, freq, signal, security, IP, etc.
                     } })

        ActionSheet.show({
            title: ssid + (n.security !== "none" ? "  ·  seguro" : "  ·  aberta"),
            items: items
        })
    }

    function _onNetworkTap(n) {
        if (n.ssid === Settings.network.currentSsid) {
            Settings.network.disconnectCurrent()
            return
        }
        // Saved network → just reconnect, don't ask password again.
        // (forget via long-press / dedicated UI when wrong psk needs reset.)
        if (n.saved) {
            Settings.network.reconnectSaved(n.ssid)
            return
        }
        if (n.security === "none") {
            Settings.network.connectOpen(n.ssid)
            return
        }
        const ssid = n.ssid
        Keyboard.show({
            title:    "Senha de " + ssid,
            password: true,
            onSubmit: function(psk) {
                Settings.network.connectWithPassphrase(ssid, psk)
            }
        })
    }

    // ── Header (back arrow when in sub-view) ────────────────────────────
    Item {
        id: _header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.view === "main" ? 0 : Theme.menuHeaderH
        visible: height > 0

        Rectangle {
            anchors.fill: parent
            color: System.surface
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Theme.borderHairline
                color:  System.border
            }
        }

        Row {
            anchors {
                left: parent.left; leftMargin: Theme.spaceL
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.spaceM

            Rectangle {
                width: Theme.btnMedium; height: Theme.btnMedium; radius: width / 2
                color: _backArea.pressed ? System.pressOverlay : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                SvgIcon {
                    anchors.centerIn: parent
                    source: "qrc:/icons/chevron-up.svg"
                    color:  System.textPrimary
                    size:   Theme.iconM
                    rotation: -90
                }
                MouseArea {
                    id: _backArea
                    anchors.fill: parent
                    onClicked: root.view = "main"
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Redes Wi-Fi"
                color: System.textPrimary
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Medium
            }
        }
    }

    // ── Body ────────────────────────────────────────────────────────────
    Loader {
        anchors {
            top:    _header.bottom
            left:   parent.left
            right:  parent.right
            bottom: parent.bottom
        }
        sourceComponent: root.view === "main" ? _mainView : _listView
    }

    Component {
        id: _mainView
        Flickable {
            contentWidth:  width
            contentHeight: _mainCol.implicitHeight + Theme.spaceXL * 2

            Column {
                id: _mainCol
                anchors {
                    top: parent.top; topMargin: Theme.spaceXL
                    left: parent.left; leftMargin: Theme.spaceXL
                    right: parent.right; rightMargin: Theme.spaceXL
                }
                spacing: Theme.spaceXL

                SettingsCard {
                    title: "Wi-Fi"

                    SettingsToggle {
                        label: "Wi-Fi"
                        checked: Settings.network.wifiPowered
                        onToggled: (v) => Settings.network.setWifiPowered(v)
                    }
                    SettingsAction {
                        label: {
                            if (Settings.network.connectingSsid !== "")
                                return "Conectando: " + Settings.network.connectingSsid
                            if (Settings.network.currentSsid !== "")
                                return "Conectado: " + Settings.network.currentSsid
                            return "Desconectado"
                        }
                        sublabel: {
                            if (Settings.network.lastError !== "")
                                return Settings.network.lastError
                            return Settings.network.state || "—"
                        }
                        onTriggered: {
                            if (Settings.network.currentSsid !== "")
                                Settings.network.disconnectCurrent()
                        }
                    }
                    SettingsAction {
                        label: "Redes disponíveis"
                        sublabel: Settings.network.networks.length + " visíveis"
                        onTriggered: {
                            Settings.network.scanWifi()
                            root.view = "list"
                        }
                    }
                }

                SettingsCard {
                    title: "Bluetooth"
                    SettingsAction { label: "Em breve" }
                }

                SettingsCard {
                    title: "Hotspot"
                    SettingsAction { label: "Em breve" }
                }
            }
        }
    }

    Component {
        id: _listView
        SettingsPageWifiList {
            onConnectRequested: (n) => root._onNetworkTap(n)
            onOptionsRequested: (n) => root._onNetworkOptions(n)
        }
    }

    // Password input now lives in the global `Keyboard` overlay (Main.qml).
}
