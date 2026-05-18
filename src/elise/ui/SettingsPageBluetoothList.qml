import QtQuick
import Elise

// Sub-page: lista de dispositivos Bluetooth visíveis / pareados.
//
// Mirrors SettingsPageWifiList — tap a row to act on it; long-press
// opens an ActionSheet with paired/forget/disconnect.
Item {
    id: root
    clip: true

    signal connectRequested(var device)   // (d: {address, paired, ...})
    signal optionsRequested(var device)   // long-press

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
                title: "Dispositivos"

                SettingsAction {
                    label: Settings.bluetooth.discovering ? "Buscando…" : "Buscar"
                    sublabel: Settings.bluetooth.devices.length + " visíveis"
                    onTriggered: Settings.bluetooth.discovering
                                   ? Settings.bluetooth.stopScan()
                                   : Settings.bluetooth.startScan()
                }

                Repeater {
                    model: Settings.bluetooth.devices
                    SettingsAction {
                        label: modelData.alias
                        sublabel: {
                            const isConn = modelData.address === Settings.bluetooth.connectingAddr
                            if (isConn) return "Conectando…"
                            if (modelData.connected) return "Conectado"
                            if (modelData.paired)    return "Pareado"
                            return modelData.address
                        }
                        onTriggered: root.connectRequested(modelData)
                        onHeldLong:  root.optionsRequested(modelData)
                    }
                }
            }
        }
    }
}
