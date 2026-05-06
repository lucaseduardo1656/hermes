import QtQuick
import QtQuick.Controls
import Elise

// Page: Conectividade — Wi-Fi, Bluetooth (TODO), Hotspot (TODO).
//
// Bound to `Settings.network` (NetworkController over wpa_supplicant1).
// Tapping a secured network opens an inline password modal; the typed
// passphrase is fed straight to wpa_supplicant via AddNetwork.
Item {
    id: root
    clip: true

    function _onNetworkTap(n) {
        if (n.ssid === Settings.network.currentSsid) {
            Settings.network.disconnectCurrent()
            return
        }
        if (n.security === "none" || n.saved) {
            Settings.network.connectOpen(n.ssid)
            return
        }
        _prompt.show(n.ssid)
    }

    Flickable {
        id: _flick
        anchors.fill: parent
        contentWidth:  width
        contentHeight: _col.implicitHeight + Theme.spaceXL * 2

        Column {
            id: _col
            anchors {
                top: parent.top; topMargin: Theme.spaceXL
                left: parent.left; leftMargin: Theme.spaceXL
                right: parent.right; rightMargin: Theme.spaceXL
            }
            spacing: Theme.spaceXL

            // ── Wi-Fi ────────────────────────────────────────────────────
            SettingsCard {
                title: "Wi-Fi"

                SettingsAction {
                    label: Settings.network.currentSsid !== ""
                              ? "Conectado: " + Settings.network.currentSsid
                              : "Desconectado"
                    sublabel: Settings.network.state
                }
                SettingsAction {
                    label: "Procurar redes"
                    sublabel: Settings.network.networks.length + " visíveis"
                    onTriggered: Settings.network.scanWifi()
                }

                Repeater {
                    model: Settings.network.networks
                    SettingsAction {
                        label:    modelData.ssid
                        sublabel: {
                            const sec = modelData.security !== "none" ? "🔒 " : ""
                            const sig = modelData.strength + "%"
                            const cur = modelData.ssid === Settings.network.currentSsid ? " · conectado" : ""
                            const sav = modelData.saved && cur === "" ? " · salva" : ""
                            return sec + sig + cur + sav
                        }
                        onTriggered: root._onNetworkTap(modelData)
                    }
                }
            }

            // ── Bluetooth (TODO BlueZ) ───────────────────────────────────
            SettingsCard {
                title: "Bluetooth"
                SettingsAction { label: "Em breve" }
            }

            // ── Hotspot (TODO) ───────────────────────────────────────────
            SettingsCard {
                title: "Hotspot"
                SettingsAction { label: "Em breve" }
            }
        }
    }

    // ── Inline password prompt ──────────────────────────────────────────
    Rectangle {
        id: _prompt
        anchors.fill: parent
        color:   System.overlay
        visible: false
        z: 10

        property string ssid: ""

        function show(name) {
            ssid        = name
            _input.text = ""
            visible     = true
            _input.forceActiveFocus()
        }
        function hide() { visible = false }

        // Eat taps on the dim layer.
        MouseArea { anchors.fill: parent; onClicked: {} }

        Rectangle {
            anchors.centerIn: parent
            width:  Math.min(parent.width - Theme.space3XL * 2, 480)
            color:  System.surface
            radius: Theme.radiusL
            border.color: System.border
            border.width: Theme.borderHairline
            height: _form.implicitHeight + Theme.spaceXL * 2

            Column {
                id: _form
                anchors {
                    left: parent.left; right: parent.right
                    top:  parent.top
                    margins: Theme.spaceXL
                }
                spacing: Theme.spaceM

                Text {
                    text:  "Conectar a " + _prompt.ssid
                    color: System.textPrimary
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text:  "Digite a senha"
                    color: System.textMuted
                    font.pixelSize: Theme.fontSmall
                }

                Rectangle {
                    width:  parent.width
                    height: 44
                    color:  System.surface2
                    radius: Theme.radiusM
                    border.color: _input.activeFocus ? System.accent : System.border
                    border.width: Theme.borderHairline

                    TextInput {
                        id: _input
                        anchors {
                            fill: parent
                            leftMargin:  Theme.spaceM
                            rightMargin: Theme.spaceM
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        color: System.textPrimary
                        font.pixelSize: Theme.fontLabel
                        echoMode: TextInput.Password
                        clip: true
                        onAccepted: _connect.activate()
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: Theme.spaceM

                    Rectangle {
                        width: 110; height: Theme.btnMedium; radius: Theme.radiusM
                        color: _cancelArea.pressed ? System.pressOverlay : "transparent"
                        border.color: System.border
                        border.width: Theme.borderHairline
                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: System.textPrimary
                            font.pixelSize: Theme.fontLabel
                        }
                        MouseArea { id: _cancelArea
                            anchors.fill: parent
                            onClicked: _prompt.hide()
                        }
                    }

                    Rectangle {
                        id: _connect
                        width: 110; height: Theme.btnMedium; radius: Theme.radiusM
                        color: _connectArea.pressed ? System.accentDim : System.accent

                        function activate() {
                            Settings.network.connectWithPassphrase(_prompt.ssid, _input.text)
                            _prompt.hide()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Conectar"
                            color: "#000000"
                            font.pixelSize: Theme.fontLabel
                            font.weight: Font.Medium
                        }
                        MouseArea { id: _connectArea
                            anchors.fill: parent
                            onClicked: _connect.activate()
                        }
                    }
                }
            }
        }
    }
}
