import QtQuick
import Elise

// Home-screen weather card (top-right). Bound to the Weather controller
// (Open-Meteo). Temperature follows the metric/imperial setting. Hidden until
// the first reading lands so it never shows an empty shell.
Rectangle {
    id: root

    readonly property bool _imperial: Settings.appearance.units === "imperial"
    function _temp(c) {
        const v = root._imperial ? (c * 9 / 5 + 32) : c
        return Math.round(v) + "°"
    }

    width: 188
    height: _content.implicitHeight + Theme.spaceL * 2
    radius: Theme.radiusL
    color: System.surface
    border.color: System.border
    border.width: 1
    visible: Weather.valid
    opacity: Weather.valid ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }

    Row {
        id: _content
        anchors {
            left: parent.left; right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Theme.spaceL; rightMargin: Theme.spaceL
        }
        spacing: Theme.spaceM

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            symbol: Weather.icon
            color: System.accent
            fontStyle: Tokens.font.icon.size(34)
            fill: 1
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - parent.spacing - 40
            spacing: 1

            Text {
                text: root._temp(Weather.temperature)
                color: System.textPrimary
                font.pixelSize: Theme.fontDisplay + 6
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                text: Weather.condition
                color: System.textSecondary
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: Weather.place !== ""
                text: Weather.place
                color: System.textMuted
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }
        }
    }
}
