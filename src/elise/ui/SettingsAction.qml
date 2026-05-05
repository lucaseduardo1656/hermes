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

    interactive: true
    signal triggered()
    onClicked: root.triggered()

    SvgIcon {
        anchors.verticalCenter: parent.verticalCenter
        source: "qrc:/icons/chevron-right.svg"
        color:  System.textMuted
        size:   Theme.iconXS
    }
}
