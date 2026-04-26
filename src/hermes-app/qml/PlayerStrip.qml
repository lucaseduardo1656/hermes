import QtQuick

Rectangle {
    id: root
    color: Theme.surface

    signal expandRequested()

    property string trackTitle:  qsTr("No track playing")
    property string trackArtist: ""
    property bool   playing:     false
    property real   progress:    0.0

    // Top border
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1; color: Theme.border
    }

    // Electric Blue progress bar
    Rectangle {
        anchors { top: parent.top; left: parent.left }
        width: parent.width * root.progress; height: 2
        color: Theme.accent
        Behavior on width { NumberAnimation { duration: 500 } }
    }

    Item {
        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }

        // Artwork thumbnail
        Rectangle {
            id: artThumb
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 40; height: 40; radius: 4
            color: Theme.surface2

            Text {
                anchors.centerIn: parent; text: "♪"
                font.pixelSize: 16; color: Theme.textMuted; opacity: 0.5
            }
        }

        // Playback controls
        Row {
            id: controls
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 4

            Item {
                width: 36; height: 36
                Rectangle {
                    anchors.fill: parent; radius: 4
                    color: prevArea.pressed ? Theme.surface2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 330 } }
                }
                Image { anchors.centerIn: parent; source: "qrc:/icons/skip-back.svg"; width: 18; height: 18; opacity: 0.7 }
                MouseArea { id: prevArea; anchors.fill: parent }
            }

            Rectangle {
                width: 40; height: 40; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: playArea.pressed ? "#2F5AC7" : Theme.accent
                Behavior on color { ColorAnimation { duration: 330 } }

                Image {
                    anchors.centerIn: parent
                    source: root.playing ? "qrc:/icons/pause.svg" : "qrc:/icons/play.svg"
                    width: 18; height: 18
                }
                MouseArea { id: playArea; anchors.fill: parent; onClicked: root.playing = !root.playing }
            }

            Item {
                width: 36; height: 36
                Rectangle {
                    anchors.fill: parent; radius: 4
                    color: nextArea.pressed ? Theme.surface2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 330 } }
                }
                Image { anchors.centerIn: parent; source: "qrc:/icons/skip-forward.svg"; width: 18; height: 18; opacity: 0.7 }
                MouseArea { id: nextArea; anchors.fill: parent }
            }
        }

        // Track info
        Column {
            anchors {
                left: artThumb.right; leftMargin: 12
                right: controls.left; rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            Text {
                text: root.trackTitle
                color: Theme.textPrimary; font.pixelSize: 13; font.weight: Font.Medium
                elide: Text.ElideRight; width: parent.width
            }
            Text {
                text: root.trackArtist || qsTr("Unknown")
                color: Theme.textMuted; font.pixelSize: 11
                elide: Text.ElideRight; width: parent.width
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.expandRequested()
    }
}
