import QtQuick
import QtQuick.Layouts
import Elise

// Top-right toast stack, rendering the Notifs backend. Each toast mirrors the
// Caelestia notification card: a circular coloured icon badge, a header line of
// "summary • time" with an expand chevron, and a body preview that grows when
// expanded (where action buttons also appear). Hover/expand pauses the
// auto-dismiss; the close action dismisses.
//
// Note: Caelestia's notifications visually tuck into the shell's rounded
// screen-border frame (a compositor-level decoration the shell owns). This app
// is a single fullscreen surface, so it renders free-floating cards instead of
// connecting to a screen frame.
//
// Public API kept for existing callers: show(message, type) → Notifs urgency.
Item {
    id: root

    function show(message, type) {
        const u = type === "error" ? 2 : type === "warning" ? 1 : 0
        Notifs.notify(message, "", u)
    }

    // Off-screen helper for the copy action (no system clipboard binding here).
    TextEdit { id: _clip; visible: false }

    ListView {
        id: _list
        anchors {
            top: parent.top; right: parent.right
            topMargin: Theme.spaceL; rightMargin: Theme.spaceL
        }
        width: Math.min(380, parent.width - Theme.space3XL)
        height: Math.min(parent.height - Theme.space3XL, contentHeight)
        spacing: Tokens.spacing.medium
        interactive: false
        model: Notifs.model

        // Caelestia notification motion: slide in from the right, slide out on
        // dismiss, and smoothly reflow (displaced) when one above is removed.
        add: Transition {
            Anim { property: "x"; from: _list.width; to: 0; easing: Tokens.anim.emphasizedDecel }
            Anim { property: "opacity"; from: 0; to: 1; type: Anim.DefaultEffects }
        }
        remove: Transition {
            // Both run for the same duration so the card slides out and fades
            // together (Caelestia's single emphasized exit).
            Anim { property: "x"; to: _list.width; duration: Tokens.anim.durations.normal; easing: Tokens.anim.emphasized }
            Anim { property: "opacity"; to: 0; duration: Tokens.anim.durations.normal; easing: Tokens.anim.emphasized }
        }
        displaced: Transition {
            Anim { property: "y"; type: Anim.DefaultSpatial }
            Anim { property: "opacity"; to: 1; type: Anim.DefaultEffects }
        }
        move: Transition {
            Anim { property: "y"; type: Anim.DefaultSpatial }
        }

        delegate: Rectangle {
                id: notif
                required property int    uid
                required property string summary
                required property string body
                required property int    urgency
                required property int    index

                readonly property bool _critical: urgency >= 2
                property bool expanded: false

                width:  ListView.view.width
                implicitHeight: _inner.implicitHeight + Tokens.padding.large * 2
                height: implicitHeight
                radius: Tokens.rounding.large
                color: _critical ? Colours.palette.m3secondaryContainer
                                  : Colours.palette.m3surfaceContainer

                Behavior on implicitHeight { Anim {} }

                // Caelestia-style interactions: hover pauses the timer, swipe
                // horizontally to dismiss, drag vertically to expand/collapse,
                // middle-click closes.
                MouseArea {
                    id: _ma
                    property real startY: 0
                    readonly property real clearThreshold: 0.35
                    readonly property real expandThreshold: 24

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    preventStealing: true
                    drag.target: parent
                    drag.axis: Drag.XAxis

                    onEntered: Notifs.pause(notif.uid)
                    onExited:  if (!notif.expanded && !pressed) Notifs.resume(notif.uid)

                    onPressed: e => {
                        Notifs.pause(notif.uid)
                        startY = e.y
                        if (e.button === Qt.MiddleButton) Notifs.dismiss(notif.uid)
                    }
                    onPositionChanged: e => {
                        if (pressed && Math.abs(e.y - startY) > expandThreshold)
                            notif.expanded = (e.y - startY) > 0
                    }
                    onReleased: {
                        if (!containsMouse && !notif.expanded) Notifs.resume(notif.uid)
                        if (Math.abs(notif.x) < notif.width * clearThreshold)
                            notif.x = 0
                        else
                            Notifs.dismiss(notif.uid)
                    }
                }

                RowLayout {
                    id: _inner
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large
                        topMargin: Tokens.padding.large
                    }
                    spacing: Tokens.spacing.medium

                    // Circular coloured icon badge — the visible anchor.
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 38; implicitHeight: 38
                        radius: width / 2
                        color: notif._critical ? Colours.palette.m3primary
                                               : Colours.palette.m3secondaryContainer
                        MaterialIcon {
                            anchors.centerIn: parent
                            symbol: Icons.getNotifIcon(notif.summary, notif.urgency)
                            color: notif._critical ? Colours.palette.m3onPrimary
                                                   : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.small
                            fill: 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Tokens.spacing.extraSmall

                        // Header: summary • agora            [chevron]
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: notif.summary
                                color: notif._critical ? Colours.palette.m3onSecondaryContainer
                                                       : Colours.palette.m3onSurface
                                font.pointSize: Tokens.font.body.medium.pointSize
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                maximumLineCount: notif.expanded ? 2 : 1
                                wrapMode: Text.WordWrap
                            }
                            StyledText {
                                text: "• agora"
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                            MaterialIcon {
                                symbol: notif.expanded ? "expand_less" : "expand_more"
                                color: Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.small
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -6
                                    onClicked: {
                                        notif.expanded = !notif.expanded
                                        if (notif.expanded) Notifs.pause(notif.uid)
                                        else Notifs.resume(notif.uid)
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: notif.body !== ""
                            text: notif.body
                            color: notif._critical ? Colours.palette.m3onSecondaryContainer
                                                   : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            wrapMode: Text.WordWrap
                            maximumLineCount: notif.expanded ? 6 : 2
                            elide: Text.ElideRight
                        }

                        // Action row (expanded only): two full-width pills
                        // (close + copy), matching the Caelestia notification
                        // actions. Colours track urgency.
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Tokens.spacing.small
                            visible: notif.expanded
                            opacity: notif.expanded ? 1 : 0
                            spacing: Tokens.spacing.extraSmall
                            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

                            // Real IconButton (ButtonBase): ripple + radius-morph
                            // press animation, round, full-width — same component
                            // and colours as the Caelestia notification actions.
                            IconButton {
                                Layout.fillWidth: true
                                isRound: true
                                shapeMorph: true
                                fillWidth: true
                                icon: "close"
                                padding: Tokens.padding.extraSmall
                                inactiveColour: notif._critical ? Colours.palette.m3secondary
                                                               : Colours.palette.m3surfaceContainerHighest
                                inactiveOnColour: notif._critical ? Colours.palette.m3onSecondary
                                                                 : Colours.palette.m3onSurfaceVariant
                                onClicked: Notifs.dismiss(notif.uid)
                            }
                            IconButton {
                                Layout.fillWidth: true
                                isRound: true
                                shapeMorph: true
                                fillWidth: true
                                icon: "content_copy"
                                padding: Tokens.padding.extraSmall
                                inactiveColour: notif._critical ? Colours.palette.m3secondary
                                                               : Colours.palette.m3surfaceContainerHighest
                                inactiveOnColour: notif._critical ? Colours.palette.m3onSecondary
                                                                 : Colours.palette.m3onSurfaceVariant
                                onClicked: {
                                    const t = notif.body !== "" ? notif.summary + " — " + notif.body
                                                                : notif.summary
                                    _clip.text = t; _clip.selectAll(); _clip.copy()
                                }
                            }
                        }
                    }
                }
        }
    }
}
