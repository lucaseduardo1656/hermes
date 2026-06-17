import QtQuick
import Elise

// Page: About — Caelestia layout (#22/#23). A hero card with the Elise logo +
// version, then grouped info rows (Sistema / Software) and the power actions.
//
// Bound to `Settings.sys` (SystemInfoController) over D-Bus; dashes render when
// the daemon link is down rather than showing stale numbers.
Item {
    id: root
    clip: true

    function _formatGB(bytes) {
        if (!bytes) return "—"
        return (bytes / 1073741824).toFixed(1) + " GB"
    }
    function _formatUptime(s) {
        if (!s) return "—"
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    readonly property var _system: [
        { label: "Hostname",      value: Settings.sys.hostname || "—" },
        { label: "Dispositivo",   value: "Raspberry Pi 5" },
        { label: "Distribuição",  value: Settings.sys.osVersion || "—" },
        { label: "Kernel",        value: Settings.sys.kernelVersion || "—" },
        { label: "Armazenamento", value: _formatGB(Settings.sys.storageUsedBytes)
                                          + " / " + _formatGB(Settings.sys.storageTotalBytes) },
        { label: "Tempo ligado",  value: _formatUptime(Settings.sys.uptimeSeconds) }
    ]
    readonly property var _software: [
        { label: "Elise",  value: Settings.sys.appVersion || "—" },
        { label: "Qt",     value: "6.8.1" },
        { label: "Daemon", value: Settings.sys.online ? "conectado" : "desconectado" }
    ]

    Flickable {
        anchors.fill: parent
        contentHeight: _col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: _col
            width: parent.width
            spacing: Theme.spaceL

            // ── Hero card ─────────────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 220
                radius: Theme.radiusL
                color: Qt.rgba(1, 1, 1, 0.05)
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spaceS
                    SvgIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "qrc:/icons/elise-logo.svg"
                        color: System.accent; size: 64
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Elise"; color: System.textPrimary
                        font.pixelSize: 34; font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "v" + (Settings.sys.appVersion || "0.1")
                        color: System.textSecondary; font.pixelSize: Theme.fontBody
                    }
                }
            }

            // ── Sistema group ─────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: Theme.spaceS
                Text { text: "Sistema"; color: System.textSecondary
                       font.pixelSize: Theme.fontLabel; font.weight: Font.Medium
                       leftPadding: Theme.spaceXS }
                Rectangle {
                    width: parent.width; height: _sysCol.height
                    radius: Theme.radiusL; color: Qt.rgba(1, 1, 1, 0.05); clip: true
                    Column {
                        id: _sysCol
                        width: parent.width
                        Repeater {
                            model: root._system
                            delegate: Item {
                                required property var modelData
                                required property int index
                                width: _sysCol.width; height: 52
                                Text { anchors { left: parent.left; leftMargin: Theme.spaceL
                                                 verticalCenter: parent.verticalCenter }
                                       text: modelData.label; color: System.textPrimary
                                       font.pixelSize: Theme.fontBody }
                                Text { anchors { right: parent.right; rightMargin: Theme.spaceL
                                                 verticalCenter: parent.verticalCenter }
                                       text: modelData.value; color: System.textSecondary
                                       font.pixelSize: Theme.fontBody }
                                Rectangle { visible: index < root._system.length - 1
                                            anchors { left: parent.left; right: parent.right
                                                      leftMargin: Theme.spaceL; rightMargin: Theme.spaceL
                                                      bottom: parent.bottom }
                                            height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                            }
                        }
                    }
                }
            }

            // ── Software group ────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: Theme.spaceS
                Text { text: "Software"; color: System.textSecondary
                       font.pixelSize: Theme.fontLabel; font.weight: Font.Medium
                       leftPadding: Theme.spaceXS }
                Rectangle {
                    width: parent.width; height: _swCol.height
                    radius: Theme.radiusL; color: Qt.rgba(1, 1, 1, 0.05); clip: true
                    Column {
                        id: _swCol
                        width: parent.width
                        Repeater {
                            model: root._software
                            delegate: Item {
                                required property var modelData
                                required property int index
                                width: _swCol.width; height: 52
                                Text { anchors { left: parent.left; leftMargin: Theme.spaceL
                                                 verticalCenter: parent.verticalCenter }
                                       text: modelData.label; color: System.textPrimary
                                       font.pixelSize: Theme.fontBody }
                                Text { anchors { right: parent.right; rightMargin: Theme.spaceL
                                                 verticalCenter: parent.verticalCenter }
                                       text: modelData.value; color: System.textSecondary
                                       font.pixelSize: Theme.fontBody }
                                Rectangle { visible: index < root._software.length - 1
                                            anchors { left: parent.left; right: parent.right
                                                      leftMargin: Theme.spaceL; rightMargin: Theme.spaceL
                                                      bottom: parent.bottom }
                                            height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                            }
                        }
                    }
                }
            }

            // ── Energia group (power actions) ─────────────────────────────
            Column {
                width: parent.width
                spacing: Theme.spaceS
                Text { text: "Energia"; color: System.textSecondary
                       font.pixelSize: Theme.fontLabel; font.weight: Font.Medium
                       leftPadding: Theme.spaceXS }
                Rectangle {
                    width: parent.width; height: _pwrCol.height
                    radius: Theme.radiusL; color: Qt.rgba(1, 1, 1, 0.05); clip: true
                    Column {
                        id: _pwrCol
                        width: parent.width
                        Item {
                            width: parent.width; height: 56
                            Rectangle { anchors.fill: parent
                                        color: _rebootArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                            Text { anchors { left: parent.left; leftMargin: Theme.spaceL
                                             verticalCenter: parent.verticalCenter }
                                   text: "Reiniciar"; color: System.textPrimary; font.pixelSize: Theme.fontBody }
                            MouseArea { id: _rebootArea; anchors.fill: parent
                                        onClicked: Settings.sys.reboot() }
                            Rectangle { anchors { left: parent.left; right: parent.right
                                                  leftMargin: Theme.spaceL; rightMargin: Theme.spaceL
                                                  bottom: parent.bottom }
                                        height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                        }
                        Item {
                            width: parent.width; height: 56
                            Rectangle { anchors.fill: parent
                                        color: _offArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                            Text { anchors { left: parent.left; leftMargin: Theme.spaceL
                                             verticalCenter: parent.verticalCenter }
                                   text: "Desligar"; color: System.danger; font.pixelSize: Theme.fontBody }
                            MouseArea { id: _offArea; anchors.fill: parent
                                        onClicked: Settings.sys.powerOff() }
                        }
                    }
                }
            }
        }
    }
}
