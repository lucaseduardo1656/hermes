import QtQuick
import Elise

// Horizontal carousel of track cards. One row per home section; the
// expanded PlayerCard stacks several of these vertically (Spotify /
// YT Music style). Tap a card → emits `trackTapped(index)`.
//
// Track shape (from PlayerController / hermes-music daemon):
//   { id, source, title, artist, album, duration_ms, artwork, ... }
Item {
    id: root

    property string heading: ""
    property var    tracks: []
    property int    currentIndex: -1
    property real   cardW: Theme.carouselCardW
    property real   cardH: cardW + 48   // artwork + 2 lines of text

    signal trackTapped(int index)

    implicitHeight: _heading.height + _list.height + Theme.spaceM

    Text {
        id: _heading
        anchors { left: parent.left; right: parent.right }
        text: root.heading
        color: Colours.palette.m3onSurface
        font.pixelSize:     Theme.fontLabel
        font.weight:        Font.Medium
        font.letterSpacing: 1
    }

    ListView {
        id: _list
        anchors {
            left: parent.left; right: parent.right
            top: _heading.bottom; topMargin: Theme.spaceM
        }
        height: root.cardH
        model: root.tracks
        orientation: ListView.Horizontal
        spacing: Theme.spaceM
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500

        delegate: Item {
            required property var modelData
            required property int index
            readonly property bool isCurrent: index === root.currentIndex

            width:  root.cardW
            height: root.cardH

            Column {
                anchors.fill: parent
                spacing: Theme.spaceS

                Rectangle {
                    width:  root.cardW
                    height: root.cardW
                    radius: Theme.radiusM
                    color:  isCurrent ? Colours.palette.m3surfaceContainerHigh
                          : _tap.pressed ? System.pressOverlay
                          : Colours.palette.m3surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Image {
                        anchors.fill: parent
                        source:   modelData.artwork || ""
                        fillMode: Image.PreserveAspectCrop
                        visible:  (modelData.artwork || "") !== ""
                        asynchronous: true
                    }
                    SvgIcon {
                        anchors.centerIn: parent
                        source: "qrc:/icons/music-note.svg"
                        color:  Colours.palette.m3outline
                        size:   Theme.iconL
                        visible: (modelData.artwork || "") === ""
                    }
                }

                Text {
                    width: root.cardW
                    text:  modelData.title || "—"
                    color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
                    font.pixelSize: Theme.fontBody
                    font.weight:    Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    width: root.cardW
                    text:  modelData.artist || ""
                    color: Colours.palette.m3outline
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: _tap
                anchors.fill: parent
                onClicked: root.trackTapped(index)
            }
        }
    }
}
