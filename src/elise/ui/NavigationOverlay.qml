import QtQuick
import Elise

// Top-of-screen card showing the next turn-by-turn instruction.
// Visible whenever Nav.active is true.
Item {
    id: root

    property string instruction: Nav.instruction
    property string distance:    Nav.distance
    property string direction:   Nav.direction

    implicitWidth:  card.width
    implicitHeight: card.height

    Rectangle {
        id: card
        // Card style. Width comes from the parent (Main mounts this
        // inside a Column with a fixed-width sibling row). Height
        // grows with the instruction text when it wraps.
        anchors.fill: parent
        height: Math.max(Theme.navCardH, _row.implicitHeight + Theme.spaceL)
        radius: Theme.radiusL
        color:  Colours.palette.m3surfaceContainer

        // 1px hairline border on top of the card surface
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Colours.palette.m3outlineVariant
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
                color:  Qt.alpha(Colours.palette.m3primary, 0.15)
                MaterialIcon {
                    anchors.centerIn: parent
                    symbol: root.direction === "left"  ? "turn_left"
                          : root.direction === "right" ? "turn_right"
                          :                              "straight"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.medium
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.navBadge - Theme.spaceM
                spacing: 3

                StyledText {
                    text:  root.instruction
                    color: Colours.palette.m3onSurface
                    font.pixelSize: Theme.fontBody
                    font.weight:    Font.Medium
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                StyledText {
                    text:  root.distance
                    color: Colours.palette.m3primary
                    font.pixelSize: Theme.fontSmall
                    font.weight:    Font.Medium
                }
            }
        }

        Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
    }
}
