import QtQuick
import Elise

// One row in the settings sidebar: icon + label, with active highlight.
//
// Usage:
//   SettingsSidebarItem {
//       icon:   "qrc:/icons/user.svg"
//       label:  "Perfil"
//       active: settingsRouter.activePage === "perfil"
//       onClicked: settingsRouter.activePage = "perfil"
//   }
Item {
    id: root

    property url    icon
    property string label
    property bool   active: false
    signal clicked()

    width:  parent ? parent.width : 0
    height: Theme.settingsSidebarItem

    Rectangle {
        anchors.fill: parent
        color: root.active        ? System.surface2
             : _area.pressed      ? System.pressOverlay
             :                       "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    // Active state — left accent strip
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width:   3
        color:   System.accent
        opacity: root.active ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    Row {
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left; leftMargin: Theme.spaceL
        }
        spacing: Theme.spaceM

        SvgIcon {
            anchors.verticalCenter: parent.verticalCenter
            source: root.icon
            color:  root.active ? System.textPrimary : System.textSecondary
            size:   Theme.iconS
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:  root.label
            color: root.active ? System.textPrimary : System.textSecondary
            font.pixelSize: Theme.fontLabel
            font.weight:    root.active ? Font.Medium : Font.Normal
        }
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
