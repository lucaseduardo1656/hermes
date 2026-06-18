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
    // MapLibre reads its style at Plugin construction, so changing styles at
    // runtime means destroying and re-creating CarMap. Before the rebuild we
    // snapshot the camera + active destination and restore them on the new map
    // so a theme change doesn't reset the zoom/tilt or break an active route.
    property var _mapRestore: null
    Loader {
        id: _mapLoader
        anchors.fill: parent
        z: 0
        sourceComponent: _mapComponent
        property string _styleUrl: Settings.appearance.mapStyleUrl
        on_StyleUrlChanged: {
            if (item) {
                root._mapRestore = {
                    cam:       item.cameraState(),
                    dest:      item.destination,
                    destName:  item.destinationName,
                    navStarted: item.navStarted
                }
            }
            active = false; active = true
        }
        onLoaded: if (root._mapRestore) {
            const s = root._mapRestore; root._mapRestore = null
            item.applyCamera(s.cam)
            if (s.dest) {
                item.setDestination(s.dest, s.destName)
                if (s.navStarted) item.startNavigation()
            }
        }
    }
    // Alias for the rest of Main.qml — search bar, summary, etc.
    // bind through `_map`.
    property var _map: _mapLoader.item
    // True while the POI side panel is up; chrome on the right edge hides
    // so it never sits under the panel.
    readonly property bool _poiPanelOpen: _map && _map.poiPanelOpen

    Component {
        id: _mapComponent
        CarMap {
            interactive: root.playerState === "collapsed"
                      && !_settings.open
                      && !Keyboard.active
            styleUrl:    _mapLoader._styleUrl
            gestureBottomExclude: root._playerVisible && root.playerState === "collapsed"
                                    ? Theme.playerCollapsedH * 2 : 0
            bottomOffset: root._playerVisible && root.playerState === "collapsed"
                            ? Theme.playerCollapsedH : 0
            onSwipeUpFromBottom: root.playerState = "half"
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
        // Hidden while the POI card occupies the left column, so the search /
        // nav banner / route preview never stack under it.
        visible: root.playerState !== "expanded" && !root._poiPanelOpen

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

        // Route preview — shown after picking a destination, before the trip
        // starts. ETA + distance + a prominent "Iniciar" button. Once the
        // trip is running the NavigationOverlay above takes over.
        Rectangle {
            id: _routePreview
            width: 320
            height: _previewCol.implicitHeight + Theme.spaceL * 2
            visible: _map && _map.hasDestination && _map.routeDistanceM > 0 && !_map.navStarted
            radius: Theme.radiusL
            color: System.surface
            border.color: System.border
            border.width: 1

            readonly property real _durMin: _map ? _map.routeDurationS / 60 : 0
            readonly property string _eta: {
                const d = new Date(Date.now() + (_map ? _map.routeDurationS : 0) * 1000)
                return Qt.formatTime(d, "HH:mm")
            }
            readonly property string _distStr: {
                if (!_map) return ""
                const m = _map.routeDistanceM
                return Settings.appearance.units === "imperial"
                    ? (m / 1609.344).toFixed(1) + " mi" : (m / 1000).toFixed(1) + " km"
            }

            Column {
                id: _previewCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                          leftMargin: Theme.spaceL; rightMargin: Theme.spaceL }
                spacing: Theme.spaceM

                Row {
                    width: parent.width
                    Column {
                        width: parent.width - _etaCol.width
                        spacing: 1
                        Text {
                            text: Math.round(_routePreview._durMin) + " min"
                            color: System.textPrimary
                            font.pixelSize: Theme.fontTitle; font.weight: Font.Bold
                        }
                        Text {
                            text: _routePreview._distStr + "  ·  chegada " + _routePreview._eta
                            color: System.textSecondary; font.pixelSize: Theme.fontLabel
                        }
                    }
                    Item { id: _etaCol; width: 0; height: 1 }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spaceS

                    Rectangle {
                        width: parent.width - _cancelBtn.width - parent.spacing
                        height: 48; radius: Theme.radiusM
                        color: _goArea.pressed ? System.accentDim : System.accent
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        Row {
                            anchors.centerIn: parent; spacing: Theme.spaceS
                            SvgIcon { anchors.verticalCenter: parent.verticalCenter
                                      size: 20; color: "#000000"
                                      source: "qrc:/icons/arrow-straight.svg" }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                   text: "Iniciar"; color: "#000000"
                                   font.pixelSize: Theme.fontBody; font.weight: Font.Bold }
                        }
                        MouseArea { id: _goArea; anchors.fill: parent
                                    onClicked: if (_map) _map.startNavigation() }
                    }
                    Rectangle {
                        id: _cancelBtn
                        width: 48; height: 48; radius: Theme.radiusM
                        color: _cxArea.pressed ? System.surface2 : "transparent"
                        border.color: System.border; border.width: 1
                        SvgIcon { anchors.centerIn: parent; size: 18
                                  color: System.textSecondary; source: "qrc:/icons/close.svg" }
                        MouseArea { id: _cxArea; anchors.fill: parent
                                    onClicked: if (_map) _map.clearDestination() }
                    }
                }
            }
        }
    }

    // ── Weather card (top-right) ──────────────────────────────────────────────
    // Regional conditions from the Weather controller. Mirrors the top-left
    // stack; hidden while the player is expanded so it never overlaps.
    WeatherCard {
        anchors {
            top:   parent.top;   topMargin:   Theme.spaceL
            right: parent.right; rightMargin: Theme.spaceL
        }
        z: 700
        visible: Weather.valid && root.playerState !== "expanded" && !root._poiPanelOpen
    }

    // ── Right-edge FAB stack ──────────────────────────────────────────────────
    // One column owns every floating button (music · places · recenter ·
    // settings) so visibility and stacking live in a single place instead of
    // chained anchors and a condition repeated on each button. Children lay
    // top→down; settings is last so it sits nearest the player bar. Hidden
    // children drop out of the layout automatically, so the stack reflows.
    Column {
        id: _fabStack
        anchors {
            right:  parent.right; rightMargin: Theme.spaceL
            bottom: root._playerVisible ? _player.top : parent.bottom
            bottomMargin: Theme.spaceL
        }
        spacing: Theme.spaceL
        z: 600
        visible: root.playerState !== "expanded"

        Fab {     // summon player — only when it's hidden
            icon: "qrc:/icons/music-note.svg"
            visible: !root._playerVisible
            onClicked: root.playerState = "half"
        }
        CompassRose {     // recenter + snap-to-north
            bearing: _map ? _map.bearing : 0
            onResetRequested: if (_map) _map.recenter()
        }
        Fab {     // settings
            icon: "qrc:/icons/settings.svg"
            onClicked: _settings.open = true
        }
    }

    // ── Input blocker (covers only area above the player card) ───────────────
    GlobalInputBlocker {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: parent.height - (root._playerVisible ? _player.height : 0)
        z: 50
        active: root.playerState !== "collapsed"
        onDismissed: root.playerState = "collapsed"
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

    // Bare-mode dismiss catcher: while the map-search keyboard is up (no dim
    // overlay), a tap on the map should close it. Sits below the search stack
    // (z 700) so suggestions still receive taps, above the map so map taps
    // dismiss. The keyboard tray (z 1400) stays on top of this.
    MouseArea {
        anchors.fill: parent
        z: 650
        visible: Keyboard.active && Keyboard.bare
        enabled: visible
        onClicked: Keyboard.dismiss()
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
