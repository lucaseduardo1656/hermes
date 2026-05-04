import QtQuick
import Elise

// Settings row with a binary on/off toggle on the right.
//
// Usage:
//   SettingsToggle {
//       label: "Sincronização"
//       checked: true
//       onToggled: ...
//   }
SettingsRow {
    id: root

    property bool checked: false
    signal toggled(bool value)

    Rectangle {
        id: _track
        anchors.verticalCenter: parent.verticalCenter
        width:  40
        height: 22
        radius: 11
        color:  root.checked ? System.accent : System.surface
        border.color: root.checked ? System.accent : System.border
        border.width: Theme.borderHairline
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Rectangle {
            id: _knob
            width:  16; height: 16; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? "#000000" : System.textSecondary
            Behavior on x     { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation  { duration: Theme.durFast } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.checked = !root.checked
                root.toggled(root.checked)
            }
        }
    }
}
