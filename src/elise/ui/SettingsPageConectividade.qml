import QtQuick
import QtQuick.Controls
import Elise

// Page: Conectividade — Wi-Fi, Bluetooth, Hotspot (TODO).
//
// Bound to `Settings.network` (NetworkController over net.connman).
// Tapping a secured network opens an inline password prompt; the typed
// passphrase is handed to the registered ConnMan Agent on connect.
Item {
    id: root
    clip: true

    function _stateText(s) {
        switch (s) {
            case "online":        return "Conectado"
            case "ready":         return "Conectado (sem internet)"
            case "association":   return "Conectando…"
            case "configuration": return "Obtendo IP…"
            case "disconnect":    return "Desconectando…"
            case "failure":       return "Falha"
            case "idle":          return ""
            default:              return s
        }
    }

    function _onNetworkTap(n) {
        if (n.state === "ready" || n.state === "online") {
            Settings.network.disconnectService(n.path)
            return
        }
        // Favorited services already have stored credentials — straight Connect
        // works. Otherwise we prompt for a passphrase if the network needs one.
        if (n.favorite || n.security === "none") {
            Settings.network.connectService(n.path)
            return
        }
        _prompt.show(n.path, n.name)
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

                SettingsToggle {
                    label: "Wi-Fi"
                    checked: Settings.network.wifiPowered
                    onToggled: (v) => Settings.network.setWifiPowered(v)
                }
                SettingsAction {
                    label: "Procurar redes"
                    sublabel: Settings.network.networks.length + " visíveis"
                    onTriggered: Settings.network.scanWifi()
                }

                Repeater {
                    model: Settings.network.networks
                    SettingsAction {
                        label:    modelData.name
                        sublabel: {
                            const st = root._stateText(modelData.state)
                            const sec = modelData.security !== "none" ? "🔒 " : ""
                            const sig = modelData.strength + "%"
                            return sec + sig + (st ? " · " + st : "")
                        }
                        onTriggered: root._onNetworkTap(modelData)
                    }
                }
            }

            // ── Bluetooth ────────────────────────────────────────────────
            SettingsCard {
                title: "Bluetooth"

                SettingsToggle {
                    label: "Bluetooth"
                    checked: Settings.network.bluetoothPowered
                    onToggled: (v) => Settings.network.setBluetoothPowered(v)
                }
                SettingsAction { label: "Dispositivos pareados";  sublabel: "Nenhum" }
                SettingsAction { label: "Parear novo dispositivo" }
            }

            // ── Hotspot (TODO) ───────────────────────────────────────────
            SettingsCard {
                title: "Hotspot"

                SettingsToggle { label: "Compartilhar conexão"; checked: false }
                SettingsAction { label: "Nome da rede";        sublabel: "elise-hotspot" }
                SettingsAction { label: "Senha" }
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

        property string servicePath: ""
        property string ssid: ""

        function show(path, name) {
            servicePath = path
            ssid        = name
            _input.text = ""
            visible     = true
            _input.forceActiveFocus()
        }
        function hide() { visible = false }

        // Eat taps on the dim layer
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
                    text:  "Digite a senha da rede"
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
                        onAccepted: _connect.clicked()
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
                        signal clicked()
                        Text {
                            anchors.centerIn: parent
                            text: "Conectar"
                            color: "#000000"
                            font.pixelSize: Theme.fontLabel
                            font.weight: Font.Medium
                        }
                        MouseArea { id: _connectArea
                            anchors.fill: parent
                            onClicked: _connect.clicked()
                        }
                        onClicked: {
                            Settings.network.connectWithPassphrase(_prompt.servicePath, _input.text)
                            _prompt.hide()
                        }
                    }
                }
            }
        }
    }
}
