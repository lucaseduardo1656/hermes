import QtQuick
import Elise

// Renderer for the global `ActionSheet` singleton. Dim overlay + bottom
// sheet card with the items. Tap outside or pick an item to dismiss.
Item {
    id: root
    anchors.fill: parent
    visible: ActionSheet.active

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        MouseArea { anchors.fill: parent; onClicked: ActionSheet.dismiss() }
    }

    Rectangle {
        id: _sheet
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter:   parent.verticalCenter
        }
        width:  Math.min(parent.width - Theme.spaceXXL * 2, 480)
        height: _col.implicitHeight + Theme.spaceL * 2
        radius: Theme.radiusL
        color:  Colours.palette.m3surfaceContainer
        border.color: Colours.palette.m3outlineVariant
        border.width: Theme.borderHairline

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: _col
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: Theme.spaceL
            }
            spacing: 0

            StyledText {
                text: ActionSheet.title
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Theme.fontSmall
                visible: ActionSheet.title !== ""
                bottomPadding: Theme.spaceM
            }

            Repeater {
                model: ActionSheet.items
                Rectangle {
                    width: parent.width
                    height: 56
                    color: _itemArea.pressed ? System.pressOverlay : "transparent"

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: Theme.borderHairline
                        color:  Colours.palette.m3outlineVariant
                        visible: index > 0
                    }

                    StyledText {
                        anchors {
                            left: parent.left; leftMargin: Theme.spaceM
                            right: parent.right; rightMargin: Theme.spaceM
                            verticalCenter: parent.verticalCenter
                        }
                        text:  modelData.label
                        color: modelData.destructive ? Colours.palette.m3error : Colours.palette.m3onSurface
                        font.pixelSize: Theme.fontMedium
                        font.weight: modelData.destructive ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: _itemArea
                        anchors.fill: parent
                        onClicked: ActionSheet.pick(index)
                    }
                }
            }
        }
    }
}
