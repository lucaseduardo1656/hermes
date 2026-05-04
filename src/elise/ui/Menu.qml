import QtQuick
import Elise

// Reusable full-screen menu surface.
//
// Animates in from the bottom (y = parent.height → 0) when `open` becomes true.
// A small drag pill at the top center acts as both visual affordance and
// gesture target — pulling the top region down by more than 30% of viewport
// height dismisses the menu.
//
// No header bar, no built-in close button: content fills the full surface so
// pages can use every pixel from the top. If you need an explicit close, put
// one in your own content.
//
//   Menu {
//       open: someState
//       Item { anchors.fill: parent /* your content */ }
//   }
Item {
    id: root

    // ── Public API ────────────────────────────────────────────────────────────
    property bool open: false
    default property alias content: _contentArea.data
    signal closed()

    function close() {
        if (open) { open = false; closed() }
    }

    // ── Drag state ────────────────────────────────────────────────────────────
    property real _liveY:    0
    property bool _dragging: false

    // Position: y = 0 when open, off-screen below when closed.
    // While dragging, _liveY tracks the finger.
    y: _dragging ? _liveY : (open ? 0 : parent.height)
    Behavior on y {
        enabled: !root._dragging
        NumberAnimation { duration: Theme.durSlow; easing.type: Easing.InOutCubic }
    }

    width:  parent.width
    height: parent.height
    visible: y < parent.height       // hide entirely once fully off-screen

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: System.surface
    }

    // ── Content slot — fills the entire menu surface ─────────────────────────
    Item {
        id: _contentArea
        anchors.fill: parent
    }

    // ── Drag affordance (top strip) ──────────────────────────────────────────
    // Floats above content so taps in the top strip become drag gestures
    // instead of falling through. The pill itself is purely cosmetic.
    Item {
        id: _dragZone
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.spaceXXL    // ~24 px hit target
        z: 10

        Rectangle {
            anchors { top: parent.top; topMargin: Theme.spaceS
                      horizontalCenter: parent.horizontalCenter }
            width:  Theme.dragPillW
            height: Theme.dragPillH
            radius: Theme.dragPillR
            color:  System.border
        }

        DragHandler {
            target: null
            yAxis.enabled: true
            xAxis.enabled: false

            property real _startY: 0

            onActiveChanged: {
                if (active) {
                    _startY = root.y
                    root._liveY = root.y
                    root._dragging = true
                } else {
                    root._dragging = false
                    const dragged = root._liveY - _startY
                    if (dragged > root.height * 0.3) root.close()
                }
            }
            onTranslationChanged: {
                root._liveY = Math.max(0, _startY + translation.y)
            }
        }
    }
}
