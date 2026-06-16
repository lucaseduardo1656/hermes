import QtQuick
import Elise

// Compact map search bar. Tap → SoftKeyboard pops up from the
// bottom; as the user types, the typed text appears live in the
// bar itself (no waiting for submit) and geocoding fires debounced.
// Picking a suggestion sets the CarMap destination.
Item {
    id: root

    property var map: null

    property string query:   ""
    property var    results: []
    property bool   open:    false

    // True while THIS bar owns the global keyboard. Lets us bind to
    // Keyboard.buffer for live text without colliding with other
    // keyboard consumers (settings password, etc).
    readonly property bool _editing:
        Keyboard.active && Keyboard.title === "Buscar endereço"

    // True when a destination is set and we're not actively editing — the
    // bar then becomes a persistent "navigating to X" header.
    readonly property bool _navigating:
        map && map.hasDestination && !_editing

    implicitHeight: open ? (_field.height + 6 + _list.implicitHeight)
                         : _field.height

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad }
    }

    // Debounce geocode calls — fire 350ms after the user stops typing.
    Timer {
        id: _geoDebounce
        interval: 600
        repeat: false
        onTriggered: {
            const q = root.query.trim()
            if (q.length < 3 || !root.map) return
            root.map.geocode(q, function(items) {
                root.results = items
                root.open = items.length > 0
            })
        }
    }

    // Live text: while keyboard is up for us, mirror its buffer.
    onQueryChanged: _geoDebounce.restart()
    Connections {
        target: Keyboard
        function onBufferChanged() {
            if (root._editing) root.query = Keyboard.buffer
        }
    }

    // ── Field ────────────────────────────────────────────────────────────────
    Rectangle {
        id: _field
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root._navigating ? 60 : Theme.btnMedium
        radius: Theme.radiusM
        color: System.surface
        border.color: root._editing ? System.accent : System.border
        border.width: 1
        Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad } }

        // Leading icon: navigation arrow while routing, search otherwise.
        SvgIcon {
            id: _leadIcon
            anchors { left: parent.left; leftMargin: Theme.spaceM
                      verticalCenter: parent.verticalCenter }
            source: root._navigating ? "qrc:/icons/arrow-straight.svg" : "qrc:/icons/search.svg"
            color:  root._navigating ? System.accent : System.textMuted
            size:   root._navigating ? Theme.iconS : Theme.iconXS
        }

        // Content: "Navegando → name" while routing, else query/placeholder.
        Column {
            anchors {
                left: _leadIcon.right; leftMargin: Theme.spaceM
                right: _clearChip.visible ? _clearChip.left : parent.right
                rightMargin: Theme.spaceS
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            Text {
                visible: root._navigating
                width: parent.width
                text: "NAVEGANDO"
                color: System.accent
                font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.2
            }
            Text {
                width: parent.width
                text: root._navigating
                        ? (root.map.destinationName || "Destino")
                        : (root.query !== "" ? root.query : "Para onde?")
                color: root._navigating || root.query !== ""
                         ? System.textPrimary : System.textMuted
                font.pixelSize: Theme.fontLabel
                font.weight: root._navigating ? Font.Bold : Font.Normal
                elide: Text.ElideRight
            }
        }

        // Clear / cancel chip (clears destination or query).
        Rectangle {
            id: _clearChip
            visible: (root.map && root.map.hasDestination) || root.query !== ""
            anchors {
                right: parent.right; rightMargin: Theme.spaceXS
                verticalCenter: parent.verticalCenter
            }
            width: Theme.btnSmall; height: Theme.btnSmall
            radius: width / 2
            color: _clearArea.pressed ? System.pressOverlay : "transparent"
            SvgIcon {
                anchors.centerIn: parent
                source: "qrc:/icons/close.svg"
                color:  System.textSecondary
                size:   Theme.iconXS
            }
            MouseArea {
                id: _clearArea
                anchors.fill: parent
                onClicked: {
                    if (root.map) root.map.clearDestination()
                    root.query = ""
                    root.results = []
                    root.open = false
                }
            }
        }

        // Tapping the field (outside the chip) opens the keyboard to search.
        MouseArea {
            anchors {
                fill: parent
                rightMargin: _clearChip.visible
                               ? Theme.btnSmall + Theme.spaceXS * 2 : 0
            }
            onClicked: {
                Keyboard.show({
                    title:    "Buscar endereço",
                    bare:     true,
                    initial:  root.query,
                    onSubmit: function(text) {
                        root.query = text
                        if (root.results.length === 0 && root.map && text.trim().length >= 3) {
                            root.map.geocode(text, function(items) {
                                root.results = items
                                root.open = items.length > 0
                            })
                        }
                    },
                    onCancel: function() {
                        if (root.query === "") root.open = false
                    }
                })
            }
        }
    }

    // ── Suggestion list ──────────────────────────────────────────────────────
    Rectangle {
        id: _list
        anchors {
            left: parent.left; right: parent.right
            top: _field.bottom; topMargin: Theme.spaceXS
        }
        radius: Theme.radiusM
        color: System.surface
        border.color: System.border
        border.width: 1

        implicitHeight: visible
                          ? Math.min(_results.contentHeight + 2,
                                     Theme.btnMedium * 5 + 2)
                          : 0
        visible: root.open && root.results.length > 0
        clip: true

        ListView {
            id: _results
            anchors { fill: parent; margins: 1 }
            model: root.results
            spacing: 0
            delegate: Item {
                required property var modelData
                required property int index
                width:  ListView.view.width
                height: Theme.btnMedium

                Rectangle {
                    anchors.fill: parent
                    color: _tap.pressed ? System.pressOverlay : "transparent"
                }
                Text {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.spaceM; rightMargin: Theme.spaceM
                    }
                    text: modelData.address
                    color: System.textPrimary
                    font.pixelSize: Theme.fontLabel
                    elide: Text.ElideRight
                }
                Rectangle {
                    visible: index < _results.count - 1
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: System.border
                }
                MouseArea {
                    id: _tap
                    anchors.fill: parent
                    onClicked: {
                        if (root.map)
                            root.map.setDestination(modelData.coordinate, modelData.address)
                        root.query = ""
                        root.open  = false
                        // Close the keyboard if still up.
                        if (Keyboard.active) Keyboard.dismiss()
                    }
                }
            }
        }
    }
}
