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
        // Card style — same fixed width as the search bar so the two
        // top-anchored chips visually align. Height grows with the
        // instruction text when it wraps.
        anchors {
            top:  parent.top; topMargin:  Theme.spaceM
            left: parent.left; leftMargin: Theme.spaceL
        }
        width:  320
        height: Math.max(Theme.navCardH, _row.implicitHeight + Theme.spaceL)
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
            id: _row
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.spaceM; rightMargin: Theme.spaceM
            }
            spacing: Theme.spaceM

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:  Theme.navBadge
                height: Theme.navBadge
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

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.navBadge - Theme.spaceM
                spacing: 3

                Text {
                    text:  root.instruction
                    color: System.textPrimary
                    font.pixelSize: Theme.fontBody
                    font.weight:    Font.Medium
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
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
