import QtQuick
import Elise

// Global on-screen keyboard + input modal. Driven by the `Keyboard`
// singleton; mounted once in Main.qml. Tesla Model 3-style:
//
//   * dim overlay covers the rest of the screen (taps outside dismiss)
//   * floating modal card near the top with title + buffer + Cancel/OK
//   * bottom tray with QWERTY pill keys
//
// Letter keys have no visible pill (just text); special keys (←, ENTER,
// modifiers, ?#&, .com, space, <, >, mic) sit on light gray pills.
Item {
    id: root
    anchors.fill: parent
    visible: Keyboard.active

    property bool _shift:  false
    property bool _digits: false

    readonly property var _abcLow: [
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l"],
        ["z","x","c","v","b","n","m"]
    ]
    readonly property var _num: [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["@","#","$","%","&","*","-","_","="],
        ["!","?",";",":","/","\\","'"]
    ]

    function _layout() { return _digits ? _num : _abcLow }
    function _shifted(c) { return _shift && !_digits ? c.toUpperCase() : c }

    readonly property int   _keyH:    52
    readonly property int   _keyW:    62
    readonly property int   _gap:     8
    readonly property color _panelBg: "#ECECE8"
    readonly property color _pill:    "#D8D8D4"
    readonly property color _pillDn:  "#BFBFBC"
    readonly property color _txt:     "#1A1A1A"
    readonly property color _txtMute: "#6B7280"

    // ── Dim layer (tap outside = dismiss) ───────────────────────────────
    // Hidden in bare mode — the caller (e.g. map search bar) keeps
    // showing its own input surface and we don't want to blanket the
    // screen.
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: !Keyboard.bare
        MouseArea {
            anchors.fill: parent
            enabled: !Keyboard.bare
            onClicked: Keyboard.dismiss()
        }
    }

    property bool _revealPwd: false

    Connections {
        target: Keyboard
        function onActiveChanged() { if (!Keyboard.active) root._revealPwd = false }
    }

    // ── Floating modal card ─────────────────────────────────────────────
    // Vertically centered in the area ABOVE the bottom key tray.
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

        // Eat clicks so dim doesn't dismiss when interacting with the card.
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: _cardCol
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: Theme.spaceL; rightMargin: Theme.spaceL
                topMargin: Theme.spaceL
            }
            spacing: Theme.spaceM

            Text {
                text:  Keyboard.title
                color: System.textPrimary
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: parent.width
                visible: Keyboard.title !== ""
            }

            Rectangle {
                width:  parent.width
                height: 44
                color:  System.surface2
                radius: Theme.radiusM
                border.color: System.accent
                border.width: Theme.borderHairline

                // Buffer display with inline cursor.
                // Clipped so overflow hides rather than pushes the eye icon.
                Item {
                    anchors {
                        left: parent.left; leftMargin: Theme.spaceM
                        right: _eye.left; rightMargin: Theme.spaceM
                        verticalCenter: parent.verticalCenter
                    }
                    height: Theme.fontTitle + 4
                    clip: true

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        verticalAlignment: Row.AlignVCenter

                        readonly property bool _masked:
                            Keyboard.password && !root._revealPwd
                        readonly property string _pre:
                            _masked ? "•".repeat(Keyboard.cursorPos)
                                    : Keyboard.buffer.slice(0, Keyboard.cursorPos)
                        readonly property string _post:
                            _masked ? "•".repeat(Keyboard.buffer.length - Keyboard.cursorPos)
                                    : Keyboard.buffer.slice(Keyboard.cursorPos)

                        Text {
                            text:  parent._pre
                            color: System.textPrimary
                            font.pixelSize: Theme.fontTitle
                        }
                        Rectangle {
                            width: 2; height: Theme.fontTitle + 2
                            color: System.accent
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: Keyboard.active
                                PauseAnimation  { duration: 550 }
                                NumberAnimation { to: 0; duration: 80 }
                                PauseAnimation  { duration: 280 }
                                NumberAnimation { to: 1; duration: 0 }
                            }
                        }
                        Text {
                            text:  parent._post
                            color: System.textPrimary
                            font.pixelSize: Theme.fontTitle
                        }
                    }
                }

                // Eye toggle — only when input is password.
                Rectangle {
                    id: _eye
                    anchors {
                        right: parent.right; rightMargin: Theme.spaceXS
                        verticalCenter: parent.verticalCenter
                    }
                    width: 36; height: 36; radius: width / 2
                    color: _eyeArea.pressed ? System.pressOverlay : "transparent"
                    visible: Keyboard.password
                    SvgIcon {
                        anchors.centerIn: parent
                        source: root._revealPwd ? "qrc:/icons/eye-off.svg"
                                                : "qrc:/icons/eye.svg"
                        color:  System.textMuted
                        size:   Theme.iconM
                    }
                    MouseArea { id: _eyeArea
                        anchors.fill: parent
                        onClicked: root._revealPwd = !root._revealPwd
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceM

                Rectangle {
                    width: 110; height: 40; radius: Theme.radiusM
                    color: _cancelArea.pressed ? System.pressOverlay : "transparent"
                    border.color: System.border
                    border.width: Theme.borderHairline
                    Text {
                        anchors.centerIn: parent
                        text: "Cancelar"; color: System.textPrimary
                        font.pixelSize: Theme.fontMedium
                    }
                    MouseArea { id: _cancelArea
                        anchors.fill: parent
                        onClicked: Keyboard.dismiss()
                    }
                }
                Rectangle {
                    width: 110; height: 40; radius: Theme.radiusM
                    color: _okArea.pressed ? Qt.darker(System.accent, 1.2) : System.accent
                    Text {
                        anchors.centerIn: parent
                        text: "Confirmar"; color: System.background
                        font.pixelSize: Theme.fontMedium; font.weight: Font.Medium
                    }
                    MouseArea { id: _okArea
                        anchors.fill: parent
                        onClicked: Keyboard.submit()
                    }
                }
            }
        }
    }

    // ── Bottom key tray ─────────────────────────────────────────────────
    Rectangle {
        id: _tray
        anchors {
            left: parent.left; right: parent.right; bottom: parent.bottom
        }
        height: _keysCol.height + Theme.spaceL * 2
        color:  root._panelBg

        // Block dim dismissal through the tray.
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: _keysCol
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top; topMargin: Theme.spaceL
            }
            spacing: root._gap

            // Row 1: q…p + backspace
            Row {
                spacing: root._gap
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: root._layout()[0]
                    KeyboardKey {
                        text:  root._shifted(modelData)
                        width: root._keyW; height: root._keyH
                        bgColor: "transparent"; downColor: root._pill; textColor: root._txt
                        onTapped: Keyboard.append(text)
                    }
                }
                KeyboardKey {
                    iconSource: "qrc:/icons/backspace.svg"
                    iconColor: root._txt
                    width: root._keyW * 1.6; height: root._keyH
                    bgColor: root._pill; downColor: root._pillDn
                    onTapped: Keyboard.backspace()
                }
            }

            // Row 2: a…l + ENTER
            Row {
                spacing: root._gap
                anchors.horizontalCenter: parent.horizontalCenter
                Item { width: root._keyW * 0.5; height: 1 }
                Repeater {
                    model: root._layout()[1]
                    KeyboardKey {
                        text:  root._shifted(modelData)
                        width: root._keyW; height: root._keyH
                        bgColor: "transparent"; downColor: root._pill; textColor: root._txt
                        onTapped: Keyboard.append(text)
                    }
                }
                KeyboardKey {
                    text: "ENTER"
                    width: root._keyW * 1.8; height: root._keyH
                    bgColor: root._pill; downColor: root._pillDn; textColor: root._txt
                    onTapped: Keyboard.submit()
                }
            }

            // Row 3: z…m (indented)
            Row {
                spacing: root._gap
                anchors.horizontalCenter: parent.horizontalCenter
                Item { width: root._keyW * 1.3; height: 1 }
                Repeater {
                    model: root._layout()[2]
                    KeyboardKey {
                        text:  root._shifted(modelData)
                        width: root._keyW; height: root._keyH
                        bgColor: "transparent"; downColor: root._pill; textColor: root._txt
                        onTapped: Keyboard.append(text)
                    }
                }
                Item { width: root._keyW * 0.6; height: 1 }
            }

            // Row 4: ^shift | mic | @ | .com | space | ?#& | < | >
            Row {
                spacing: root._gap
                anchors.horizontalCenter: parent.horizontalCenter

                KeyboardKey {
                    text:  "⇧"
                    width: root._keyW * 1.4; height: root._keyH
                    accent: !root._digits && root._shift
                    bgColor: root._pill; downColor: root._pillDn; textColor: root._txt
                    onTapped: {
                        if (root._digits) root._digits = false
                        else root._shift = !root._shift
                    }
                }
                KeyboardKey {
                    iconSource: "qrc:/icons/mic.svg"
                    iconColor: root._txt
                    width: root._keyW; height: root._keyH
                    bgColor: root._pill; downColor: root._pillDn
                    onTapped: { /* voice — placeholder */ }
                }
                KeyboardKey {
                    text:  "@"
                    width: root._keyW; height: root._keyH
                    bgColor: root._pill; downColor: root._pillDn; textColor: root._txt
                    onTapped: Keyboard.append("@")
                }
                KeyboardKey {
                    text:  ".com"
                    width: root._keyW * 1.3; height: root._keyH
                    bgColor: root._pill; downColor: root._pillDn; textColor: root._txt
                    onTapped: Keyboard.append(".com")
                }
                KeyboardKey {
                    text:  ""
                    width: root._keyW * 4.5; height: root._keyH
                    bgColor: root._pill; downColor: root._pillDn
                    onTapped: Keyboard.append(" ")
                }
                KeyboardKey {
                    text:  "?#&"
                    width: root._keyW * 1.2; height: root._keyH
                    accent: root._digits
                    bgColor: root._pill; downColor: root._pillDn; textColor: root._txt
                    onTapped: root._digits = !root._digits
                }
                KeyboardKey {
                    text:  "<"
                    width: root._keyW; height: root._keyH
                    bgColor: root._pill; downColor: root._pillDn; textColor: root._txt
                    onTapped: Keyboard.cursorLeft()
                }
                KeyboardKey {
                    text:  ">"
                    width: root._keyW; height: root._keyH
                    bgColor: root._pill; downColor: root._pillDn; textColor: root._txt
                    onTapped: Keyboard.cursorRight()
                }
            }
        }
    }
}
