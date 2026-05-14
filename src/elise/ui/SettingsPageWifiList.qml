import QtQuick
import Elise

// Sub-page: lista completa de redes WiFi disponíveis.
//
// Shown when the user taps "Redes disponíveis" on Conectividade. Has its
// own back affordance via the parent's `backRequested()` hook (the parent
// page renders a header with a chevron-left button that calls back here).
Item {
    id: root
    clip: true

    signal connectRequested(var network)   // (n: {ssid, security, saved, ...})
    signal optionsRequested(var network)   // long-press

    Flickable {
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

            SettingsCard {
                title: "Redes próximas"

                SettingsAction {
                    label: "Atualizar"
                    sublabel: Settings.network.networks.length + " visíveis"
                    onTriggered: Settings.network.scanWifi()
                }

                Repeater {
                    model: Settings.network.networks
                    SettingsAction {
                        label: modelData.ssid
                        sublabel: {
                            const sec = modelData.security !== "none" ? "🔒 " : ""
                            const isConn = modelData.ssid === Settings.network.connectingSsid
                            const isCur  = modelData.ssid === Settings.network.currentSsid
                            if (isConn) return sec + "Conectando…"
                            if (isCur)  return sec + "Conectado"
                            return sec + modelData.strength + "%"
                        }
                        onTriggered: root.connectRequested(modelData)
                        onHeldLong:  root.optionsRequested(modelData)
                    }
                }
            }
        }
    }
}
