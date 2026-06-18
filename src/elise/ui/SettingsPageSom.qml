pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Page: Audio — Caelestia nexus AudioPage layout. Two connected groups
// (Output / Input), each a SliderRow + ToggleRow (Muted) + a device row, then
// a standalone "App volumes" nav row.
//
// Output volume + Muted are wired to the controller (PipeWire via wpctl).
// Input + per-app volumes have no backend on this hardware (single speaker
// sink, no capture), so those controls are cosmetic placeholders.
VerticalFadeFlickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: _col.implicitHeight + topMargin + bottomMargin
    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.extraLarge

    // Cosmetic state for the Input block (no capture device on this unit).
    property int  _inputVol:   58
    property bool _inputMuted: true

    // A fixed device row (single sink/source on this hardware, always current).
    component DeviceRow: ConnectedRect {
        id: dev
        property url icon
        property string name
        last: true
        Layout.fillWidth: true
        implicitHeight: 64

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 38; height: 38; radius: width / 2
                color: Qt.rgba(System.accent.r, System.accent.g, System.accent.b, 0.22)
                SvgIcon {
                    anchors.centerIn: parent
                    source: dev.icon
                    color: System.accent; size: Theme.iconS
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: dev.name
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
            SvgIcon {
                Layout.alignment: Qt.AlignVCenter
                source: "qrc:/icons/check.svg"
                color: System.accent; size: Theme.iconS
            }
        }
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
        spacing: Tokens.spacing.extraSmall / 2

        // ── Output ──────────────────────────────────────────────────────────
        SliderRow {
            Layout.fillWidth: true
            first: true
            iconSource: "qrc:/icons/speaker.svg"
            label: "Output"
            valueLabel: Math.round(value * 100) + "%"
            value: Settings.audio.volume / 100
            enabled: !Settings.audio.muted
            onMoved: v => Settings.audio.setVolume(Math.round(v * 100))
        }
        ToggleRow {
            Layout.fillWidth: true
            text: "Muted"
            checked: Settings.audio.muted
            onToggled: Settings.audio.setMuted(checked)
        }
        DeviceRow {
            icon: "qrc:/icons/speaker.svg"
            name: "Alto-falantes do veículo"
        }

        // ── Input (cosmetic — no capture device) ────────────────────────────
        SliderRow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            first: true
            iconSource: "qrc:/icons/mic-fill.svg"
            label: "Input"
            valueLabel: Math.round(value * 100) + "%"
            value: root._inputVol / 100
            enabled: !root._inputMuted
            onMoved: v => root._inputVol = Math.round(v * 100)
        }
        ToggleRow {
            Layout.fillWidth: true
            text: "Muted"
            checked: root._inputMuted
            onToggled: root._inputMuted = checked
        }
        DeviceRow {
            icon: "qrc:/icons/mic-fill.svg"
            name: "Microfone interno"
        }

        // ── App volumes (no per-app backend) ────────────────────────────────
        ConnectedRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            first: true; last: true
            implicitHeight: 66

            StateLayer {}

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 36; height: 36; radius: width / 2
                    color: Colours.palette.m3surfaceContainerHighest
                    SvgIcon {
                        anchors.centerIn: parent
                        source: "qrc:/icons/sliders.svg"
                        color: Colours.palette.m3onSurfaceVariant; size: Theme.iconS
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: "App volumes"
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Nenhum app tocando áudio"
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }
                SvgIcon {
                    Layout.alignment: Qt.AlignVCenter
                    source: "qrc:/icons/chevron-right.svg"
                    color: Colours.palette.m3onSurfaceVariant; size: Theme.iconS
                }
            }
        }
    }
}
