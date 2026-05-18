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
        height: Theme.btnMedium
        radius: Theme.radiusM
        color: System.surface
        border.color: root._editing ? System.accent : System.border
        border.width: 1

        Row {
            anchors {
                fill: parent
                leftMargin: Theme.spaceM; rightMargin: Theme.spaceM
            }
            spacing: Theme.spaceS

            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/icons/search.svg"
                color:  System.textMuted
                size:   Theme.iconXS
            }
            Text {
                id: _txt
                anchors.verticalCenter: parent.verticalCenter
                text:  root.query !== "" ? root.query : "Para onde?"
                color: root.query !== "" ? System.textPrimary : System.textMuted
                font.pixelSize: Theme.fontLabel
                width: parent.width - Theme.iconXS - Theme.spaceS
                       - (root.map && root.map.hasDestination
                            ? Theme.btnSmall + Theme.spaceS : 0)
                elide: Text.ElideRight
            }
        }

        // Clear destination chip.
        Rectangle {
            visible: root.map && root.map.hasDestination
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

        MouseArea {
            anchors {
                fill: parent
                rightMargin: root.map && root.map.hasDestination
                               ? Theme.btnSmall + Theme.spaceXS * 2 : 0
            }
            onClicked: {
                Keyboard.show({
                    title:    "Buscar endereço",
                    bare:     true,
                    initial:  root.query,
                    onSubmit: function(text) {
                        // Submit just closes the keyboard; live updates
                        // already populated results and the query.
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
                            root.map.setDestination(modelData.coordinate)
                        root.query = modelData.address
                        root.open  = false
                        // Close the keyboard if still up.
                        if (Keyboard.active) Keyboard.dismiss()
                    }
                }
            }
        }
    }
}
