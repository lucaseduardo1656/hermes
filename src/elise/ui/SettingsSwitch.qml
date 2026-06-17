import QtQuick
import Elise

// Standalone on/off switch (the pill used in settings headers). Drives the
// caller's source-of-truth via `toggled` — never writes `checked` itself, so
// it stays bound to backend state.
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool value)

    width:  48
    height: 26
    radius: height / 2
    color: root.checked ? System.accent : System.surface2
    border.color: root.checked ? System.accent : System.border
    border.width: 1
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    Rectangle {
        id: _knob
        width: 18; height: 18; radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 4 : 4
        color: root.checked ? "#1A1A1A" : System.textSecondary
        Behavior on x     { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation  { duration: Theme.durFast } }
    }

    MouseArea { anchors.fill: parent; onClicked: root.toggled(!root.checked) }
}
