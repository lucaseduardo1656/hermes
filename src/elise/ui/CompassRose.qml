import QtQuick
import QtQuick.Shapes
import Elise

// Floating compass dial. Shows where North is when the map has been
// rotated off-axis; tap to snap the bearing back to 0. Hidden while
// bearing is already zero so it doesn't crowd the screen.
//
// Owner sets `bearing` (the map's current bearing in degrees, CW
// from north) and listens for `resetRequested`.
Item {
    id: root

    property real bearing: 0
    signal resetRequested()

    width:  Theme.btnMedium
    height: Theme.btnMedium

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color:  _area.pressed ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer
        border.color: Colours.palette.m3outlineVariant
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    // The dial — rotates inverse to the map bearing so the N pointer
    // always indicates true north on screen.
    Item {
        id: _dial
        anchors.fill: parent
        // Map bearing wraps 0..360; the inverse for the dial is just
        // -bearing. A naive NumberAnimation on rotation would spin
        // the long way around at the 359°→0° wrap, so no Behavior.
        rotation: -root.bearing

        readonly property real _cx: width / 2
        readonly property real _cy: height / 2

        // Proper kite-shaped compass needle: long accent triangle
        // pointing up (north), shorter muted triangle pointing down
        // (south), joined at the centre. Two ShapePaths so each half
        // can have its own fill colour.
        Shape {
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Colours.palette.m3primary
                startX: _dial._cx; startY: 6
                PathLine { x: _dial._cx + 6; y: _dial._cy }
                PathLine { x: _dial._cx;     y: _dial._cy }
                PathLine { x: _dial._cx - 6; y: _dial._cy }
                PathLine { x: _dial._cx;     y: 6 }
            }
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Colours.palette.m3onSurfaceVariant
                startX: _dial._cx; startY: _dial.height - 6
                PathLine { x: _dial._cx + 5; y: _dial._cy }
                PathLine { x: _dial._cx;     y: _dial._cy }
                PathLine { x: _dial._cx - 5; y: _dial._cy }
                PathLine { x: _dial._cx;     y: _dial.height - 6 }
            }
        }

        // Pivot pin in the centre of the needle.
        Rectangle {
            anchors.centerIn: parent
            width: 4; height: 4
            radius: 2
            color: Colours.palette.m3onSurface
        }

        // Tiny N marker just outside the dial top.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: -3
            text: "N"
            color: Colours.palette.m3primary
            font.pixelSize: 9
            font.weight: Font.Bold
        }
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        onClicked: root.resetRequested()
    }
}
