import QtQuick
import Elise

// Grouped section card. Holds a heading and a vertical stack of rows.
//
// Usage:
//   SettingsCard {
//       title: "Conta Elise"
//       SettingsAction { label: "Status de login" ... }
//       SettingsToggle { label: "Sincronização" ... }
//   }
//
// All children land in `_body` (a Column), separated by hairline dividers
// drawn between adjacent rows.
Column {
    id: root

    property string title: ""
    default property alias content: _body.data

    spacing: Theme.spaceS
    width: parent ? parent.width : 0

    // Section heading (uppercase label)
    Text {
        visible: root.title !== ""
        text:  root.title.toUpperCase()
        color: System.textSecondary
        font.pixelSize:    Theme.fontCaption
        font.weight:       Font.Medium
        font.letterSpacing: 1
    }

    // Rounded container for the rows
    Rectangle {
        width:  parent.width
        height: _body.implicitHeight
        radius: Theme.radiusM
        color:  System.surface2

        Column {
            id: _body
            anchors.fill: parent
            spacing: 0
        }
    }
}
