import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: Theme.background

    MouseArea { anchors.fill: parent }

    property string source:      "local"
    property bool   playing:     false
    property real   progress:    0.0
    property string trackTitle:  qsTr("No track playing")
    property string trackArtist: ""

    // ── Artwork panel (left 42%) ──────────────────────────────────
    Item {
        id: leftPanel
        anchors { top: parent.top; left: parent.left; bottom: sourceBar.top }
        width: parent.width * 0.42

        Rectangle {
            id: artwork
            anchors.centerIn: parent
            width:  Math.min(leftPanel.width - 48, leftPanel.height - 48)
            height: width
            radius: 12
            color:  Theme.surface2

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: Math.floor(artwork.width * 0.38)
                color: Theme.textMuted; opacity: 0.3
            }
        }
    }

    // ── Source tab bar ────────────────────────────────────────────
    Rectangle {
        id: sourceBar
        anchors { bottom: parent.bottom; left: parent.left }
        width: leftPanel.width; height: 52
        color: Theme.surface

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1; color: Theme.border
        }

        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 6

            Repeater {
                model: [
                    { id: "local",   label: "Local"   },
                    { id: "spotify", label: "Spotify" },
                    { id: "youtube", label: "YouTube" }
                ]

                Rectangle {
                    required property var modelData
                    width: 68; height: 28; radius: 4
                    color: root.source === modelData.id ? Theme.accent : Theme.surface2
                    Behavior on color { ColorAnimation { duration: 330 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.source === modelData.id ? "#FFFFFF" : Theme.textMuted
                        font.pixelSize: 12; font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 330 } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.source = modelData.id }
                }
            }
        }
    }

    // ── Vertical divider ─────────────────────────────────────────
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; left: leftPanel.right }
        width: 1; color: Theme.border
    }

    // ── Right panel: player controls ─────────────────────────────
    Column {
        anchors {
            left: leftPanel.right; leftMargin: 40
            right: parent.right; rightMargin: 40
            verticalCenter: parent.verticalCenter
        }
        spacing: 28

        Column {
            width: parent.width; spacing: 6

            Text {
                text: root.trackTitle
                color: Theme.textPrimary
                font.pixelSize: 22; font.weight: Font.Medium
                elide: Text.ElideRight; width: parent.width
            }
            Text {
                text: root.trackArtist || qsTr("Unknown artist")
                color: Theme.textMuted
                font.pixelSize: 14; font.weight: Font.Normal
                elide: Text.ElideRight; width: parent.width
            }
        }

        Column {
            width: parent.width; spacing: 8

            Rectangle {
                id: progressTrack
                width: parent.width; height: 3; radius: 1.5
                color: Theme.surface2

                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height; radius: 1.5; color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 500 } }
                }

                Rectangle {
                    x: progressTrack.width * root.progress - 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12; radius: 6
                    color: Theme.accent
                    visible: scrubArea.containsPress
                }

                MouseArea {
                    id: scrubArea
                    anchors { fill: parent; topMargin: -18; bottomMargin: -18 }
                    onPressed: root.progress = Math.max(0.0, Math.min(1.0, mouseX / progressTrack.width))
                    onPositionChanged: if (pressed) root.progress = Math.max(0.0, Math.min(1.0, mouseX / progressTrack.width))
                }
            }

            Row {
                width: parent.width

                Text { text: "0:00"; color: Theme.textMuted; font.pixelSize: 11 }
                Item { width: parent.width - 80; height: 1 }
                Text {
                    text: "--:--"; color: Theme.textMuted; font.pixelSize: 11
                    width: 40; horizontalAlignment: Text.AlignRight
                }
            }
        }

        // Playback controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Item {
                width: 44; height: 44; anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent; radius: 4
                    color: prevArea.pressed ? Theme.surface2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 330 } }
                }
                Image { anchors.centerIn: parent; source: "qrc:/icons/skip-back.svg"; width: 22; height: 22; opacity: 0.75 }
                MouseArea { id: prevArea; anchors.fill: parent }
            }

            Rectangle {
                width: 56; height: 56; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: playArea.pressed ? "#2F5AC7" : Theme.accent
                Behavior on color { ColorAnimation { duration: 330 } }

                Image {
                    anchors.centerIn: parent
                    source: root.playing ? "qrc:/icons/pause.svg" : "qrc:/icons/play.svg"
                    width: 24; height: 24
                }
                MouseArea { id: playArea; anchors.fill: parent; onClicked: root.playing = !root.playing }
            }

            Item {
                width: 44; height: 44; anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent; radius: 4
                    color: nextArea.pressed ? Theme.surface2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 330 } }
                }
                Image { anchors.centerIn: parent; source: "qrc:/icons/skip-forward.svg"; width: 22; height: 22; opacity: 0.75 }
                MouseArea { id: nextArea; anchors.fill: parent }
            }
        }

        // Volume
        Row {
            width: parent.width; spacing: 10

            Image {
                source: "qrc:/icons/volume-2.svg"; width: 16; height: 16
                opacity: 0.4; anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                id: volTrack
                width: parent.width - 26 - 10; height: 3; radius: 1.5
                color: Theme.surface2; anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * 0.7; height: parent.height; radius: parent.radius
                    color: Theme.border2
                }
            }
        }
    }

    Text {
        anchors { right: parent.right; bottom: parent.bottom; margins: 16 }
        text: qsTr("Queue coming soon")
        color: Theme.textDisabled; font.pixelSize: 10; font.letterSpacing: 0.8
    }
}
