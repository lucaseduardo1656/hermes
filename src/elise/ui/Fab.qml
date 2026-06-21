import QtQuick
import Elise

// Floating circular button for map actions. M3 tonal style by default
// (surface-container circle, like the CompassRose) so the whole right-edge
// stack reads as one set; set `primary: true` for the accent-filled variant.
//
// Usage:
//   Fab { symbol: "settings"; onClicked: ... }
Item {
    id: root

    property string symbol
    property bool   primary: false
    signal clicked()

    readonly property int size: Theme.btnMedium

    width:  size
    height: size

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color: root.primary
                 ? (_area.pressed ? Colours.palette.m3inversePrimary : Colours.palette.m3primary)
                 : (_area.pressed ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer)
        border.color: root.primary ? "transparent" : Colours.palette.m3outlineVariant
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    MaterialIcon {
        anchors.centerIn: parent
        symbol: root.symbol
        color:  root.primary ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.medium
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
