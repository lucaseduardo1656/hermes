import QtQuick
import Elise

// Indeterminate spinner — a rotating arc ring. (Caelestia uses a Material glyph
// spinner, but this Qt build can't render the Material Symbols font, so the
// ring is drawn with plain primitives instead.)
Item {
    id: root

    property int implicitSize: 18
    property color color: Colours.palette.m3primary

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Rectangle {
        id: ring
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, root.implicitSize / 9)
        border.color: root.color

        // A wedge masking the ring so it reads as a moving arc.
        Rectangle {
            width: parent.width * 0.6
            height: parent.height * 0.6
            color: Colours.tPalette.m3surfaceContainer
            anchors { top: parent.top; right: parent.right }
        }

        RotationAnimator on rotation {
            from: 0; to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.visible
        }
    }
}
