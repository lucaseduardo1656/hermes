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

                SettingsRow {
                    interactive: true
                    label: Settings.network.scanning ? "Procurando redes…" : "Atualizar"
                    sublabel: Settings.network.networks.length + " visíveis"
                    onClicked: Settings.network.scanWifi()

                    // Spinner trailing slot while a scan is in flight; refresh
                    // glyph otherwise. Both occupy the same anchored Item so
                    // the row geometry doesn't jitter.
                    Item {
                        width: Theme.iconM; height: Theme.iconM
                        anchors.verticalCenter: parent.verticalCenter

                        SvgIcon {
                            anchors.centerIn: parent
                            visible: !Settings.network.scanning
                            source: "qrc:/icons/refresh.svg"
                            color:  System.textMuted
                            size:   Theme.iconS
                        }
                        Rectangle {
                            id: _spinner
                            visible: Settings.network.scanning
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.color: System.accent
                            border.width: 2
                            // Cut a quadrant out so the ring reads as moving.
                            Rectangle {
                                width: parent.width / 2; height: parent.width / 2
                                color: System.surface
                                anchors { top: parent.top; right: parent.right }
                            }
                            RotationAnimator on rotation {
                                from: 0; to: 360; duration: 900
                                loops: Animation.Infinite
                                running: _spinner.visible
                            }
                        }
                    }
                }

                Repeater {
                    model: Settings.network.networks
                    SettingsRow {
                        interactive: true
                        label: modelData.ssid
                        sublabel: {
                            const isConn = modelData.ssid === Settings.network.connectingSsid
                            const isCur  = modelData.ssid === Settings.network.currentSsid
                            if (isConn) return "Conectando…"
                            if (isCur)  return "Conectado"
                            if (modelData.saved) return "Salva"
                            return ""
                        }
                        onClicked:     root.connectRequested(modelData)
                        onLongPressed: root.optionsRequested(modelData)

                        Row {
                            spacing: Theme.spaceS
                            anchors.verticalCenter: parent.verticalCenter
                            SvgIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData.security !== "none"
                                source: "qrc:/icons/lock.svg"
                                color:  System.textSecondary
                                size:   Theme.iconS
                            }
                            SignalBars {
                                anchors.verticalCenter: parent.verticalCenter
                                strength: modelData.strength
                                active:   modelData.ssid === Settings.network.currentSsid
                            }
                        }
                    }
                }
            }
        }
    }
}
