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
            width: 36; height: 4; radius: 2
            color: System.border
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
                        size: Theme.iconM
                        onTapped: Player.previous()
                    }

                    // Play / pause — gold accent square (sized to match transport buttons)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  Theme.btnMedium
                        height: Theme.btnMedium
                        radius: Theme.radiusM
                        color:  _expPlay.pressed ? System.accentDim : System.accent
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                        SvgIcon {
                            anchors.centerIn: parent
                            source: Player.playing ? "qrc:/icons/pause.svg" : "qrc:/icons/play.svg"
                            color:  "#000000"
                            size:   Theme.iconM
                        }
                        MouseArea { id: _expPlay; anchors.fill: parent; onClicked: Player.togglePlay() }
                    }

                    IconBtn {
                        icon: "qrc:/icons/skip-forward.svg"
                        size: Theme.iconM
                        onTapped: Player.next()
                    }
                    IconBtn {
                        icon: "qrc:/icons/heart.svg"
                        size: Theme.iconM
                        // TODO: wire to Player.toggleFavorite() once exposed
                    }
                    IconBtn {
                        icon: "qrc:/icons/chevron-down.svg"
                        size: Theme.iconM
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
                        height: 14

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
                            height: 3; radius: 1.5
                            color:  System.surface2

                            Rectangle {
                                width:  parent.width * Player.progress
                                height: parent.height
                                radius: parent.radius
                                color:  System.accent
                                Behavior on width { NumberAnimation { duration: 500 } }
                            }
                            // Larger hit area than visual bar (extend top/bottom by 14px)
                            MouseArea {
                                anchors { fill: parent; topMargin: -14; bottomMargin: -14 }
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
                    width:  260
                    height: Theme.btnMedium
                    radius: Theme.radiusM
                    color:  "transparent"
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
                            text:  "Anything"
                            color: System.textMuted
                            font.pixelSize: Theme.fontLabel
                        }
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

                            width: _tabLbl.width; height: 32

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

            // ── Browse sections (FAVORITES / TOP STATIONS) ────────────────────
            BrowseSection {
                width: parent.width
                visible: _expandedView.fullExpanded
                title: "FAVORITES"
            }

            BrowseSection {
                width: parent.width
                visible: _expandedView.fullExpanded
                title: "TOP STATIONS"
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

    // Heading + horizontal grid of placeholder album covers.
    component BrowseSection: Column {
        property string title

        spacing: Theme.spaceM

        Text {
            width: parent.width
            text:  title
            color: System.textPrimary
            font.pixelSize:    Theme.fontLabel
            font.weight:       Font.Medium
            font.letterSpacing: 1
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spaceXL

            Repeater {
                model: 6
                delegate: Rectangle {
                    width:  Theme.playerGridArt
                    height: Theme.playerGridArt
                    radius: Theme.radiusM
                    color:  System.surface2
                    layer.enabled: true

                    SvgIcon {
                        anchors.centerIn: parent
                        source: "qrc:/icons/music-note.svg"
                        color:  System.textMuted
                        size:   Theme.iconL
                    }
                }
            }
        }
    }
}
