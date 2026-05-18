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
        color:  _area.pressed ? System.pressOverlay : System.surface
        border.color: System.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    // The dial — rotates inverse to the map bearing so the N pointer
    // always indicates true north on screen.
    Item {
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
                fillColor: System.accent
                startX: parent._cx; startY: 6              // tip (top)
                PathLine { x: parent._cx + 6; y: parent._cy }     // east shoulder
                PathLine { x: parent._cx;     y: parent._cy }     // back to centre
                PathLine { x: parent._cx - 6; y: parent._cy }     // west shoulder
                PathLine { x: parent._cx;     y: 6 }              // close
            }
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: System.textMuted
                startX: parent._cx; startY: parent.height - 6   // tip (bottom)
                PathLine { x: parent._cx + 5; y: parent._cy }
                PathLine { x: parent._cx;     y: parent._cy }
                PathLine { x: parent._cx - 5; y: parent._cy }
                PathLine { x: parent._cx;     y: parent.height - 6 }
            }
        }

        // Pivot pin in the centre of the needle.
        Rectangle {
            anchors.centerIn: parent
            width: 4; height: 4
            radius: 2
            color: System.textPrimary
        }

        // Tiny N marker just outside the dial top.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: -3
            text: "N"
            color: System.accent
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
