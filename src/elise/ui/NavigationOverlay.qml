import QtQuick
import Elise

// Top-of-screen card showing the next turn-by-turn instruction.
// Visible whenever Nav.active is true.
Item {
    id: root

    property string instruction: Nav.instruction
    property string distance:    Nav.distance
    property string direction:   Nav.direction

    visible: Nav.active

    Rectangle {
        id: card
        anchors {
            top:    parent.top;  topMargin:   Theme.spaceM
            left:   parent.left; leftMargin:  Theme.spaceL
            right:  parent.right; rightMargin: Theme.spaceL
        }
        height: 64
        radius: Theme.radiusL
        color:  System.surface

        // 1px hairline border on top of the card surface
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: System.border
            border.width: 1
        }

        Row {
            anchors { fill: parent; leftMargin: Theme.spaceL; rightMargin: Theme.spaceL }
            spacing: Theme.spaceL

            // Direction badge
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:  40; height: 40
                radius: Theme.radiusM
                color:  Qt.rgba(System.accent.r, System.accent.g, System.accent.b, 0.15)

                SvgIcon {
                    anchors.centerIn: parent
                    source: root.direction === "left"  ? "qrc:/icons/arrow-left.svg"
                          : root.direction === "right" ? "qrc:/icons/arrow-right.svg"
                          :                              "qrc:/icons/arrow-straight.svg"
                    color: System.accent
                    size:  Theme.iconM
                }
            }

            // Instruction + distance
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text:  root.instruction
                    color: System.textPrimary
                    font.pixelSize: Theme.fontBody
                    font.weight:    Font.Medium
                    elide: Text.ElideRight
                    width: card.width - 100
                }
                Text {
                    text:  root.distance
                    color: System.accent
                    font.pixelSize: Theme.fontSmall
                    font.weight:    Font.Medium
                }
            }
        }

        Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
    }
}
