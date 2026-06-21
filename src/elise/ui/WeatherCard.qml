import QtQuick
import Elise

// Compact home-screen weather chip (top-right). Just the glyph + temperature
// at a glance; condition shows small underneath. Tapping expands a small popup
// with the extra detail (feels-like / humidity / place) so the resting chip
// stays minimal. Bound to the Weather controller (Open-Meteo).
Item {
    id: root

    readonly property bool _imperial: Settings.appearance.units === "imperial"
    function _t(c) {
        const v = root._imperial ? (c * 9 / 5 + 32) : c
        return Math.round(v) + "°"
    }

    property bool expanded: false

    implicitWidth:  _chip.width
    implicitHeight: _chip.height
    visible: Weather.valid
    opacity: Weather.valid ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }

    // ── Resting chip ────────────────────────────────────────────────────
    Rectangle {
        id: _chip
        width: _row.implicitWidth + Theme.spaceM * 2
        height: 44
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainer
        border.color: Colours.palette.m3outlineVariant
        border.width: 1

        Row {
            id: _row
            anchors.centerIn: parent
            spacing: Theme.spaceS

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                symbol: Weather.icon
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
                fill: 1
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root._t(Weather.temperature)
                color: Colours.palette.m3onSurface
                font.pixelSize: Theme.fontLarge
                font.weight: Font.Bold
            }
        }

        MouseArea { anchors.fill: parent; onClicked: root.expanded = !root.expanded }
    }

    // ── Expanded detail popover (standard floating-card pattern) ────────
    Popover {
        open: root.expanded
        originCorner: Item.TopRight
        anchors { top: _chip.bottom; topMargin: Theme.spaceS; right: _chip.right }

        Column {
            width: 188
            spacing: Theme.spaceXS

            StyledText {
                width: parent.width
                text: Weather.condition
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
                wrapMode: Text.WordWrap
            }
            StyledText {
                width: parent.width
                visible: Weather.place !== ""
                text: Weather.place
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
            }
            Row {
                width: parent.width
                spacing: Theme.spaceL
                topPadding: Theme.spaceXS
                StyledText {
                    text: "Sensação " + root._t(Weather.feelsLike)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
                StyledText {
                    text: "Umidade " + Weather.humidity + "%"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }
    }
}
