import QtQuick
import Elise

// Page: Conectividade — Wi-Fi, Bluetooth, Hotspot (TODO).
//
// Bound to `Settings.network` (NetworkController over net.connman).
Flickable {
    id: root
    contentWidth:  width
    contentHeight: _col.implicitHeight + Theme.spaceXL * 2
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

    Column {
        id: _col
        anchors {
            top: parent.top; topMargin: Theme.spaceXL
            left: parent.left; leftMargin: Theme.spaceXL
            right: parent.right; rightMargin: Theme.spaceXL
        }
        spacing: Theme.spaceXL

        // ── Wi-Fi ────────────────────────────────────────────────────────
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

            // Lista de redes
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
                    onTriggered: {
                        if (modelData.state === "ready" || modelData.state === "online")
                            Settings.network.disconnectService(modelData.path)
                        else
                            Settings.network.connectService(modelData.path)
                    }
                }
            }
        }

        // ── Bluetooth ────────────────────────────────────────────────────
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

        // ── Hotspot (TODO) ───────────────────────────────────────────────
        SettingsCard {
            title: "Hotspot"

            SettingsToggle { label: "Compartilhar conexão"; checked: false }
            SettingsAction { label: "Nome da rede";        sublabel: "elise-hotspot" }
            SettingsAction { label: "Senha" }
        }
    }
}
