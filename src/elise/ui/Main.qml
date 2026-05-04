import QtQuick
import QtQuick.VirtualKeyboard
import Elise

// Root window for the Elise infotainment UI.
// Layered, state-driven layout:
//   playerState === "collapsed" → MapView interactive, player is bottom bar
//   playerState === "half"      → player shows compact info row
//   playerState === "expanded"  → player covers full screen
//
// Z-order legend:
//   0     MapView (always behind)
//   50    GlobalInputBlocker (blocks map taps when player is open)
//   600   Floating action button (settings cog) — hidden behind expanded player
//   700   Player card (collapsed / half)
//   800   Navigation overlay (top toast for turn-by-turn)
//   900   Player card (expanded — promoted above nav)
//   1000  Notifications
//   1100  Virtual keyboard
//   1200  Settings menu (full-screen, drag-to-dismiss)
Window {
    id: root
    width: 1024; height: 600
    visible: true
    title: "Elise"
    color: System.background

    // Single source of truth for player state. PlayerCard is purely controlled.
    property string playerState: "collapsed"

    // ── Map ──────────────────────────────────────────────────────────────────
    MapView {
        anchors.fill: parent
        z: 0
        interactive: root.playerState === "collapsed"
    }

    // ── Input blocker (covers only area above the player card) ───────────────
    GlobalInputBlocker {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: parent.height - _player.height
        z: 50
        active: root.playerState !== "collapsed"
        onDismissed: root.playerState = "collapsed"
    }

    // ── Floating action button (settings) ────────────────────────────────────
    // Anchored to the top of the player card so it rises with the bar. Sits
    // below the player in z so the expanded player covers it.
    Fab {
        anchors {
            right:  parent.right; rightMargin: Theme.spaceL
            bottom: _player.top;  bottomMargin: Theme.spaceL
        }
        z: 600
        icon: "qrc:/icons/settings.svg"
        visible: root.playerState !== "expanded"
        onClicked: _settings.open = true
    }

    // ── Player card ──────────────────────────────────────────────────────────
    PlayerCard {
        id: _player
        anchors {
            bottom: parent.bottom; left: parent.left; right: parent.right
            // Side gaps shrink to 0 when fully expanded so it goes edge-to-edge.
            leftMargin:  root.playerState === "expanded" ? 0 : Theme.playerSideInset
            rightMargin: root.playerState === "expanded" ? 0 : Theme.playerSideInset
            Behavior on leftMargin  { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.InOutCubic } }
            Behavior on rightMargin { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.InOutCubic } }
        }
        z: root.playerState === "expanded" ? 900 : 700

        playerState: root.playerState
        onStateChangeRequested: (s) => root.playerState = s
    }

    // ── Navigation overlay ───────────────────────────────────────────────────
    NavigationOverlay {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.navOverlayH
        z: 800
    }

    // ── Notifications ────────────────────────────────────────────────────────
    NotificationLayer {
        id: notifications
        anchors { top: parent.top; left: parent.left; right: parent.right }
        z: 1000
    }

    // ── Settings menu ────────────────────────────────────────────────────────
    SettingsMenu {
        id: _settings
        z: 1200
    }

    // ── Virtual keyboard ─────────────────────────────────────────────────────
    InputPanel {
        z: 1100
        x: 0; width: parent.width
        y: active ? parent.height - height : parent.height
        Behavior on y { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
    }
}
