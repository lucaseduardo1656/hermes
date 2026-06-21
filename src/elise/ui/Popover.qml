import QtQuick
import Elise

// Reusable floating card / popover — the single standard for transient floating
// surfaces (weather detail, POI info, quick menus). Built from the same pieces
// as Caelestia's dashboard cards: an M3 surface with an Elevation shadow that
// sizes to its content and animates in with a scale + fade (Emphasized motion)
// from `originCorner`.
//
// Usage:
//   Popover {
//       open: someState
//       Column { ... }          // content goes in the default slot
//   }
Item {
    id: root

    // Drives the show/hide animation.
    property bool open: false
    // Inner padding around the content.
    property real padding: Theme.spaceL
    // Where the entrance scale grows from (point the popover is anchored to).
    property int originCorner: Item.Top

    default property alias content: _holder.data
    readonly property alias contentItem: _holder

    // Size to the content (+ padding) so text never truncates unexpectedly.
    implicitWidth:  _holder.childrenRect.width  + padding * 2
    implicitHeight: _holder.childrenRect.height + padding * 2
    visible: _surface.opacity > 0.01

    Rectangle {
        id: _surface
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainer
        border.color: Colours.palette.m3outlineVariant
        border.width: 1

        transformOrigin: root.originCorner
        opacity: root.open ? 1 : 0
        scale:   root.open ? 1 : 0.92

        Behavior on opacity { Anim { type: Anim.FastEffects } }
        Behavior on scale   { Anim { type: Anim.Emphasized } }
    }

    Item {
        id: _holder
        anchors { fill: parent; margins: root.padding }
        opacity: _surface.opacity
    }
}
