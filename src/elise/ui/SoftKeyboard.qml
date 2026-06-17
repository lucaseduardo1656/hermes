import QtQuick
import Elise

// Global on-screen keyboard, Tesla Model 3/Y style. Driven by the
// `Keyboard` singleton and mounted once in Main.qml.
//
// Layout: a light bottom tray holding a QWERTY block on the left and a
// permanent 3×3+0 number pad on the right (no digit toggle needed). The
// `?#&` key swaps the letter block for symbols; ⇧ shifts case. In normal
// (non-bare) mode a floating card above the tray shows the title, the live
// buffer with a blinking caret and Cancel/Confirm. In bare mode (map
// search) the card is hidden — the caller renders its own input surface.
Item {
    id: root
    anchors.fill: parent
    visible: Keyboard.active

    // ── State ───────────────────────────────────────────────────────────
    property bool _shift:   false
    property bool _symbols: false
    property bool _revealPwd: false

    Connections {
        target: Keyboard
        function onActiveChanged() {
            if (!Keyboard.active) { root._revealPwd = false; root._symbols = false; root._shift = false }
        }
    }

    // ── Layout data (ABNT2 / pt-BR) ─────────────────────────────────────
    // Each row: { indent (in key-units), keys: [...] }. Row 1 carries the
    // ç dedicated key like a physical ABNT2 board; accented vowels come from
    // long-pressing the base vowel (variant popup).
    readonly property var _letterRows: [
        { indent: 0.0, keys: ["q","w","e","r","t","y","u","i","o","p"] },
        { indent: 0.0, keys: ["a","s","d","f","g","h","j","k","l","ç"] },
        { indent: 0.0, keys: ["z","x","c","v","b","n","m","-",",","."] }
    ]
    readonly property var _symbolRows: [
        { indent: 0.0, keys: ["@","#","$","%","&","*","-","+","(",")"] },
        { indent: 0.0, keys: ["=","/","\\","'","\"",":",";","!","?","°"] },
        { indent: 0.0, keys: ["~","_","|","€","£","¢","§","ª","º","…"] }
    ]
    readonly property var _rows: _symbols ? _symbolRows : _letterRows
    function _cap(c) { return (_shift && !_symbols) ? c.toUpperCase() : c }

    // Accented variants offered on long-press (pt-BR).
    readonly property var _variantMap: ({
        "a": "áàâãä", "e": "éèêë", "i": "íìî", "o": "óòôõö",
        "u": "úùûü",  "c": "ç",    "n": "ñ"
    })
    function _variants(c) {
        const v = _variantMap[c.toLowerCase()]
        if (!v) return []
        const arr = v.split("")
        return (_shift && !_symbols) ? arr.map(function(x){ return x.toUpperCase() }) : arr
    }

    // ── Accent variant popup ────────────────────────────────────────────
    property var  _popupKeys: []
    property real _popupX: 0
    property real _popupY: 0
    property bool _popupOpen: false
    function _openVariants(keyItem, base) {
        const vs = _variants(base)
        if (vs.length === 0) return
        const p = keyItem.mapToItem(root, 0, 0)
        root._popupKeys = vs
        root._popupX = p.x + keyItem.width / 2
        root._popupY = p.y
        root._popupOpen = true
    }

    // ── Metrics / palette ───────────────────────────────────────────────
    readonly property int   _keyW: 58
    readonly property int   _keyH: 52
    readonly property int   _gap:  8
    readonly property color _panelBg: "#ECECE8"
    readonly property color _capDn:   "#DCDCD8"   // letter press feedback
    readonly property color _pill:    "#D7D7D2"   // special-key fill
    readonly property color _pillDn:  "#C2C2BD"
    readonly property color _txt:     "#1A1A1A"
    readonly property color _txtMute: "#9A9A95"
    readonly property color _accent:  System.accent

    // One key. Flat (text only) by default; `pill` gives the gray fill used
    // by action keys; `active` highlights toggles (⇧, ?#&).
    component Key: Rectangle {
        id: key
        property string label:    ""
        property string icon:     ""
        property string baseChar: ""        // raw char, for accent variants
        property bool   pill:      false
        property bool   active:    false
        property real   cells:     1
        property real   fontPx:    23
        property bool   enabledKey: true
        property bool   _held:     false
        signal tap()

        width:  cells * root._keyW + (cells - 1) * root._gap
        height: root._keyH
        radius: 11
        // No color animation — a fade on quick taps reads as flicker.
        color: active ? root._accent
             : !pill   ? (_a.pressed ? root._capDn : "transparent")
             :           (_a.pressed ? root._pillDn : root._pill)
        opacity: enabledKey ? 1 : 0.3

        // Long-press affordance dot for keys with accent variants.
        Rectangle {
            visible: root._variants(key.baseChar).length > 1
            width: 5; height: 5; radius: 2.5
            color: root._txtMute
            anchors { top: parent.top; right: parent.right; margins: 5 }
        }

        Text {
            anchors.centerIn: parent
            visible: key.icon === ""
            text: key.label
            color: key.active ? "#000000" : root._txt
            font.pixelSize: key.fontPx
            font.weight: Font.Medium
        }
        SvgIcon {
            anchors.centerIn: parent
            visible: key.icon !== ""
            source: key.icon
            color:  key.active ? "#000000" : root._txt
            size:   24
        }
        MouseArea {
            id: _a; anchors.fill: parent
            enabled: key.enabledKey
            pressAndHoldInterval: 320
            onPressAndHold: {
                if (root._variants(key.baseChar).length > 0) {
                    key._held = true
                    root._openVariants(key, key.baseChar)
                }
            }
            onClicked: {
                if (key._held) { key._held = false; return }
                key.tap()
            }
        }
    }

    // ── Dim layer (tap outside dismisses; hidden in bare mode) ───────────
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: !Keyboard.bare
        MouseArea { anchors.fill: parent; onClicked: Keyboard.dismiss() }
    }

    // ── Floating input card (non-bare) ──────────────────────────────────
    Rectangle {
        id: _card
        visible: !Keyboard.bare
        x: (parent.width - width) / 2
        y: (parent.height - _tray.height - height) / 2
        width:  Math.min(parent.width - Theme.spaceXXL * 2, 520)
        height: _cardCol.implicitHeight + Theme.spaceL * 2
        radius: Theme.radiusL
        color:  System.surface
        border.color: System.border
        border.width: Theme.borderHairline

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: _cardCol
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: Theme.spaceL; rightMargin: Theme.spaceL; topMargin: Theme.spaceL
            }
            spacing: Theme.spaceM

            Text {
                width: parent.width
                visible: Keyboard.title !== ""
                text:  Keyboard.title
                color: System.textPrimary
                font.pixelSize: Theme.fontTitle; font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width; height: 44
                color: System.surface2; radius: Theme.radiusM
                border.color: System.accent; border.width: Theme.borderHairline

                Item {
                    anchors {
                        left: parent.left; leftMargin: Theme.spaceM
                        right: _eye.left;  rightMargin: Theme.spaceM
                        verticalCenter: parent.verticalCenter
                    }
                    height: Theme.fontTitle + 4
                    clip: true

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool _masked: Keyboard.password && !root._revealPwd
                        readonly property string _pre: _masked
                            ? "•".repeat(Keyboard.cursorPos)
                            : Keyboard.buffer.slice(0, Keyboard.cursorPos)
                        readonly property string _post: _masked
                            ? "•".repeat(Keyboard.buffer.length - Keyboard.cursorPos)
                            : Keyboard.buffer.slice(Keyboard.cursorPos)

                        Text {
                            text: parent._pre; color: System.textPrimary
                            font.pixelSize: Theme.fontTitle
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 2; height: Theme.fontTitle + 2; color: System.accent
                            anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite; running: Keyboard.active
                                PauseAnimation  { duration: 550 }
                                NumberAnimation { to: 0; duration: 80 }
                                PauseAnimation  { duration: 280 }
                                NumberAnimation { to: 1; duration: 0 }
                            }
                        }
                        Text {
                            text: parent._post; color: System.textPrimary
                            font.pixelSize: Theme.fontTitle
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    id: _eye
                    anchors { right: parent.right; rightMargin: Theme.spaceXS
                              verticalCenter: parent.verticalCenter }
                    width: 36; height: 36; radius: width / 2
                    color: _eyeArea.pressed ? System.pressOverlay : "transparent"
                    visible: Keyboard.password
                    SvgIcon {
                        anchors.centerIn: parent
                        source: root._revealPwd ? "qrc:/icons/eye-off.svg" : "qrc:/icons/eye.svg"
                        color: System.textMuted; size: Theme.iconM
                    }
                    MouseArea { id: _eyeArea; anchors.fill: parent
                                onClicked: root._revealPwd = !root._revealPwd }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceM

                Rectangle {
                    width: 110; height: 40; radius: Theme.radiusM
                    color: _cancelArea.pressed ? System.pressOverlay : "transparent"
                    border.color: System.border; border.width: Theme.borderHairline
                    Text { anchors.centerIn: parent; text: "Cancelar"
                           color: System.textPrimary; font.pixelSize: Theme.fontMedium }
                    MouseArea { id: _cancelArea; anchors.fill: parent
                                onClicked: Keyboard.dismiss() }
                }
                Rectangle {
                    width: 110; height: 40; radius: Theme.radiusM
                    color: _okArea.pressed ? Qt.darker(System.accent, 1.2) : System.accent
                    Text { anchors.centerIn: parent; text: "Confirmar"
                           color: System.background; font.pixelSize: Theme.fontMedium
                           font.weight: Font.Medium }
                    MouseArea { id: _okArea; anchors.fill: parent
                                onClicked: Keyboard.submit() }
                }
            }
        }
    }

    // ── Key tray ────────────────────────────────────────────────────────
    Rectangle {
        id: _tray
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: _trayRow.height + Theme.spaceL * 2
        color: root._panelBg

        MouseArea { anchors.fill: parent; onClicked: {} }   // block dim dismissal

        Row {
            id: _trayRow
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.spaceL }
            spacing: Theme.spaceXL

            // ── QWERTY block ──────────────────────────────────────────────
            Column {
                spacing: root._gap

                // Letter rows + trailing action key (backspace / enter).
                Repeater {
                    model: root._rows
                    Row {
                        required property var modelData
                        required property int index
                        spacing: root._gap

                        Item { width: modelData.indent * (root._keyW + root._gap); height: 1 }

                        Repeater {
                            model: modelData.keys
                            Key {
                                required property string modelData
                                label:    root._cap(modelData)
                                baseChar: modelData
                                onTap: Keyboard.append(label)
                            }
                        }

                        // backspace on row 0, enter on row 1
                        Key {
                            visible: index === 0
                            icon: "qrc:/icons/backspace.svg"
                            pill: true; cells: 1.6
                            onTap: Keyboard.backspace()
                        }
                        Key {
                            visible: index === 1
                            label: "Enter"; fontPx: 18
                            pill: true; cells: 2.0
                            onTap: Keyboard.submit()
                        }
                    }
                }

                // Bottom row: shift · globe · mic · space · ?#& · ◀ · ▶
                Row {
                    spacing: root._gap

                    Key { icon: "qrc:/icons/shift.svg"; pill: true; cells: 1.4
                          active: root._shift && !root._symbols
                          onTap: root._shift = !root._shift }
                    Key { icon: "qrc:/icons/globe.svg"; pill: true; enabledKey: false }
                    Key { icon: "qrc:/icons/mic.svg";   pill: true; enabledKey: false }
                    Key { label: ""; pill: true; cells: 4.6; onTap: Keyboard.append(" ") }
                    Key { label: "?#&"; fontPx: 18; pill: true; cells: 1.4; active: root._symbols
                          onTap: root._symbols = !root._symbols }
                    Key { icon: "qrc:/icons/chevron-left.svg";  pill: true; onTap: Keyboard.cursorLeft() }
                    Key { icon: "qrc:/icons/chevron-right.svg"; pill: true; onTap: Keyboard.cursorRight() }
                }
            }

            // ── Number pad ────────────────────────────────────────────────
            Column {
                spacing: root._gap

                Repeater {
                    model: [["1","2","3"], ["4","5","6"], ["7","8","9"]]
                    Row {
                        required property var modelData
                        spacing: root._gap
                        Repeater {
                            model: modelData
                            Key {
                                required property string modelData
                                label: modelData
                                onTap: Keyboard.append(label)
                            }
                        }
                    }
                }
                Key { label: "0"; cells: 3; onTap: Keyboard.append("0") }
            }
        }
    }

    // ── Accent variant popup (long-press a vowel / c / n) ───────────────
    Item {
        anchors.fill: parent
        visible: root._popupOpen
        z: 50

        // Tap anywhere outside the strip closes without inserting.
        MouseArea { anchors.fill: parent; onClicked: root._popupOpen = false }

        Rectangle {
            x: Math.max(8, Math.min(root._popupX - width / 2, root.width - width - 8))
            y: root._popupY - height - 8
            width: _vRow.width + 12; height: root._keyH + 12
            radius: 12
            color: "#FFFFFF"
            border.color: root._pill; border.width: 1

            Row {
                id: _vRow
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: root._popupKeys
                    Rectangle {
                        required property string modelData
                        width: root._keyW; height: root._keyH; radius: 10
                        color: _vArea.pressed ? root._capDn : "transparent"
                        Text {
                            anchors.centerIn: parent; text: modelData
                            color: root._txt; font.pixelSize: 23; font.weight: Font.Medium
                        }
                        MouseArea {
                            id: _vArea; anchors.fill: parent
                            onClicked: { Keyboard.append(modelData); root._popupOpen = false }
                        }
                    }
                }
            }
        }
    }
}
