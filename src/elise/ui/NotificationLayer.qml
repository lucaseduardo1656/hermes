import QtQuick
import Elise

// Top-anchored toast stack. Newest notification appears at the top, slides in
// from above, then auto-dismisses with a fade after `_dismissDelayMs`.
//
// Public API: call `show(message, type)` from outside.
//   type ∈ { "info" (default), "warning", "error" }
Item {
    id: root

    readonly property int _dismissDelayMs: 4000

    function show(message, type) {
        _model.insert(0, { message: message, type: type || "info", uid: Date.now() })
    }

    ListModel { id: _model }

    Column {
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            topMargin: Theme.spaceS
        }
        spacing: Theme.toastSpacing

        Repeater {
            model: _model

            delegate: Rectangle {
                id: notif
                required property string message
                required property string type
                required property var    uid
                required property int    index

                width:  parent.width - Theme.space3XL
                x:      Theme.spaceL
                height: Theme.toastH
                radius: Theme.radiusM

                color: notif.type === "error"   ? "#3A1515"
                     : notif.type === "warning" ? "#3A2D10"
                     :                            System.surface2

                border.color: notif.type === "error"   ? "#8B3333"
                            : notif.type === "warning" ? "#8B6A1A"
                            :                            System.border
                border.width: 1
                opacity: 1.0

                Text {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left:  parent.left;  leftMargin:  Theme.spaceL
                        right: closeBtn.left; rightMargin: Theme.spaceS
                    }
                    text:  notif.message
                    color: System.textPrimary
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: closeBtn
                    anchors {
                        right: parent.right; rightMargin: Theme.spaceM
                        verticalCenter: parent.verticalCenter
                    }
                    width: 24; height: 24; radius: Theme.radiusS / 2
                    color: closeArea.pressed ? System.pressOverlay : "transparent"

                    SvgIcon {
                        anchors.centerIn: parent
                        source: "qrc:/icons/close.svg"
                        color:  System.textSecondary
                        size:   Theme.iconXS - 2
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        onClicked: _model.remove(notif.index)
                    }
                }

                // Auto-dismiss
                Timer {
                    interval: root._dismissDelayMs
                    running:  true
                    repeat:   false
                    onTriggered: fadeOut.start()
                }

                NumberAnimation on opacity {
                    id: fadeOut
                    to: 0; duration: Theme.durSlower; easing.type: Easing.OutCubic
                    onStopped: _model.remove(notif.index)
                }

                // Slide in from above
                NumberAnimation on y {
                    from: -Theme.toastSlideOffset; to: 0
                    duration: Theme.durSlow
                    easing.type: Easing.OutCubic
                    running: true
                }
            }
        }
    }
}
