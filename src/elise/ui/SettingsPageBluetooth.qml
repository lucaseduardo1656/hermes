import QtQuick
import Elise

// Page: Bluetooth — toggle, status, lista de devices (sub-view).
Item {
    id: root
    clip: true

    property string view: "main"      // "main" | "list"

    function _onDeviceTap(d) {
        if (d.connected) {
            Settings.bluetooth.disconnectDevice(d.address)
            return
        }
        if (d.paired) {
            Settings.bluetooth.connectDevice(d.address)
            return
        }
        // First-time pairing: triggers our NoInputNoOutput agent, which
        // auto-approves. On success the controller also flips Trusted
        // and follows up with a Connect for the audio link.
        Settings.bluetooth.pair(d.address)
    }

    function _onDeviceOptions(d) {
        const items = []
        if (d.connected) {
            items.push({ label: "Desconectar",
                         onSelected: function() {
                             Settings.bluetooth.disconnectDevice(d.address) } })
        } else if (d.paired) {
            items.push({ label: "Conectar",
                         onSelected: function() {
                             Settings.bluetooth.connectDevice(d.address) } })
        } else {
            items.push({ label: "Parear e conectar",
                         onSelected: function() {
                             Settings.bluetooth.pair(d.address) } })
        }
        if (d.paired) {
            items.push({ label: "Esquecer dispositivo", destructive: true,
                         onSelected: function() {
                             Settings.bluetooth.forget(d.address) } })
        }
        ActionSheet.show({
            title: d.alias,
            items: items
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
                    onClicked: {
                        Settings.bluetooth.stopScan()
                        root.view = "main"
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Dispositivos Bluetooth"
                color: System.textPrimary
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Medium
            }
        }
    }

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
                    title: "Bluetooth"

                    SettingsToggle {
                        label: "Bluetooth"
                        checked: Settings.bluetooth.powered
                        onToggled: (v) => Settings.bluetooth.setPowered(v)
                    }
                    SettingsAction {
                        label: {
                            if (Settings.bluetooth.connectingAddr !== "")
                                return "Conectando…"
                            if (Settings.bluetooth.connectedAlias !== "")
                                return "Conectado: " + Settings.bluetooth.connectedAlias
                            return "Desconectado"
                        }
                        sublabel: Settings.bluetooth.lastError !== ""
                                    ? Settings.bluetooth.lastError
                                    : (Settings.bluetooth.powered ? "Bluetooth ligado"
                                                                  : "Bluetooth desligado")
                    }
                    SettingsAction {
                        label: "Dispositivos"
                        sublabel: Settings.bluetooth.devices.length + " visíveis"
                        onTriggered: {
                            if (Settings.bluetooth.powered)
                                Settings.bluetooth.startScan()
                            root.view = "list"
                        }
                    }
                }
            }
        }
    }

    Component {
        id: _listView
        SettingsPageBluetoothList {
            onConnectRequested: (d) => root._onDeviceTap(d)
            onOptionsRequested: (d) => root._onDeviceOptions(d)
        }
    }
}
