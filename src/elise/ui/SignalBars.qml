import QtQuick
import Elise

// Four-bar wifi signal indicator. Bars light up proportionally to
// `strength` (0–100). Driven by RSSI percentage from NetworkController.
Item {
    id: root
    property int  strength: 0
    property bool active:   false      // muted (gray) when not the active connection
    property color tint: active ? System.accent : System.textPrimary
    implicitWidth:  18
    implicitHeight: 14

    Row {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        spacing: 2
        Repeater {
            model: 4
            Rectangle {
                width:  3
                height: 4 + index * 3
                radius: 1
                // Each bar lights at 25/50/75/100% thresholds.
                readonly property bool lit: root.strength >= (index + 1) * 20
                color: lit ? root.tint : Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.25)
                anchors.bottom: parent.bottom
            }
        }
    }
}
