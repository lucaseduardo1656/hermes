import QtQuick
import Elise

// Vertical list of tracks shown in the expanded PlayerCard. Either the
// current queue or search results, controlled by `showingResults`.
//
// Track shape (from PlayerController / hermes-music daemon):
//   { id, source, title, artist, album, duration_ms, artwork, ... }
Item {
    id: root

    property string heading: ""         // section title shown above the list
    property var    tracks: []          // QVariantList<QVariantMap>
    property int    currentIndex: -1    // highlighted row (queue's playing track)

    signal trackTapped(int index)

    implicitHeight: _col.implicitHeight

    Column {
        id: _col
        width: parent.width
        spacing: Theme.spaceM

        Text {
            width: parent.width
            text:  root.heading
            color: Colours.palette.m3onSurface
            font.pixelSize:    Theme.fontLabel
            font.weight:       Font.Medium
            font.letterSpacing: 1
        }

        Repeater {
            model: root.tracks
            delegate: Item {
                required property var   modelData
                required property int   index
                readonly property bool isCurrent: index === root.currentIndex

                width:  parent.width
                height: 64

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusM
                    color:  _tap.pressed ? System.pressOverlay
                          : isCurrent     ? Colours.palette.m3surfaceContainerHigh
                          : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }

                Row {
                    anchors {
                        left: parent.left;  leftMargin:  Theme.spaceM
                        right: _dur.left;   rightMargin: Theme.spaceM
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.spaceM

                    Rectangle {
                        width:  48; height: 48; radius: Theme.radiusS
                        color:  Colours.palette.m3surfaceContainerHigh
                        anchors.verticalCenter: parent.verticalCenter

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
                            size:   Theme.iconS
                            visible: (modelData.artwork || "") === ""
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48 - Theme.spaceM
                        spacing: 2

                        Text {
                            width: parent.width
                            text:  modelData.title || "—"
                            color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            font.pixelSize: Theme.fontBody
                            font.weight:    Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text:  modelData.artist || ""
                            color: Colours.palette.m3outline
                            font.pixelSize: Theme.fontCaption
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    id: _dur
                    anchors {
                        right: parent.right; rightMargin: Theme.spaceM
                        verticalCenter: parent.verticalCenter
                    }
                    text:  _fmtMs(modelData.duration_ms || 0)
                    color: Colours.palette.m3outline
                    font.pixelSize: Theme.fontCaption
                }

                MouseArea {
                    id: _tap
                    anchors.fill: parent
                    onClicked: root.trackTapped(index)
                }
            }
        }
    }

    function _fmtMs(ms) {
        if (!ms || ms <= 0) return ""
        const total = Math.floor(ms / 1000)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }
}
