import QtQuick
import Elise

// Header at the top of the settings sidebar.
//
// Layout:
//   [Avatar] Name ▼                                          [📶]
//
// Avatar + name + chevron form a single tappable area that emits
// `profileMenuRequested()` (host wires this to a profile picker later).
// The connectivity icon recolors itself based on `connOnline`.
Item {
    id: root

    // ── Public props ─────────────────────────────────────────────────────────
    property string userName:   "Convidado"
    property bool   connOnline: false
    signal profileMenuRequested()

    width:  parent ? parent.width : 0
    height: 64

    // ── Profile chip (left) ──────────────────────────────────────────────────
    Row {
        id: _profile
        anchors {
            verticalCenter: parent.verticalCenter
            left:  parent.left;  leftMargin:  Theme.spaceL
            right: _connectivity.left; rightMargin: Theme.spaceM
        }
        spacing: Theme.spaceM

        Rectangle {
            id: _avatar
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: System.surface2
            SvgIcon {
                anchors.centerIn: parent
                source: "qrc:/icons/user.svg"
                color:  System.textSecondary
                size:   Theme.iconS
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXS

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  root.userName
                color: System.textPrimary
                font.pixelSize: Theme.fontLabel
                font.weight:    Font.Medium
                elide: Text.ElideRight
            }
            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/icons/chevron-down.svg"
                color:  System.textSecondary
                size:   Theme.iconXS
            }
        }
    }

    MouseArea {
        anchors.fill: _profile
        onClicked:    root.profileMenuRequested()
    }

    // ── Connectivity icon (right) ────────────────────────────────────────────
    Item {
        id: _connectivity
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right; rightMargin: Theme.spaceL
        }
        width:  Theme.iconM
        height: Theme.iconM

        SvgIcon {
            anchors.centerIn: parent
            source: "qrc:/icons/wifi.svg"
            color:  root.connOnline ? System.accent : System.textMuted
            size:   Theme.iconS
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }
    }

    // ── Bottom hairline divider ──────────────────────────────────────────────
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.borderHairline
        color:  System.border
    }
}
