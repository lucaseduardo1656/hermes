import QtQuick
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

    // Tesla-style chrome: the player bar only takes screen real estate
    // when there's actually media to surface (track loaded, queue
    // populated) or the user explicitly opened it. Otherwise it
    // collapses to a small Fab on the right edge.
    readonly property bool _playerVisible:
        Player.trackTitle !== ""
     || Player.queue.length > 0
     || root.playerState !== "collapsed"

    // ── Map ──────────────────────────────────────────────────────────────────
    // MapLibre reads its style at Plugin construction, so changing
    // styles at runtime means destroying and re-creating CarMap.
    // A Loader keyed on the style URL is the cheapest way to do that:
    // toggling `active` tears the old map down and rebuilds with the
    // new URL.
    Loader {
        id: _mapLoader
        anchors.fill: parent
        z: 0
        sourceComponent: _mapComponent
        property string _styleUrl: Settings.appearance.mapStyleUrl
        on_StyleUrlChanged: { active = false; active = true }
    }
    // Alias for the rest of Main.qml — search bar, summary, etc.
    // bind through `_map`.
    property var _map: _mapLoader.item

    Component {
        id: _mapComponent
        CarMap {
            interactive: root.playerState === "collapsed"
                      && !_settings.open
                      && !Keyboard.active
            styleUrl:    _mapLoader._styleUrl
        }
    }

    // ── Top-left chip stack ──────────────────────────────────────────────────
    // Single Column owns the three chips (search → nav banner → route
    // summary) so they always stack with the same spacing and no
    // cross-item anchor weirdness.
    Column {
        id: _topStack
        anchors {
            top:  parent.top;  topMargin:  Theme.spaceL
            left: parent.left; leftMargin: Theme.spaceL
        }
        spacing: Theme.spaceS
        z: 700
        visible: root.playerState !== "expanded"

        MapSearchBar {
            id: _mapSearch
            width: 320
            map: root._map
        }

        NavigationOverlay {
            id: _navOverlay
            width: 320
            height: Theme.navOverlayH
            visible: Nav.active
        }

        Rectangle {
            id: _routeSummary
            width: 320
            height: Theme.btnLarge
            visible: _map && _map.hasDestination && _map.routeDistanceM > 0
            radius: Theme.radiusL
            color: System.surface
            border.color: System.border
            border.width: 1
            Row {
                anchors { fill: parent; leftMargin: Theme.spaceL; rightMargin: Theme.spaceL }
                spacing: Theme.spaceL
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!_map) return ""
                        const m = _map.routeDistanceM
                        if (Settings.appearance.units === "imperial") {
                            const mi = m / 1609.344
                            return mi.toFixed(1) + " mi"
                        }
                        return (m / 1000).toFixed(1) + " km"
                    }
                    color: System.textPrimary
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.Medium
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: _map ? Math.round(_map.routeDurationS / 60) + " min" : ""
                    color: System.textSecondary
                    font.pixelSize: Theme.fontBody
                }
            }
        }
    }

    // Compass dial — appears whenever the map has been rotated off
    // north. Tap to snap back. Sits just above the recenter Fab.
    // Compass + recenter combo — sits where the recenter arrow used
    // to. Always visible: shows north when bearing != 0, doubles as
    // the "snap back to GPS + north" button when tapped.
    CompassRose {
        id: _recenterFab     // kept the id so other anchors don't shift
        anchors {
            right:  parent.right; rightMargin: Theme.spaceL
            bottom: _settingsFab.top; bottomMargin: Theme.spaceL
        }
        z: 600
        bearing: _map ? _map.bearing : 0
        visible: root.playerState !== "expanded"
        onResetRequested: if (_map) _map.recenter()
    }

    // Music Fab — only when the player is hidden. Tapping summons the
    // player bar to its half-expanded state. Stacks above recenter.
    Fab {
        anchors {
            right:  parent.right; rightMargin: Theme.spaceL
            bottom: _recenterFab.top; bottomMargin: Theme.spaceL
        }
        z: 600
        icon: "qrc:/icons/music-note.svg"
        visible: !root._playerVisible && root.playerState !== "expanded"
        onClicked: root.playerState = "half"
    }

    // ── Input blocker (covers only area above the player card) ───────────────
    GlobalInputBlocker {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: parent.height - (root._playerVisible ? _player.height : 0)
        z: 50
        active: root.playerState !== "collapsed"
        onDismissed: root.playerState = "collapsed"
    }

    // ── Floating action button (settings) ────────────────────────────────────
    // Anchored to the top of the player card when it's around; otherwise
    // sits at the screen bottom-right corner.
    Fab {
        id: _settingsFab
        anchors {
            right:  parent.right; rightMargin: Theme.spaceL
            bottom: root._playerVisible ? _player.top : parent.bottom
            bottomMargin: Theme.spaceL
        }
        z: 600
        icon: "qrc:/icons/settings.svg"
        visible: root.playerState !== "expanded"
        onClicked: _settings.open = true
    }

    // ── Player card ──────────────────────────────────────────────────────────
    PlayerCard {
        id: _player
        visible: root._playerVisible
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

    // NavigationOverlay is mounted inside the top-left Column above.

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

    // ── Global on-screen keyboard ────────────────────────────────────────────
    // Top of the z-stack so it covers settings sidebar + modals.
    // Driven by the `Keyboard` singleton; any page does `Keyboard.show(...)`.
    SoftKeyboard {
        z: 1400
    }

    // ── Global action sheet (contextual menus) ───────────────────────────────
    // Above the keyboard so long-press menus over a field still get focus.
    ActionSheetView {
        z: 1500
    }

    // QtVirtualKeyboard's InputPanel is intentionally absent — Qt's IM plugin
    // refuses to attach client-side under cage/Wayland. We use the QML
    // SoftKeyboard above instead.
}
