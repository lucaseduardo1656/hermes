pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Page: Network — Caelestia nexus NetworkPage. Wi-Fi ToggleRow over an ItemList
// of nearby networks; the indeterminate scan bar lives at the top of the list
// card and grows in while a scan is in flight. Password entry is delegated to
// the global Keyboard; per-network actions go through the ActionSheet.
VerticalFadeFlickable {
    id: page
    clip: true
    contentWidth: width
    contentHeight: _col.implicitHeight + topMargin + bottomMargin
    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.extraLarge

    function _isSecure(n) { return n.security !== "none" }

    function _onNetworkTap(n) {
        if (n.ssid === Settings.network.currentSsid) { Settings.network.disconnectCurrent(); return }
        if (n.saved)               { Settings.network.reconnectSaved(n.ssid); return }
        if (!_isSecure(n))         { Settings.network.connectOpen(n.ssid);    return }
        const ssid = n.ssid
        Keyboard.show({
            title: "Digite a senha", subtitle: "Rede: " + ssid, password: true,
            onSubmit: function(psk) { Settings.network.connectWithPassphrase(ssid, psk) }
        })
    }
    function _onNetworkOptions(n) {
        const ssid = n.ssid
        const items = []
        if (ssid === Settings.network.currentSsid)
            items.push({ label: "Desconectar", onSelected: function() { Settings.network.disconnectCurrent() } })
        else
            items.push({ label: "Conectar", onSelected: function() { page._onNetworkTap(n) } })
        if (n.saved)
            items.push({ label: "Esquecer rede", destructive: true,
                         onSelected: function() { Settings.network.forgetSsid(ssid) } })
        ActionSheet.show({ title: ssid, items: items })
    }

    // Keep the network list fresh while the page is open. The scan bar itself is
    // always shown while Wi-Fi is on (the page is continuously rescanning).
    Component.onCompleted: if (Settings.network.wifiPowered) Settings.network.scanWifi()
    Timer {
        interval: 8000; repeat: true; running: Settings.network.wifiPowered
        triggeredOnStart: true
        onTriggered: Settings.network.scanWifi()
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: "Wi-Fi"
            labelFont: Tokens.font.body.medium
            checked: Settings.network.wifiPowered
            onToggled: Settings.network.setWifiPowered(checked)
        }

        ItemList {
            id: networkList
            last: true

            showList: Settings.network.wifiPowered
            placeholderIcon: Settings.network.wifiPowered ? "wifi_find" : "signal_wifi_off"
            placeholderText: Settings.network.wifiPowered ? "Nenhuma rede encontrada" : "Wi-Fi desligado"
            // Scan bar lives INSIDE the list card (over the solid surface) exactly
            // like the Bluetooth pair page — the only place the native
            // StyledProgressBar reliably composites here. Reserve its strip and
            // push the list below it; gate on the stable global wifiPowered.
            extraHeight: Settings.network.wifiPowered ? scanIndicator.implicitHeight : 0
            list.anchors.top: scanIndicator.bottom

            model: Settings.network.wifiPowered ? Settings.network.networks : []

            delegate: StateLayer {
                id: net
                required property var modelData
                required property int index

                readonly property bool current: modelData.ssid === Settings.network.currentSsid
                readonly property bool connecting: modelData.ssid === Settings.network.connectingSsid
                readonly property bool saved: modelData.saved === true

                anchors.left: networkList.list.contentItem.left
                anchors.right: networkList.list.contentItem.right
                anchors.fill: undefined
                implicitHeight: netLayout.implicitHeight + netLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                disabled: connecting

                onClicked: if (!connecting) page._onNetworkTap(modelData)

                RowLayout {
                    id: netLayout
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.extraLarge
                    anchors.rightMargin: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        symbol: Icons.getNetworkIcon(net.modelData.strength, page._isSecure(net.modelData))
                        color: net.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        opacity: net.connecting ? 0.5 : 1
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        opacity: net.connecting ? 0.5 : 1

                        StyledText {
                            Layout.fillWidth: true
                            text: net.modelData.ssid
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Segurança: " + (page._isSecure(net.modelData) ? net.modelData.security.toUpperCase() : "aberta")
                                  + (net.saved ? "  •  Salva" : "")
                                  + (net.current ? "  •  Conectado" : "")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    // Trailing: spinner while connecting; gear (options) for
                    // saved/current; plain lock otherwise.
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Theme.iconM
                        implicitHeight: Theme.iconM

                        LoadingIndicator {
                            anchors.centerIn: parent
                            visible: net.connecting
                            implicitSize: Theme.iconM
                        }
                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !net.connecting
                            symbol: (net.saved || net.current) ? "settings" : "lock"
                            color: net.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }
                        StateLayer {
                            disabled: net.connecting || !(net.saved || net.current)
                            onClicked: page._onNetworkOptions(net.modelData)
                        }
                    }
                }
            }

            // Same indeterminate M3 bar as the Bluetooth pair page, pinned to the
            // top of the list card. Hidden when Wi-Fi is off.
            StyledProgressBar {
                id: scanIndicator
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.margins: 1
                implicitHeight: Tokens.rounding.extraSmall
                indeterminate: true
                visible: Settings.network.wifiPowered
            }
        }
    }
}
