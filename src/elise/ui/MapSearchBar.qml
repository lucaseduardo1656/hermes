import QtQuick
import QtPositioning
import Elise

// Map search — Tesla-style. The field doubles as a navigation header while a
// route is active. Tapping it opens a panel with Home/Work shortcuts, a
// Recents/Favorites switch and (while typing) live geocode results. Picking
// an item normally routes there; when RoadInfo is in "set place" mode it is
// saved to Home/Work instead.
Item {
    id: root

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
    // Panel is shown while searching (keyboard ours or results open), but not
    // while we're acting as the navigation header.
    readonly property bool _panelOpen: (_editing || open) && !_navigating

    readonly property var _items: _typing ? results
                               : tab === "favoritos" ? RoadInfo.favorites
                               : RoadInfo.recents

    implicitHeight: _field.height + (_panelOpen ? 6 + _panel.height : 0)
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

    // ── Debounced geocode ───────────────────────────────────────────────
    Timer {
        id: _geoDebounce; interval: 600; repeat: false
        onTriggered: {
            const q = root.query.trim()
            if (q.length < 3 || !root.map) return
            root.map.geocode(q, function(items) {
                root.results = items; root.open = items.length > 0
            })
        }
    }
    onQueryChanged: _geoDebounce.restart()
    Connections {
        target: Keyboard
        function onBufferChanged() { if (root._editing) root.query = Keyboard.buffer }
    }

    // ── Field ────────────────────────────────────────────────────────────
    Rectangle {
        id: _field
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root._navigating ? 60 : Theme.btnMedium
        radius: Theme.radiusM
        color: System.surface
        border.color: root._editing ? System.accent : System.border
        border.width: 1
        Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad } }

        SvgIcon {
            id: _leadIcon
            anchors { left: parent.left; leftMargin: Theme.spaceM; verticalCenter: parent.verticalCenter }
            source: root._navigating ? "qrc:/icons/arrow-straight.svg" : "qrc:/icons/search.svg"
            color:  root._navigating ? System.accent : System.textMuted
            size:   root._navigating ? Theme.iconS : Theme.iconXS
        }

        Column {
            anchors {
                left: _leadIcon.right; leftMargin: Theme.spaceM
                right: _clearChip.visible ? _clearChip.left : parent.right
                rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter
            }
            spacing: 1
            Text {
                visible: root._navigating || root._setting
                width: parent.width
                text: root._setting
                        ? (RoadInfo.pendingPlace === "home" ? "DEFININDO CASA" : "DEFININDO TRABALHO")
                        : "NAVEGANDO"
                color: System.accent
                font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.2
            }
            Text {
                width: parent.width
                text: root._navigating ? (root.map.destinationName || "Destino")
                     : root._setting   ? "Escolha o local…"
                     : root.query !== "" ? root.query : "Para onde?"
                color: (root._navigating || root.query !== "") ? System.textPrimary : System.textMuted
                font.pixelSize: Theme.fontLabel
                font.weight: root._navigating ? Font.Bold : Font.Normal
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: _clearChip
            visible: (root.map && root.map.hasDestination) || root.query !== ""
            anchors { right: parent.right; rightMargin: Theme.spaceXS; verticalCenter: parent.verticalCenter }
            width: Theme.btnSmall; height: Theme.btnSmall; radius: width / 2
            color: _clearArea.pressed ? System.pressOverlay : "transparent"
            SvgIcon { anchors.centerIn: parent; source: "qrc:/icons/close.svg"
                      color: System.textSecondary; size: Theme.iconXS }
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
                rightMargin: _clearChip.visible ? Theme.btnSmall + Theme.spaceXS * 2 : 0
            }
            onClicked: root._openKeyboard()
        }
    }

    // ── Search panel ──────────────────────────────────────────────────────
    Rectangle {
        id: _panel
        anchors { left: parent.left; right: parent.right; top: _field.bottom; topMargin: Theme.spaceXS }
        height: _panelCol.implicitHeight + Theme.spaceM * 2
        radius: Theme.radiusM
        color: System.surface
        border.color: System.border; border.width: 1
        visible: root._panelOpen
        clip: true

        Column {
            id: _panelCol
            anchors { left: parent.left; right: parent.right; top: parent.top
                      margins: Theme.spaceM }
            spacing: Theme.spaceS

            // Home / Work shortcuts (hidden while actively typing a query)
            Row {
                width: parent.width
                visible: !root._typing
                spacing: Theme.spaceS

                component Shortcut: Rectangle {
                    id: sc
                    property string which
                    property string icon
                    property string label
                    property bool   isSet
                    width: (parent.width - parent.spacing) / 2
                    height: 46; radius: Theme.radiusM
                    color: _scArea.pressed ? System.surface2 : "transparent"
                    border.color: System.border; border.width: 1

                    SvgIcon {
                        id: _scIcon
                        anchors { left: parent.left; leftMargin: Theme.spaceM
                                  verticalCenter: parent.verticalCenter }
                        size: 18; source: sc.icon
                        color: sc.isSet ? System.accent : System.textSecondary
                    }
                    Text {
                        anchors { left: _scIcon.right; leftMargin: Theme.spaceS
                                  right: parent.right; rightMargin: Theme.spaceS
                                  verticalCenter: parent.verticalCenter }
                        text: sc.label
                        color: sc.isSet ? System.textPrimary : System.textMuted
                        font.pixelSize: Theme.fontLabel; font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    MouseArea { id: _scArea; anchors.fill: parent
                                onClicked: root._placeTap(sc.which) }
                }

                Shortcut {
                    which: "home"; icon: "qrc:/icons/home.svg"; label: "Casa"
                    isSet: RoadInfo.home && RoadInfo.home.lat !== undefined
                }
                Shortcut {
                    which: "work"; icon: "qrc:/icons/work.svg"; label: "Trabalho"
                    isSet: RoadInfo.work && RoadInfo.work.lat !== undefined
                }
            }

            // Tabs (Recentes / Favoritos) — hidden while typing
            Row {
                width: parent.width
                visible: !root._typing
                spacing: Theme.spaceL

                Repeater {
                    model: [{ k: "recentes", t: "Recentes" }, { k: "favoritos", t: "Favoritos" }]
                    Item {
                        required property var modelData
                        width: _tabTxt.width; height: 30
                        Text {
                            id: _tabTxt
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.t
                            color: root.tab === modelData.k ? System.textPrimary : System.textMuted
                            font.pixelSize: Theme.fontLabel
                            font.weight: root.tab === modelData.k ? Font.Bold : Font.Normal
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 2; radius: 1; color: System.accent
                            visible: root.tab === modelData.k
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.tab = modelData.k }
                    }
                }
            }

            // Empty hint
            Text {
                width: parent.width
                visible: root._items.length === 0
                text: root._typing ? "Buscando…"
                    : root.tab === "favoritos" ? "Sem favoritos ainda."
                    : "Sem destinos recentes."
                color: System.textMuted; font.pixelSize: Theme.fontLabel
                topPadding: Theme.spaceS; bottomPadding: Theme.spaceS
            }

            // Results / recents / favorites list
            ListView {
                width: parent.width
                height: Math.min(contentHeight, Theme.btnMedium * 4)
                visible: root._items.length > 0
                model: root._items
                clip: true
                interactive: contentHeight > height
                spacing: 0

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 56

                    readonly property bool _isResult: root._typing
                    readonly property var _coord: _isResult ? modelData.coordinate
                        : QtPositioning.coordinate(modelData.lat, modelData.lon)
                    readonly property string _name: _isResult
                        ? modelData.address
                        : (modelData.name && modelData.name.length ? modelData.name : modelData.address)
                    readonly property string _sub: _isResult ? "" : (modelData.address || "")

                    Rectangle { anchors.fill: parent
                                color: _rowArea.pressed ? System.surface2 : "transparent" }

                    SvgIcon {
                        id: _rowIcon
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        size: 20; color: System.textSecondary
                        source: root._typing ? "qrc:/icons/search.svg"
                              : root.tab === "favoritos" ? "qrc:/icons/star.svg"
                              : "qrc:/icons/clock.svg"
                    }
                    Column {
                        anchors {
                            left: _rowIcon.right; leftMargin: Theme.spaceM
                            right: _rowDist.left; rightMargin: Theme.spaceS
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 1
                        Text { width: parent.width; text: parent.parent._name
                               color: System.textPrimary; font.pixelSize: Theme.fontLabel
                               elide: Text.ElideRight }
                        Text { width: parent.width; visible: parent.parent._sub !== ""
                               text: parent.parent._sub
                               color: System.textMuted; font.pixelSize: 12
                               elide: Text.ElideRight }
                    }
                    Text {
                        id: _rowDist
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: root._distStr(_coord.latitude, _coord.longitude)
                        color: System.textSecondary; font.pixelSize: 12
                    }
                    Rectangle { visible: index < root._items.length - 1
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 1; color: System.border }

                    MouseArea { id: _rowArea; anchors.fill: parent
                                onClicked: root._pick(parent._coord, parent._name, parent._sub) }
                }
            }
        }
    }
}
