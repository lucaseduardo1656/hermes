import QtQuick
import QtQuick.Layouts
import QtPositioning
import Elise

// Map search — Tesla-style. The field doubles as a navigation header while a
// route is active. Tapping it opens a panel with Home/Work shortcuts, a
// Recents/Favorites switch and (while typing) live geocode results. Picking
// an item normally routes there; when RoadInfo is in "set place" mode it is
// saved to Home/Work instead.
//
// Styled with the nexus design tokens (Tokens/Colours) + Material Symbols to
// match the settings UI.
Item {
    id: root

    // Clip so the results panel reveals with a slide-down as the container's
    // animated height grows, instead of popping in.
    clip: true

    property var map: null

    property string query:   ""
    property var    results: []
    property bool   open:    false
    property string tab:     "recentes"     // recentes | favoritos

    readonly property bool _editing:
        Keyboard.active && Keyboard.title === "Buscar endereço"
    readonly property bool _navigating: map && map.hasDestination && !_editing
    readonly property bool _typing: query.trim().length >= 3
    readonly property bool _setting: RoadInfo.pendingPlace !== ""
    readonly property bool _panelOpen: (_editing || open) && !_navigating

    readonly property var _items: _typing ? results
                               : tab === "favoritos" ? RoadInfo.favorites
                               : RoadInfo.recents

    implicitHeight: _field.height + (_panelOpen ? Tokens.spacing.small + _panel.height : 0)
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad }
    }

    // ── Helpers ─────────────────────────────────────────────────────────
    function _distStr(lat, lon) {
        if (!GPS.valid) return ""
        const d = QtPositioning.coordinate(lat, lon).distanceTo(GPS.coordinate)
        return d >= 1000 ? (d / 1000).toFixed(1) + " km" : Math.round(d) + " m"
    }
    function _pick(coord, name, address) {
        if (root._setting) {
            RoadInfo.savePlace(RoadInfo.pendingPlace, coord.latitude, coord.longitude, name)
        } else if (root.map) {
            root.map.setDestination(coord, name, address || "")
        }
        root.query = ""; root.results = []; root.open = false
        if (Keyboard.active) Keyboard.dismiss()
    }
    function _openKeyboard() {
        Keyboard.show({
            title: "Buscar endereço", bare: true, initial: root.query,
            onSubmit: function(text) {
                root.query = text
                if (root.results.length === 0 && root.map && text.trim().length >= 3)
                    root.map.geocode(text, function(items) {
                        root.results = items; root.open = items.length > 0
                    })
            },
            onCancel: function() {
                if (root.query === "") root.open = false
                RoadInfo.cancelSetPlace()
            }
        })
    }
    function _placeTap(which) {
        const p = which === "home" ? RoadInfo.home : RoadInfo.work
        if (p && p.lat !== undefined) {
            _pick(QtPositioning.coordinate(p.lat, p.lon),
                  which === "home" ? "Casa" : "Trabalho", "")
        } else {
            RoadInfo.beginSetPlace(which)
            _openKeyboard()
        }
    }

    // True while a geocode request is in flight (drives the loading bar).
    property bool _searching: false

    // ── Debounced geocode ───────────────────────────────────────────────
    Timer {
        id: _geoDebounce; interval: 600; repeat: false
        onTriggered: {
            const q = root.query.trim()
            if (q.length < 3 || !root.map) { root._searching = false; return }
            root._searching = true
            root.map.geocode(q, function(items) {
                root.results = items; root.open = items.length > 0
                root._searching = false
            })
        }
    }
    onQueryChanged: { if (query.trim().length >= 3) root._searching = true; _geoDebounce.restart() }
    Connections {
        target: Keyboard
        function onBufferChanged() { if (root._editing) root.query = Keyboard.buffer }
    }

    // ── Field ────────────────────────────────────────────────────────────
    Rectangle {
        id: _field
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root._navigating ? 60 : Theme.btnLarge
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHigh
        border.color: root._editing ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
        border.width: 1
        Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad } }
        Behavior on border.color { CAnim {} }

        MaterialIcon {
            id: _leadIcon
            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
            symbol: root._navigating ? "navigation" : "search"
            color:  root._navigating ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
            fill: root._navigating ? 1 : 0
        }

        Column {
            anchors {
                left: _leadIcon.right; leftMargin: Tokens.spacing.medium
                right: _clearChip.visible ? _clearChip.left : parent.right
                rightMargin: Tokens.spacing.small; verticalCenter: parent.verticalCenter
            }
            spacing: 1
            StyledText {
                visible: root._navigating || root._setting
                width: parent.width
                text: root._setting
                        ? (RoadInfo.pendingPlace === "home" ? "DEFININDO CASA" : "DEFININDO TRABALHO")
                        : "NAVEGANDO"
                color: Colours.palette.m3primary
                font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.2
            }
            StyledText {
                width: parent.width
                text: root._navigating ? (root.map.destinationName || "Destino")
                     : root._setting   ? "Escolha o local…"
                     : root.query !== "" ? root.query : "Para onde?"
                color: (root._navigating || root.query !== "") ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.body.large.pointSize
                font.weight: root._navigating ? Font.Bold : Font.Normal
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: _clearChip
            visible: (root.map && root.map.hasDestination) || root.query !== ""
            anchors { right: parent.right; rightMargin: Tokens.spacing.extraSmall; verticalCenter: parent.verticalCenter }
            width: Theme.btnSmall; height: Theme.btnSmall; radius: width / 2
            color: _clearArea.pressed ? Colours.palette.m3surfaceContainerHighest : "transparent"
            MaterialIcon { anchors.centerIn: parent; symbol: "close"
                           color: Colours.palette.m3onSurfaceVariant; fontStyle: Tokens.font.icon.small }
            MouseArea {
                id: _clearArea; anchors.fill: parent
                onClicked: {
                    if (root.map) root.map.clearDestination()
                    root.query = ""; root.results = []; root.open = false
                    RoadInfo.cancelSetPlace()
                }
            }
        }

        MouseArea {
            anchors {
                fill: parent
                rightMargin: _clearChip.visible ? Theme.btnSmall + Tokens.spacing.extraSmall * 2 : 0
            }
            onClicked: root._openKeyboard()
        }
    }

    // ── Search panel ──────────────────────────────────────────────────────
    Rectangle {
        id: _panel
        anchors { left: parent.left; right: parent.right; top: _field.bottom; topMargin: Tokens.spacing.small }
        height: _panelCol.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh
        border.color: Colours.palette.m3outlineVariant; border.width: 1
        visible: root._panelOpen
        clip: true

        // Swallow taps on the panel so they don't fall through to the map
        // (which would deselect / dismiss the search).
        MouseArea { anchors.fill: parent }

        Column {
            id: _panelCol
            anchors { left: parent.left; right: parent.right; top: parent.top
                      margins: Tokens.padding.large }
            spacing: Tokens.spacing.small

            // Home / Work shortcuts — only on the resting panel; hidden once the
            // keyboard is up (frees vertical space above it on the short screen).
            Row {
                width: parent.width
                visible: !root._typing && !root._editing
                spacing: Tokens.spacing.small

                component Shortcut: Rectangle {
                    id: sc
                    property string which
                    property string icon
                    property string label
                    property bool   isSet
                    width: (parent.width - parent.spacing) / 2
                    height: 46; radius: Tokens.rounding.medium
                    color: _scArea.pressed ? Colours.palette.m3surfaceContainerHigh : "transparent"
                    border.color: Colours.palette.m3outlineVariant; border.width: 1

                    MaterialIcon {
                        id: _scIcon
                        anchors { left: parent.left; leftMargin: Tokens.padding.large
                                  verticalCenter: parent.verticalCenter }
                        symbol: sc.icon
                        fontStyle: Tokens.font.icon.small
                        color: sc.isSet ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fill: sc.isSet ? 1 : 0
                    }
                    StyledText {
                        anchors { left: _scIcon.right; leftMargin: Tokens.spacing.small
                                  right: parent.right; rightMargin: Tokens.spacing.small
                                  verticalCenter: parent.verticalCenter }
                        text: sc.label
                        color: sc.isSet ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                    MouseArea { id: _scArea; anchors.fill: parent
                                onClicked: root._placeTap(sc.which) }
                }

                Shortcut {
                    which: "home"; icon: "home"; label: "Casa"
                    isSet: RoadInfo.home && RoadInfo.home.lat !== undefined
                }
                Shortcut {
                    which: "work"; icon: "work"; label: "Trabalho"
                    isSet: RoadInfo.work && RoadInfo.work.lat !== undefined
                }
            }

            // Tabs (Recentes / Favoritos) — Caelestia dashboard style: icon over
            // label, full-width, with an animated underline indicator + a
            // separator. Hidden while typing a query.
            Column {
                width: parent.width
                visible: !root._typing
                spacing: 0

                readonly property var _tabs: [
                    { k: "recentes",  t: "Recentes",  ic: "schedule" },
                    { k: "favoritos", t: "Favoritos", ic: "star" }
                ]

                RowLayout {
                    id: _tabBar
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: parent.parent._tabs
                        delegate: Item {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: _tcol.implicitHeight + Tokens.padding.small * 2
                            readonly property bool current: root.tab === modelData.k

                            StateLayer {
                                radius: Tokens.rounding.medium
                                onClicked: root.tab = modelData.k
                            }
                            Column {
                                id: _tcol
                                anchors.centerIn: parent
                                spacing: 1
                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    symbol: modelData.ic
                                    color: parent.parent.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    fill: parent.parent.current ? 1 : 0
                                    fontStyle: Tokens.font.icon.small
                                    Behavior on fill { Anim { type: Anim.DefaultEffects } }
                                }
                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.t
                                    color: parent.parent.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                }
                            }
                        }
                    }
                }

                // Animated underline indicator.
                Item {
                    width: parent.width; height: 3
                    Rectangle {
                        width: parent.width / 2 - Tokens.spacing.large
                        height: 3; radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                        x: (root.tab === "recentes" ? 0 : parent.width / 2) + Tokens.spacing.large / 2
                        Behavior on x { Anim {} }
                    }
                }

                // Separator.
                Rectangle {
                    width: parent.width; height: 1
                    color: Colours.palette.m3outlineVariant
                }
            }

            // Loading — the indeterminate M3 bar used across the app (Wi-Fi /
            // Bluetooth scan), shown while a geocode request is in flight.
            Column {
                width: parent.width
                visible: root._searching && root._items.length === 0
                spacing: Tokens.spacing.small
                topPadding: Tokens.spacing.small

                StyledText {
                    text: "Buscando…"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
                StyledProgressBar {
                    width: parent.width
                    implicitHeight: Tokens.rounding.extraSmall
                    indeterminate: true
                }
            }

            // Empty hint (not while loading)
            StyledText {
                width: parent.width
                visible: !root._searching && root._items.length === 0
                text: root._typing ? "Nenhum resultado."
                    : root.tab === "favoritos" ? "Sem favoritos ainda."
                    : "Sem destinos recentes."
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                topPadding: Tokens.spacing.small; bottomPadding: Tokens.spacing.small
            }

            // Results / recents / favorites list
            ListView {
                width: parent.width
                // Capped so the panel still clears the docked keyboard on the
                // short 600-px screen; the list scrolls for more.
                height: Math.min(contentHeight, Theme.btnMedium * 3)
                visible: root._items.length > 0
                model: root._items
                clip: true
                interactive: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                spacing: 0

                delegate: ListRow {
                    required property var modelData
                    required property int index

                    readonly property bool _isResult: root._typing
                    readonly property var _coord: _isResult ? modelData.coordinate
                        : QtPositioning.coordinate(modelData.lat, modelData.lon)

                    icon: root._typing ? "search"
                        : root.tab === "favoritos" ? "star" : "schedule"
                    title: _isResult ? modelData.address
                         : (modelData.name && modelData.name.length ? modelData.name : modelData.address)
                    subtitle: _isResult ? "" : (modelData.address || "")
                    onClicked: root._pick(_coord, title, subtitle)

                    StyledText {
                        text: root._distStr(_coord.latitude, _coord.longitude)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }
            }
        }
    }
}
