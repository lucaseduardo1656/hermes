import QtQuick
import Elise

// Base row for use inside a SettingsCard. Hosts a label on the left and a
// trailing slot on the right. Concrete rows (toggle, action, value display)
// build on top of this.
//
// Hairline divider draws automatically when this row is not the first child.
Item {
    id: root

    property string label
    property string sublabel: ""
    default property alias trailing: _trailing.data

    width:  parent ? parent.width : 0
    height: Theme.settingsRowH

    // Hairline divider (top edge); hidden if this row is the first sibling
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right
                  leftMargin: Theme.spaceL; rightMargin: Theme.spaceL }
        height: Theme.borderHairline
        color:  System.border
        visible: root.parent && root.parent.children[0] !== root
    }

    Column {
        anchors {
            verticalCenter: parent.verticalCenter
            left:  parent.left; leftMargin: Theme.spaceL
            right: _trailing.left; rightMargin: Theme.spaceM
        }
        spacing: 2

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
    }
}
