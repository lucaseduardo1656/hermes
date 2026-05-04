import QtQuick
import Elise

// Tappable settings row with a chevron-right affordance.
//
// Usage:
//   SettingsAction {
//       label: "Trocar perfil"
//       onTriggered: ...
//   }
SettingsRow {
    id: root

    signal triggered()

    SvgIcon {
        anchors.verticalCenter: parent.verticalCenter
        source: "qrc:/icons/chevron-right.svg"
        color:  System.textMuted
        size:   Theme.iconXS
    }

    MouseArea {
        anchors.fill: parent
        onClicked:    root.triggered()
        // Pressed-state tint covering the row
        Rectangle {
            anchors.fill: parent
            color:   parent.pressed ? System.pressOverlay : "transparent"
            z:      -1
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }
    }
}
