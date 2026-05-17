import QtQuick
import QtQuick.Controls
import Elise

// Three-state collapsible player card.
//
// States:
//   collapsed → bottom bar (artwork + title + transport)
//   half      → expanded info row with progress + transport
//   expanded  → full screen with FAVORITES / TOP STATIONS browse area
//
// Owners are responsible for setting `playerState`. The card emits
// `stateChangeRequested(newState)` and never mutates its own state.
//
// Two views render simultaneously, cross-faded by opacity:
//   _collapsedView   — visible only when state === "collapsed"
//   _expandedView    — visible whenever state !== "collapsed"
//                      Bottom sections (search/tabs/grids) appear only when fully expanded.
Item {
    id: root

    // ── Public API ────────────────────────────────────────────────────────────
    property string playerState: "collapsed"     // "collapsed" | "half" | "expanded"
    signal stateChangeRequested(string newState)

    // ── Geometry ──────────────────────────────────────────────────────────────
    readonly property real collapsedH: Theme.playerCollapsedH
    readonly property real halfH:      Theme.playerHalfH
    readonly property real expandedH:  parent.height

    function _stateToH(s) {
        switch (s) {
            case "expanded": return expandedH
            case "half":     return halfH
            default:         return collapsedH
        }
    }

    // ── Drag state ────────────────────────────────────────────────────────────
    // While the user is actively dragging, height tracks `_liveH`. On release,
    // we snap to the nearest state's height via `_snapH` and the height Behavior.
    property bool _dragging: false
    property real _liveH:    collapsedH
    property real _snapH:    collapsedH

    onPlayerStateChanged:   _snapH = _stateToH(playerState)
    Component.onCompleted:  _snapH = _stateToH(playerState)

    height: _dragging ? _liveH : _snapH
    Behavior on height {
        enabled: !root._dragging
        NumberAnimation { duration: Theme.durSlow; easing.type: Easing.InOutCubic }
    }

    // ── Drag gesture ──────────────────────────────────────────────────────────
    // Only fires on actual drag translation (above DragHandler's internal threshold),
    // so taps never trigger it — buttons inside still get their clicks.
    DragHandler {
        id: _drag
        target: null
        // When the card is fully expanded, the browse feed below uses a
        // Flickable for vertical scroll. A card-wide DragHandler would
        // grab those gestures first and collapse the card instead of
        // scrolling. Disable the drag in expanded state — users still
        // close via the chevron-down button or by dragging from the
        // collapsed/half states.
        enabled: root.playerState !== "expanded"
        yAxis.enabled: true
        xAxis.enabled: false

        property real _startH: 0

        onActiveChanged: {
            if (active) {
                _startH = root.height
                root._liveH = root.height
                root._dragging = true
            } else {
                root._dragging = false
                const frac = root._liveH / root.expandedH
                const snap = frac < 0.28 ? "collapsed"
                           : frac < 0.72 ? "half"
                           :               "expanded"
                root._snapH = root._stateToH(snap)
                root.stateChangeRequested(snap)
            }
        }

        onTranslationChanged: {
            // Drag up = negative translation.y → height grows.
            root._liveH = Math.max(root.collapsedH,
                          Math.min(root.expandedH, _startH - translation.y))
        }
    }

    // ── Background card ───────────────────────────────────────────────────────
    Rectangle {
        id: cardBg
        anchors.fill: parent
        color: System.surface

        // Top corners only — when expanded, the card is edge-to-edge so corners square off.
        topLeftRadius:  playerState === "expanded" ? 0 : Theme.radiusXL
        topRightRadius: playerState === "expanded" ? 0 : Theme.radiusXL
        Behavior on topLeftRadius  { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.InOutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.InOutCubic } }

        // Drag-handle pill (cosmetic indicator at top of card)
        Rectangle {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter
                      topMargin: Theme.spaceS }
            width:  Theme.dragPillW
            height: Theme.dragPillH
            radius: Theme.dragPillR
            color:  System.border
            opacity: root.playerState !== "expanded" ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
    }

    // ── Content: Collapsed bar ────────────────────────────────────────────────
    Item {
        id: _collapsedView
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.collapsedH
        opacity: root.playerState === "collapsed" ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

        // Tap zone (declared first → lowest z). Button MouseAreas inside the Row
        // sit above and capture taps on themselves; everything else falls through here.
        MouseArea {
            anchors.fill: parent
            onClicked: root.stateChangeRequested("half")
        }

        Row {
            anchors { fill: parent; leftMargin: Theme.spaceL; rightMargin: Theme.spaceM }
            spacing: Theme.spaceM

            // Artwork thumbnail
            Rectangle {
                width:  Theme.playerCollapsedArt
                height: Theme.playerCollapsedArt
                radius: Theme.radiusS
                anchors.verticalCenter: parent.verticalCenter
                color:  System.surface2
                layer.enabled: true

                Image {
                    anchors.fill: parent
                    source:   Player.trackArtwork
                    fillMode: Image.PreserveAspectCrop
                    visible:  Player.trackArtwork !== ""
                }
                SvgIcon {
                    anchors.centerIn: parent
                    source: "qrc:/icons/music-note.svg"
                    color:  System.textMuted
                    size:   Theme.iconS
                    visible: Player.trackArtwork === ""
                }
            }

            // Title (fills remaining width before button cluster)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  Player.trackTitle || "—"
                color: System.textPrimary
                font.pixelSize: Theme.fontBody
                font.weight:    Font.Medium
                elide:          Text.ElideRight
                width: parent.width
                       - Theme.playerCollapsedArt
                       - Theme.spaceM
                       - (Theme.btnSmall * 3 + Theme.spaceM * 3)
            }

            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                icon: "qrc:/icons/skip-back.svg"
                size: Theme.iconS
                onTapped: Player.previous()
            }

            // Play / pause (gold accent square)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:  Theme.btnSmall
                height: Theme.btnSmall
                radius: Theme.radiusS
                color: _playArea.pressed ? System.accentDim : System.accent
                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                SvgIcon {
                    anchors.centerIn: parent
                    source: Player.playing ? "qrc:/icons/pause.svg" : "qrc:/icons/play.svg"
                    color:  "#000000"
                    size:   Theme.iconS
                }
                MouseArea { id: _playArea; anchors.fill: parent; onClicked: Player.togglePlay() }
            }

            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                icon: "qrc:/icons/skip-forward.svg"
                size: Theme.iconS
                onTapped: Player.next()
            }
        }
    }

    // ── Content: Half + Expanded (single layout, conditional sections) ───────
    Item {
        id: _expandedView
        anchors.fill: parent
        opacity: root.playerState !== "collapsed" ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }

        property string activeTab: "Streaming"
        readonly property bool fullExpanded: root.playerState === "expanded"

        // Browse-area state.
        //   searchResults — non-empty after the user submits a query;
        //                   when populated, it replaces the section grid.
        //   homeSections  — list of {id, title, type, items} from /home.
        property var    searchResults: []
        property var    homeSections:  []
        property string lastQuery:     ""

        Connections {
            target: Player
            function onTracksLoaded(tracks, context) {
                if (context === "search")
                    _expandedView.searchResults = tracks
            }
            function onHomeLoaded(sections, replace) {
                if (replace)
                    _expandedView.homeSections = sections
                else
                    _expandedView.homeSections = _expandedView.homeSections.concat(sections)
            }
        }

        // Kick off the daemon /home request once; sections will populate
        // asynchronously via onHomeLoaded.
        Component.onCompleted: Player.loadHome()

        Column {
            anchors {
                fill: parent
                topMargin:    Theme.spaceXXL
                bottomMargin: Theme.spaceXXL
                leftMargin:   Theme.space3XL
                rightMargin:  Theme.space3XL
            }
            spacing: Theme.spaceXXL

            // ── Top row: artwork + info + transport controls ──────────────────
            Item {
                id: _expTopRow
                width: parent.width
                height: Theme.playerExpandedArt

                // Tap zone — covers artwork + info area only (left of controls).
                // Step-up: half → expanded. Child MouseAreas (scrub) win over this one.
                MouseArea {
                    anchors {
                        left:   parent.left
                        right:  _expControls.left
                        top:    parent.top
                        bottom: parent.bottom
                    }
                    enabled:  root.playerState === "half"
                    onClicked: root.stateChangeRequested("expanded")
                }

                // Swipe-down-to-close gesture, scoped to the top row only
                // (artwork + info). The card-wide DragHandler is disabled
                // when expanded so the Flickable below can scroll; this
                // localised handler restores the familiar "drag from the
                // top to collapse" gesture without stealing scroll input
                // from the section feed.
                DragHandler {
                    id: _expDrag
                    target: null
                    enabled: root.playerState === "expanded"
                    yAxis.enabled: true
                    xAxis.enabled: false

                    property real _startH: 0

                    onActiveChanged: {
                        if (active) {
                            _startH = root.height
                            root._liveH = root.height
                            root._dragging = true
                        } else {
                            root._dragging = false
                            const frac = root._liveH / root.expandedH
                            const snap = frac < 0.28 ? "collapsed"
                                       : frac < 0.72 ? "half"
                                       :               "expanded"
                            root._snapH = root._stateToH(snap)
                            root.stateChangeRequested(snap)
                        }
                    }

                    onTranslationChanged: {
                        root._liveH = Math.max(root.collapsedH,
                                      Math.min(root.expandedH, _startH - translation.y))
                    }
                }

                // Artwork
                Rectangle {
                    id: _expArt
                    width:  Theme.playerExpandedArt
                    height: Theme.playerExpandedArt
                    radius: Theme.radiusL
                    color:  System.surface2
                    layer.enabled: true

                    Image {
                        anchors.fill: parent
                        source:   Player.trackArtwork
                        fillMode: Image.PreserveAspectCrop
                        visible:  Player.trackArtwork !== ""
                    }
                    SvgIcon {
                        anchors.centerIn: parent
                        source: "qrc:/icons/music-note.svg"
                        color:  System.textMuted
                        size:   Theme.iconXL
                        visible: Player.trackArtwork === ""
                    }
                }

                // Right-side transport row
                Row {
                    id: _expControls
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.spaceL

                    IconBtn {
                        icon: "qrc:/icons/skip-back.svg"
                        size: Theme.iconS
                        onTapped: Player.previous()
                    }

                    // Play / pause — gold accent square (matches collapsed bar play button)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  Theme.btnSmall
                        height: Theme.btnSmall
                        radius: Theme.radiusS
                        color:  _expPlay.pressed ? System.accentDim : System.accent
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                        SvgIcon {
                            anchors.centerIn: parent
                            source: Player.playing ? "qrc:/icons/pause.svg" : "qrc:/icons/play.svg"
                            color:  "#000000"
                            size:   Theme.iconS
                        }
                        MouseArea { id: _expPlay; anchors.fill: parent; onClicked: Player.togglePlay() }
                    }

                    IconBtn {
                        icon: "qrc:/icons/skip-forward.svg"
                        size: Theme.iconS
                        onTapped: Player.next()
                    }
                    IconBtn {
                        icon: "qrc:/icons/heart.svg"
                        size: Theme.iconS
                        // TODO: wire to Player.toggleFavorite() once exposed
                    }
                    // Manual refresh — re-fetches the home feed from the
                    // daemon. Always visible (not gated on empty state)
                    // so the user can recover from a stale or partial
                    // cache without restarting anything.
                    IconBtn {
                        icon: "qrc:/icons/refresh.svg"
                        size: Theme.iconS
                        visible: _expandedView.fullExpanded
                        onTapped: Player.loadHome()
                    }
                    IconBtn {
                        icon: "qrc:/icons/chevron-down.svg"
                        size: Theme.iconS
                        // Step-down: expanded → half → collapsed
                        onTapped: root.stateChangeRequested(
                            root.playerState === "expanded" ? "half" : "collapsed")
                    }
                }

                // Info column between artwork and controls
                Column {
                    anchors {
                        left:    _expArt.right;        leftMargin:  Theme.spaceXL
                        right:   _expControls.left;    rightMargin: Theme.spaceXL
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.spaceXS

                    Text {
                        text:  Player.trackTitle || "—"
                        color: System.textPrimary
                        font.pixelSize: Theme.fontDisplay
                        font.weight:    Font.Medium
                        elide: Text.ElideRight; width: parent.width
                    }
                    Text {
                        text:  Player.trackArtist || ""
                        color: System.textSecondary
                        font.pixelSize: Theme.fontBody
                        elide: Text.ElideRight; width: parent.width
                    }
                    Text {
                        text:  Player.trackAlbum || ""
                        color: System.textMuted
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideRight; width: parent.width
                        visible: Player.trackAlbum !== ""
                    }

                    // Progress bar with remaining-time label aligned to the right
                    Item {
                        width: parent.width
                        height: Theme.progressRowH

                        Text {
                            id: _expRemaining
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: {
                                const rem = Math.max(0, (Player.durationMs || 0) - (Player.positionMs || 0))
                                return rem > 0 ? "-" + _formatMs(rem) : ""
                            }
                            color: System.textMuted
                            font.pixelSize: Theme.fontCaption
                        }
                        Rectangle {
                            anchors {
                                left:  parent.left
                                right: _expRemaining.left; rightMargin: Theme.spaceM
                                verticalCenter: parent.verticalCenter
                            }
                            height: Theme.progressBarH
                            radius: Theme.progressBarR
                            color:  System.surface2

                            Rectangle {
                                width:  parent.width * Player.progress
                                height: parent.height
                                radius: parent.radius
                                color:  System.accent
                                Behavior on width { NumberAnimation { duration: Theme.progressTickMs } }
                            }
                            // Larger hit area than visual bar
                            MouseArea {
                                anchors { fill: parent
                                          topMargin:    -Theme.progressRowH
                                          bottomMargin: -Theme.progressRowH }
                                onPressed:         (m) => Player.seekTo(Math.max(0, Math.min(1, m.x / width)))
                                onPositionChanged: (m) => { if (pressed) Player.seekTo(Math.max(0, Math.min(1, m.x / width))) }
                            }
                        }
                    }
                }
            }

            // ── Search field + source tabs ────────────────────────────────────
            Item {
                width: parent.width
                height: visible ? Theme.btnMedium : 0
                visible: _expandedView.fullExpanded

                Rectangle {
                    id: _searchField
                    width:  Theme.searchFieldW
                    height: Theme.btnMedium
                    radius: Theme.radiusM
                    color:  _searchArea.pressed ? System.pressOverlay : "transparent"
                    border.color: System.border
                    border.width: 1

                    Row {
                        anchors { fill: parent; leftMargin: Theme.spaceL; rightMargin: Theme.spaceL }
                        spacing: Theme.spaceS

                        SvgIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/icons/search.svg"
                            color:  System.textMuted
                            size:   Theme.iconXS
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text:  _expandedView.lastQuery !== "" ? _expandedView.lastQuery
                                                                  : "Buscar música"
                            color: _expandedView.lastQuery !== "" ? System.textPrimary
                                                                  : System.textMuted
                            font.pixelSize: Theme.fontLabel
                        }
                    }

                    MouseArea {
                        id: _searchArea
                        anchors.fill: parent
                        onClicked: Keyboard.show({
                            title:    "Buscar música",
                            initial:  _expandedView.lastQuery,
                            onSubmit: function(q) {
                                _expandedView.lastQuery = q
                                if (q.trim() === "") {
                                    _expandedView.searchResults = []
                                } else {
                                    Player.search(q, _expandedView.activeTab === "USB"
                                                       ? "local" : "all")
                                }
                            }
                        })
                    }
                }

                // Tabs aligned to the right
                Row {
                    anchors {
                        left:  _searchField.right; leftMargin: Theme.space3XL
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.space3XL

                    Repeater {
                        model: [ "Streaming", "USB" ]
                        delegate: Item {
                            required property string modelData
                            readonly property bool isActive: _expandedView.activeTab === modelData

                            width: _tabLbl.width; height: Theme.tabH

                            Text {
                                id: _tabLbl
                                anchors.centerIn: parent
                                text:  modelData
                                color: isActive ? System.textPrimary : System.textSecondary
                                font.pixelSize: Theme.fontLarge
                                font.weight:    isActive ? Font.DemiBold : Font.Normal
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: _expandedView.activeTab = modelData
                            }
                        }
                    }
                }
            }

            // ── Browse area ──────────────────────────────────────────────────
            //
            // When the user has an active search, we show a flat vertical
            // list (TrackList). Otherwise we render the home feed: a
            // "Próximas músicas" carousel built from Player.queue, followed
            // by one carousel per /home section. The whole thing is in a
            // Flickable so the user can scroll vertically through sections.
            Item {
                id: _browseArea
                width:   parent.width
                height: _expandedView.fullExpanded
                          ? (parent.height - y - Theme.spaceXXL)
                          : 0
                visible: _expandedView.fullExpanded
                clip:    true

                // ── Search results overlay ──
                TrackList {
                    id: _searchList
                    width: parent.width
                    visible: _expandedView.searchResults.length > 0
                    heading: "RESULTADOS"
                    tracks: _expandedView.searchResults
                    onTrackTapped: (idx) => {
                        Player.playQueue(_expandedView.searchResults, idx)
                        _expandedView.searchResults = []
                        _expandedView.lastQuery     = ""
                    }
                }

                // ── Home feed (scrollable column of carousels) ──
                // Empty-state hint shown when the home feed hasn't loaded
                // yet (boot before sync / no network / daemon down). The
                // user can poke `Recarregar` to retry now; otherwise the
                // PlayerController's status poll auto-retries every few
                // seconds and the carousels appear as soon as data lands.
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spaceL
                    visible: _expandedView.searchResults.length === 0
                          && _expandedView.homeSections.length === 0
                          && Player.queue.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Player.daemonReady ? "Carregando músicas…"
                                                 : "Sem conexão com o servidor"
                        color: System.textMuted
                        font.pixelSize: Theme.fontBody
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width:  140
                        height: Theme.btnMedium
                        radius: Theme.radiusM
                        color:  _retryArea.pressed ? System.accentDim : System.accent

                        Text {
                            anchors.centerIn: parent
                            text:  "Recarregar"
                            color: "#000000"
                            font.pixelSize: Theme.fontBody
                            font.weight:    Font.Medium
                        }
                        MouseArea {
                            id: _retryArea
                            anchors.fill: parent
                            onClicked: Player.loadHome()
                        }
                    }
                }

                Flickable {
                    id: _feed
                    anchors.fill: parent
                    visible: _expandedView.searchResults.length === 0
                          && _expandedView.homeSections.length > 0
                    contentWidth: width
                    contentHeight: _feedCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    // Infinite scroll trigger — when the viewport is
                    // within one screen-height of the bottom, request
                    // the next /home page. PlayerController guards
                    // against re-entrancy and exhausted feeds.
                    onContentYChanged: {
                        const remaining = contentHeight - (contentY + height)
                        if (remaining < height) Player.loadMoreHome()
                    }

                    Column {
                        id: _feedCol
                        width: parent.width
                        spacing: Theme.spaceXXL

                        // Próximas músicas — current queue, highlighting
                        // the playing track. Hidden when queue is empty.
                        TrackCarousel {
                            width:   parent.width
                            visible: Player.queue.length > 0
                            heading: "PRÓXIMAS MÚSICAS"
                            tracks:  Player.queue
                            currentIndex: Player.queueIndex
                            onTrackTapped: (idx) => Player.playQueue(Player.queue, idx)
                        }

                        // One carousel per /home section.
                        Repeater {
                            model: _expandedView.homeSections
                            delegate: TrackCarousel {
                                required property var modelData
                                width:   _feedCol.width
                                heading: (modelData.title || "").toUpperCase()
                                tracks:  modelData.items || []
                                onTrackTapped: (idx) => Player.playQueue(modelData.items, idx)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _formatMs(ms) {
        if (!ms || ms <= 0) return "—:——"
        const total = Math.floor(ms / 1000)
        const m     = Math.floor(total / 60)
        const s     = total % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    // ── Inline components ─────────────────────────────────────────────────────

    // Square tappable icon button with subtle pressed-state background.
    component IconBtn: Item {
        property url  icon
        property real size: Theme.iconM
        signal tapped()

        width:  Theme.btnMedium
        height: Theme.btnMedium

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusM
            color:  _ia.pressed ? System.pressOverlay : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }
        SvgIcon {
            anchors.centerIn: parent
            source: parent.icon
            color:  System.textSecondary
            size:   parent.size
        }
        MouseArea { id: _ia; anchors.fill: parent; onClicked: parent.tapped() }
    }

}
