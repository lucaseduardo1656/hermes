import QtQuick
import Elise

// Page: Conectividade — Wi-Fi.
//
// Two-state internal router:
//   * "main"  — hero status card + toggle + Redes link
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

    // Pick the best matching strength for the active SSID from the scan
    // list so the hero card's bars track signal quality live.
    function _currentStrength() {
        const cur = Settings.network.currentSsid
        if (!cur) return 0
        const list = Settings.network.networks
        for (let i = 0; i < list.length; ++i)
            if (list[i].ssid === cur) return list[i].strength
        return 0
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

                // ── Hero status card ────────────────────────────────────
                // Big visual cue of where Wi-Fi stands: icon, SSID, IP.
                // Color of the icon shifts with connection state so the
                // user can read it without parsing text.
                Rectangle {
                    width: parent.width
                    height: 132
                    radius: Theme.radiusL
                    color: System.surface
                    border.color: System.border
                    border.width: 1

                    readonly property string _state: Settings.network.state
                    readonly property bool _online: Settings.network.currentSsid !== ""
                    readonly property bool _busy:
                        Settings.network.connectingSsid !== ""

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spaceXL
                        spacing: Theme.spaceXL

                        // Big wifi glyph + accent halo when online.
                        Rectangle {
                            width:  72; height: 72; radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: parent.parent._online ? Qt.rgba(System.accent.r,
                                                                    System.accent.g,
                                                                    System.accent.b, 0.16)
                                                          : Qt.rgba(1, 1, 1, 0.04)
                            SvgIcon {
                                anchors.centerIn: parent
                                source: "qrc:/icons/wifi.svg"
                                color:  parent.parent.parent._online
                                            ? System.accent : System.textMuted
                                size:   Theme.iconXL
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 72 - Theme.spaceXL
                            spacing: 4

                            Text {
                                width: parent.width
                                text: {
                                    if (Settings.network.connectingSsid !== "")
                                        return "Conectando a " + Settings.network.connectingSsid
                                    if (Settings.network.currentSsid !== "")
                                        return Settings.network.currentSsid
                                    if (!Settings.network.wifiPowered)
                                        return "Wi-Fi desligado"
                                    return "Sem conexão"
                                }
                                elide: Text.ElideRight
                                color: System.textPrimary
                                font.pixelSize: Theme.fontTitle
                                font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width
                                visible: Settings.network.ipAddress !== ""
                                         && Settings.network.currentSsid !== ""
                                text: "IP " + Settings.network.ipAddress
                                color: System.textSecondary
                                font.pixelSize: Theme.fontBody
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                visible: Settings.network.lastError !== ""
                                text: Settings.network.lastError
                                color: System.danger
                                font.pixelSize: Theme.fontCaption
                                elide: Text.ElideRight
                            }
                            Row {
                                spacing: Theme.spaceS
                                visible: Settings.network.currentSsid !== ""
                                SignalBars {
                                    strength: root._currentStrength()
                                    active: true
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Settings.network.state
                                    color: System.textMuted
                                    font.pixelSize: Theme.fontCaption
                                }
                            }
                        }
                    }
                }

                SettingsCard {
                    title: "Wi-Fi"

                    SettingsToggle {
                        label: "Wi-Fi"
                        checked: Settings.network.wifiPowered
                        onToggled: (v) => Settings.network.setWifiPowered(v)
                    }
                    SettingsAction {
                        label: "Redes disponíveis"
                        sublabel: Settings.network.scanning
                                    ? "Procurando…"
                                    : Settings.network.networks.length + " visíveis"
                        onTriggered: {
                            Settings.network.scanWifi()
                            root.view = "list"
                        }
                    }
                    SettingsAction {
                        visible: Settings.network.currentSsid !== ""
                        label: "Desconectar"
                        sublabel: Settings.network.currentSsid
                        onTriggered: Settings.network.disconnectCurrent()
                    }
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
}
