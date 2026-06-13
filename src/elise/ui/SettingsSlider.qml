import QtQuick
import Elise

// Volume/level slider row for SettingsCard.
// Label + live value on top, draggable track below.
// Height is taller than a standard row to fit both rows.
Item {
    id: root

    property string label: ""
    property int    value: 50
    property int    from:  0
    property int    to:    100

    signal moved(int value)

    width:  parent ? parent.width : 0
    height: 72

    // Hairline divider — same first-child detection as SettingsRow.
    Rectangle {
        anchors {
            top: parent.top
            left: parent.left;  leftMargin:  Theme.spaceL
            right: parent.right; rightMargin: Theme.spaceL
        }
        height:  Theme.borderHairline
        color:   System.border
        visible: root.parent && root.parent.children[0] !== root
    }

    // Label (left) + current value (right)
    Item {
        id: _labelRow
        anchors {
            top: parent.top; topMargin: 14
            left: parent.left;  leftMargin:  Theme.spaceL
            right: parent.right; rightMargin: Theme.spaceL
        }
        height: Theme.fontLabel + 2

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text:  root.label
            color: System.textPrimary
            font.pixelSize: Theme.fontLabel
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text:  root.value + "%"
            color: System.accent
            font.pixelSize: Theme.fontLabel
            font.weight:    Font.Medium
        }
    }

    // Slider track + thumb
    Item {
        id: _slider
        anchors {
            top: _labelRow.bottom; topMargin: 8
            left: parent.left;  leftMargin:  Theme.spaceL
            right: parent.right; rightMargin: Theme.spaceL
        }
        height: 20

        // Track background
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 4; radius: 2
            color: System.surface2

            // Filled portion
            Rectangle {
                readonly property real frac:
                    (root.value - root.from) / Math.max(1, root.to - root.from)
                width:  frac * parent.width
                height: parent.height; radius: parent.radius
                color:  System.accent
            }
        }

        // Thumb
        Rectangle {
            id: _thumb
            readonly property real frac:
                (root.value - root.from) / Math.max(1, root.to - root.from)
            x: frac * (_slider.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 20; radius: 10
            color: System.accent
        }

        MouseArea {
            anchors.fill: parent

            function valueAt(mx) {
                const frac = Math.max(0, Math.min(1, mx / _slider.width))
                return Math.round(root.from + frac * (root.to - root.from))
            }

            onPressed:          (ev) => root.moved(valueAt(ev.x))
            onPositionChanged:  (ev) => { if (pressed) root.moved(valueAt(ev.x)) }
        }
    }
}
