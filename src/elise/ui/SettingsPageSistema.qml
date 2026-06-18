import QtQuick
import QtQuick.Layouts
import Elise

// Page: About — mirrors Caelestia's modules/nexus/pages/AboutPage.qml: a hero
// ConnectedRect (logo + name + version), then grouped InfoRows under section
// headers. Flickable root (sized by the settings page Loader) so it scrolls.
//
// Bound to `Settings.sys` (SystemInfoController) over D-Bus.
VerticalFadeFlickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: _col.implicitHeight + topMargin + bottomMargin
    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.extraLarge

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

    // Section header (Caelestia nexus SectionHeader style).
    component Header: StyledText {
        property bool first: false
        Layout.fillWidth: true
        Layout.topMargin: first ? 0 : Tokens.spacing.largeIncreased
        Layout.bottomMargin: Tokens.spacing.extraSmall
        Layout.leftMargin: Tokens.padding.small
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
        elide: Text.ElideRight
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
        spacing: Tokens.spacing.extraSmall / 2

        // ── Hero ──────────────────────────────────────────────────────────
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: hero.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: hero
                anchors.centerIn: parent
                width: parent.width - Tokens.padding.largeIncreased * 2
                spacing: Tokens.spacing.small

                SvgIcon {
                    Layout.alignment: Qt.AlignHCenter
                    source: "qrc:/icons/elise-logo.svg"
                    color: System.accent; size: 72
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Tokens.spacing.small
                    text: "Elise"
                    font.pixelSize: 32; font.weight: Font.Bold
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "v" + (Settings.sys.appVersion || "0.1")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                }
            }
        }

        // ── Sistema ───────────────────────────────────────────────────────
        Header { first: true; text: "Sistema" }
        Repeater {
            model: root._system
            delegate: InfoRow {
                required property var modelData
                required property int index
                first: index === 0
                last: index === root._system.length - 1
                label: modelData.label
                value: modelData.value
            }
        }

        // ── Software ──────────────────────────────────────────────────────
        Header { text: "Software" }
        Repeater {
            model: root._software
            delegate: InfoRow {
                required property var modelData
                required property int index
                first: index === 0
                last: index === root._software.length - 1
                label: modelData.label
                value: modelData.value
            }
        }

        // ── Energia ───────────────────────────────────────────────────────
        Header { text: "Energia" }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.medium
            TextButton {
                text: "Reiniciar"
                type: TextButton.Tonal
                onClicked: Settings.sys.reboot()
            }
            TextButton {
                text: "Desligar"
                type: TextButton.Filled
                activeColour: Colours.palette.m3error
                inactiveColour: Colours.palette.m3error
                inactiveOnColour: Colours.palette.m3onError
                onClicked: Settings.sys.powerOff()
            }
            Item { Layout.fillWidth: true }
        }
    }
}
