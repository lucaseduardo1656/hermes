import QtQuick
import Elise

// Floating Action Button — a circular tappable button used for primary
// secondary actions (e.g. opening Settings).
//
// Usage:
//   Fab {
//       icon: "qrc:/icons/settings.svg"
//       onClicked: ...
//   }
Item {
    id: root

    property url   icon
    property color color: System.accent
    signal clicked()

    readonly property int size: Theme.btnMedium

    width:  size
    height: size

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color:  _area.pressed ? System.accentDim : root.color
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        // Soft shadow ring (subtle elevation)
        border.color: Qt.rgba(0, 0, 0, 0.25)
        border.width: Theme.borderHairline
    }

    SvgIcon {
        anchors.centerIn: parent
        source: root.icon
        color:  "#000000"
        size:   Theme.iconS
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
