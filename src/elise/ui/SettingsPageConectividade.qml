import QtQuick
import QtQuick.Controls
import Elise

// Page: Network — a Wi-Fi toggle header card over the inline list of nearby
// networks (Caelestia layout). Password input is delegated to the global
// Keyboard singleton; per-network actions go through the ActionSheet.
Flickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: _outer.height
    boundsBehavior: Flickable.StopAtBounds

    function _onNetworkTap(n) {
        if (n.ssid === Settings.network.currentSsid) { Settings.network.disconnectCurrent(); return }
        if (n.saved)               { Settings.network.reconnectSaved(n.ssid); return }
        if (n.security === "none") { Settings.network.connectOpen(n.ssid);    return }
        const ssid = n.ssid
        Keyboard.show({
            title: "Senha de " + ssid, password: true,
            onSubmit: function(psk) { Settings.network.connectWithPassphrase(ssid, psk) }
        })
    }
    function _onNetworkOptions(n) {
        const ssid = n.ssid
        const isCurrent = ssid === Settings.network.currentSsid
        const items = []
        if (isCurrent)
            items.push({ label: "Desconectar", onSelected: function() { Settings.network.disconnectCurrent() } })
        else
            items.push({ label: "Conectar", onSelected: function() { root._onNetworkTap(n) } })
        if (n.saved)
            items.push({ label: "Esquecer rede", destructive: true,
                         onSelected: function() { Settings.network.forgetSsid(ssid) } })
        ActionSheet.show({ title: ssid, items: items })
    }
    function _strengthOf(ssid) {
        const list = Settings.network.networks
        for (let i = 0; i < list.length; ++i)
            if (list[i].ssid === ssid) return list[i].strength
        return 0
    }

    // Auto-scan: refresh on open and on a slow timer (the indeterminate bar in
    // the gap shows while a scan is in flight).
    Component.onCompleted: if (Settings.network.wifiPowered) Settings.network.scanWifi()
    Timer {
        interval: 12000; repeat: true; running: Settings.network.wifiPowered
        onTriggered: Settings.network.scanWifi()
    }

        // Two separate cards — a Wi-Fi toggle card and the network list card —
        // with a real gap between them (the panel shows through) so they don't
        // look glued. The scan indicator sweeps in that gap.
        Column {
            id: _outer
            width: parent.width
            spacing: 0

            // ── Wi-Fi toggle card — acts as the FIRST item of the group, so
            //    only its top corners round (the list continues below the gap).
            Rectangle {
                width: parent.width; height: 64
                topLeftRadius: Theme.radiusL; topRightRadius: Theme.radiusL
                bottomLeftRadius: 0; bottomRightRadius: 0
                color: Qt.rgba(1, 1, 1, 0.05)
                clip: true
                Rectangle { anchors.fill: parent
                            color: _wifiRowArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                Text {
                    anchors { left: parent.left; leftMargin: Theme.spaceL
                              verticalCenter: parent.verticalCenter }
                    text: "Wi-Fi"; color: System.textPrimary
                    font.pixelSize: Theme.fontBody; font.weight: Font.Medium
                }
                StyledSwitch {
                    id: _wifiSwitch
                    anchors { right: parent.right; rightMargin: Theme.spaceL
                              verticalCenter: parent.verticalCenter }
                    checked: Settings.network.wifiPowered
                    onToggled: Settings.network.setWifiPowered(checked)
                }
                MouseArea {
                    id: _wifiRowArea
                    anchors { left: parent.left; right: _wifiSwitch.left; top: parent.top; bottom: parent.bottom }
                    onClicked: Settings.network.setWifiPowered(!Settings.network.wifiPowered)
                }
            }

            // ── Gap with the scan indicator — Caelestia StyledProgressBar
            //    (indeterminate M3, native WavyLine/LinearIndicatorManager).
            Item {
                id: _gap
                width: parent.width; height: Theme.spaceXS; clip: true
                StyledProgressBar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    indeterminate: Settings.network.scanning
                    opacity: Settings.network.scanning ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                }
            }

            // ── Network list card — continues the group, so its top is square
            //    (first network = the "second" item) and only the bottom rounds.
            Rectangle {
                width: parent.width; height: _listCol.height
                topLeftRadius: 0; topRightRadius: 0
                bottomLeftRadius: Theme.radiusL; bottomRightRadius: Theme.radiusL
                color: Qt.rgba(1, 1, 1, 0.05)
                clip: true

                Column {
                    id: _listCol
                    width: parent.width

                // Empty state
                Item {
                    width: parent.width; height: 128
                    visible: Settings.network.networks.length === 0
                    Column {
                        anchors.centerIn: parent; spacing: Theme.spaceS
                        SvgIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: "qrc:/icons/wifi.svg"; color: System.textMuted; size: Theme.iconXL
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Settings.network.scanning ? "Procurando redes…" : "Nenhuma rede encontrada"
                            color: System.textSecondary; font.pixelSize: Theme.fontBody
                        }
                    }
                }

                Repeater {
                    model: Settings.network.networks
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: _listCol.width
                        height: 60
                        readonly property bool _current: modelData.ssid === Settings.network.currentSsid
                        readonly property bool _saved:   modelData.saved === true

                        Rectangle { anchors.fill: parent
                                    color: _rowArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }

                        SvgIcon {
                            id: _wifiIcon
                            anchors { left: parent.left; leftMargin: Theme.spaceL
                                      verticalCenter: parent.verticalCenter }
                            source: "qrc:/icons/wifi.svg"
                            color:  _current ? System.accent : System.textSecondary
                            size:   Theme.iconS
                        }
                        Column {
                            anchors { left: _wifiIcon.right; leftMargin: Theme.spaceM
                                      right: _rowAction.left; rightMargin: Theme.spaceS
                                      verticalCenter: parent.verticalCenter }
                            spacing: 1
                            Text {
                                width: parent.width
                                text: modelData.ssid
                                color: _current ? System.accent : System.textPrimary
                                font.pixelSize: Theme.fontBody
                                font.weight: _current ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: "Segurança: " + (modelData.security === "none" ? "aberta"
                                        : modelData.security.toUpperCase())
                                      + (_saved ? "  ·  Salva" : "")
                                      + (_current ? "  ·  Conectado" : "")
                                color: System.textSecondary; font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            id: _rowAction
                            anchors { right: parent.right; rightMargin: Theme.spaceL
                                      verticalCenter: parent.verticalCenter }
                            width: Theme.btnMedium; height: Theme.btnMedium; radius: width / 2
                            color: (_saved || _current) && _gearArea.pressed ? System.surface2 : "transparent"
                            SvgIcon {
                                anchors.centerIn: parent
                                source: (_saved || _current) ? "qrc:/icons/cog.svg" : "qrc:/icons/lock.svg"
                                color: System.textSecondary; size: Theme.iconS
                            }
                            MouseArea { id: _gearArea; anchors.fill: parent
                                        enabled: _saved || _current
                                        onClicked: root._onNetworkOptions(modelData) }
                        }
                        MouseArea { id: _rowArea
                            anchors { left: parent.left; right: _rowAction.left; top: parent.top; bottom: parent.bottom }
                            onClicked: root._onNetworkTap(modelData) }

                        Rectangle { visible: index < Settings.network.networks.length - 1
                                    anchors { left: _wifiIcon.left; right: parent.right
                                              rightMargin: Theme.spaceL; bottom: parent.bottom }
                                    height: 1; color: Qt.rgba(1,1,1,0.06) }
                    }   // delegate Item
                }       // Repeater
                }       // _listCol Column
            }           // list card Rectangle
        }               // _outer Column
    }                   // root Flickable
