import QtQuick
import Elise

// Base row for use inside a SettingsCard. Hosts a label on the left and a
// trailing slot on the right. Concrete rows (toggle, action, value display)
// build on top of this.
//
// Set `interactive: true` to enable a row-level MouseArea that emits
// `clicked()` when the user taps anywhere on the row. Keep it `false` for
// rows whose interactivity lives in their own widget (e.g. the toggle
// track) so taps don't double-fire.
//
// Hairline divider draws automatically when this row is not the first child.
Item {
    id: root

    property string label
    property string sublabel:    ""
    property bool   interactive: false
    signal clicked()

    default property alias trailing: _trailing.data

    width:  parent ? parent.width : 0
    height: Theme.settingsRowH

    // Row-level tap surface. Sits at the bottom of the stack so trailing
    // widgets (e.g. a toggle track) get first dibs while the rest of the
    // row falls through to here.
    MouseArea {
        id: _tap
        anchors.fill: parent
        enabled: root.interactive
        onClicked: root.clicked()
        z: 0
    }

    // Pressed-state tint (only when interactive).
    Rectangle {
        anchors.fill: parent
        color:   _tap.pressed ? System.pressOverlay : "transparent"
        visible: root.interactive
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        z: 1
    }

    // Hairline divider (top edge); hidden if this row is the first sibling
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right
                  leftMargin: Theme.spaceL; rightMargin: Theme.spaceL }
        height: Theme.borderHairline
        color:  System.border
        visible: root.parent && root.parent.children[0] !== root
        z: 2
    }

    Column {
        anchors {
            verticalCenter: parent.verticalCenter
            left:  parent.left; leftMargin: Theme.spaceL
            right: _trailing.left; rightMargin: Theme.spaceM
        }
        spacing: 2
        z: 3

        Text {
            text:  root.label
            color: System.textPrimary
            font.pixelSize: Theme.fontLabel
            elide: Text.ElideRight; width: parent.width
        }
        Text {
            visible: root.sublabel !== ""
            text:  root.sublabel
            color: System.textMuted
            font.pixelSize: Theme.fontCaption
            elide: Text.ElideRight; width: parent.width
        }
    }

    Item {
        id: _trailing
        anchors {
            right: parent.right; rightMargin: Theme.spaceL
            verticalCenter: parent.verticalCenter
        }
        width:  childrenRect.width
        height: parent.height
        z: 4
    }
}
