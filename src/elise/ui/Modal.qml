import QtQuick
import Elise

// Standard centered modal — a dimmed backdrop over a surface card that scales +
// fades in (Caelestia's dialog motion). Sizes to its content. This is the app's
// canonical floating-dialog style (e.g. the Wi-Fi password entry).
//
// Usage:
//   Modal {
//       open: someState
//       onDismissed: someState = false      // backdrop tap
//       Column { ... }                       // content in the default slot
//   }
Item {
    id: root
    anchors.fill: parent

    property bool open: false
    property bool dismissable: true
    property real cardWidth: 400
    property real padding: Tokens.padding.large
    signal dismissed()

    default property alias content: _holder.data
    readonly property alias contentItem: _holder

    visible: _card.opacity > 0.01

    // Dim backdrop.
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        opacity: root.open ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        MouseArea { anchors.fill: parent; enabled: root.open
                    onClicked: if (root.dismissable) root.dismissed() }
    }

    // Centered card.
    Rectangle {
        id: _card
        anchors.centerIn: parent
        width:  root.cardWidth
        height: _holder.childrenRect.height + root.padding * 2
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainer
        border.color: Colours.palette.m3outlineVariant
        border.width: 1

        opacity: root.open ? 1 : 0
        scale:   root.open ? 1 : 0.7
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        Behavior on scale   { Anim {} }

        // Swallow taps so they don't reach the backdrop.
        MouseArea { anchors.fill: parent; onClicked: {} }

        Item {
            id: _holder
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                margins: root.padding
            }
            implicitHeight: childrenRect.height
        }
    }
}
