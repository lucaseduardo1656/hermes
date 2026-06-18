import QtQuick
import QtQuick.Controls
import Elise

// Page: Audio — Caelestia layout (#19). Two grouped blocks (Output / Input),
// each a slider + Muted toggle + device row, then an "App volumes" row.
//
// Wired to the controller: Output volume + Output Muted (PipeWire via wpctl).
// Input + per-app volumes have no backend on this hardware (single speaker
// sink, no capture), so those controls are cosmetic placeholders.
Flickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: _col.height
    boundsBehavior: Flickable.StopAtBounds

    // Cosmetic state for the Input block (no capture device on this unit).
    property int  _inputVol:   58
    property bool _inputMuted: true

        Column {
            id: _col
            width: parent.width
            spacing: Theme.spaceL

            // ── Output block ──────────────────────────────────────────────
            Rectangle {
                width: parent.width; height: _outCol.height
                radius: Theme.radiusL; color: Qt.rgba(1,1,1,0.05); clip: true
                Column {
                    id: _outCol
                    width: parent.width

                    // slider row
                    Item {
                        width: parent.width; height: 88
                        Item {
                            id: _outTop
                            anchors { top: parent.top; topMargin: 16
                                      left: parent.left; leftMargin: Theme.spaceL
                                      right: parent.right; rightMargin: Theme.spaceL }
                            height: Theme.fontLabel + 2
                            Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                   text: "Output"; color: System.textPrimary; font.pixelSize: Theme.fontLabel
                                   font.weight: Font.Medium }
                            Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                   text: Settings.audio.volume + "%"; color: System.accent
                                   font.pixelSize: Theme.fontLabel; font.weight: Font.Medium }
                        }
                        Item {
                            anchors { top: _outTop.bottom; topMargin: 12
                                      left: parent.left; leftMargin: Theme.spaceL
                                      right: parent.right; rightMargin: Theme.spaceL }
                            height: 30
                            SvgIcon { id: _outIcon
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                source: "qrc:/icons/speaker.svg"; color: System.textSecondary; size: Theme.iconS }
                            StyledSlider {
                                id: _outSlider
                                anchors { left: parent.left; leftMargin: Theme.iconS + Theme.spaceM
                                          right: parent.right; verticalCenter: parent.verticalCenter }
                                height: 28
                                value: Settings.audio.volume / 100
                                onInteraction: (v) => Settings.audio.setVolume(Math.round(v * 100))
                            }
                        }
                    }
                    Rectangle { width: parent.width - Theme.spaceL*2; x: Theme.spaceL
                                height: 1; color: Qt.rgba(1,1,1,0.06) }

                    // muted row
                    Item {
                        width: parent.width; height: 56
                        Rectangle { anchors.fill: parent
                                    color: _outMuteArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                        Text { anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                               text: "Muted"; color: System.textPrimary; font.pixelSize: Theme.fontBody }
                        StyledSwitch { id: _outMute
                            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                            checked: Settings.audio.muted
                            onToggled: Settings.audio.setMuted(checked) }
                        MouseArea { id: _outMuteArea
                            anchors { left: parent.left; right: _outMute.left; top: parent.top; bottom: parent.bottom }
                            onClicked: Settings.audio.setMuted(!Settings.audio.muted) }
                    }
                    Rectangle { width: parent.width - Theme.spaceL*2; x: Theme.spaceL
                                height: 1; color: Qt.rgba(1,1,1,0.06) }

                    // device row (single vehicle sink, always selected)
                    Item {
                        width: parent.width; height: 64
                        Rectangle { id: _outBadge
                            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                            width: 38; height: 38; radius: width / 2
                            color: Qt.rgba(System.accent.r, System.accent.g, System.accent.b, 0.22)
                            SvgIcon { anchors.centerIn: parent; source: "qrc:/icons/speaker.svg"
                                      color: System.accent; size: Theme.iconS } }
                        Text { anchors { left: _outBadge.right; leftMargin: Theme.spaceM
                                         right: _outCheck.left; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
                               text: "Alto-falantes do veículo"; color: System.textPrimary
                               font.pixelSize: Theme.fontBody; elide: Text.ElideRight }
                        SvgIcon { id: _outCheck
                            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                            source: "qrc:/icons/check.svg"; color: System.accent; size: Theme.iconS }
                    }
                }
            }

            // ── Input block (cosmetic — no capture device) ────────────────
            Rectangle {
                width: parent.width; height: _inCol.height
                radius: Theme.radiusL; color: Qt.rgba(1,1,1,0.05); clip: true
                Column {
                    id: _inCol
                    width: parent.width

                    Item {
                        width: parent.width; height: 88
                        Item {
                            id: _inTop
                            anchors { top: parent.top; topMargin: 16
                                      left: parent.left; leftMargin: Theme.spaceL
                                      right: parent.right; rightMargin: Theme.spaceL }
                            height: Theme.fontLabel + 2
                            Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                   text: "Input"; color: System.textPrimary; font.pixelSize: Theme.fontLabel
                                   font.weight: Font.Medium }
                            Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                   text: root._inputVol + "%"; color: System.accent
                                   font.pixelSize: Theme.fontLabel; font.weight: Font.Medium }
                        }
                        Item {
                            anchors { top: _inTop.bottom; topMargin: 12
                                      left: parent.left; leftMargin: Theme.spaceL
                                      right: parent.right; rightMargin: Theme.spaceL }
                            height: 30
                            SvgIcon { id: _inIcon
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                source: "qrc:/icons/mic-fill.svg"; color: System.textSecondary; size: Theme.iconS }
                            StyledSlider {
                                id: _inSlider
                                anchors { left: parent.left; leftMargin: Theme.iconS + Theme.spaceM
                                          right: parent.right; verticalCenter: parent.verticalCenter }
                                height: 28
                                value: root._inputVol / 100
                                onInteraction: (v) => root._inputVol = Math.round(v * 100)
                            }
                        }
                    }
                    Rectangle { width: parent.width - Theme.spaceL*2; x: Theme.spaceL
                                height: 1; color: Qt.rgba(1,1,1,0.06) }

                    Item {
                        width: parent.width; height: 56
                        Rectangle { anchors.fill: parent
                                    color: _inMuteArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                        Text { anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                               text: "Muted"; color: System.textPrimary; font.pixelSize: Theme.fontBody }
                        StyledSwitch { id: _inMute
                            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                            checked: root._inputMuted
                            onToggled: root._inputMuted = checked }
                        MouseArea { id: _inMuteArea
                            anchors { left: parent.left; right: _inMute.left; top: parent.top; bottom: parent.bottom }
                            onClicked: root._inputMuted = !root._inputMuted }
                    }
                    Rectangle { width: parent.width - Theme.spaceL*2; x: Theme.spaceL
                                height: 1; color: Qt.rgba(1,1,1,0.06) }

                    Item {
                        width: parent.width; height: 64
                        Rectangle { id: _inBadge
                            anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                            width: 38; height: 38; radius: width / 2
                            color: Qt.rgba(System.accent.r, System.accent.g, System.accent.b, 0.22)
                            SvgIcon { anchors.centerIn: parent; source: "qrc:/icons/mic-fill.svg"
                                      color: System.accent; size: Theme.iconS } }
                        Text { anchors { left: _inBadge.right; leftMargin: Theme.spaceM
                                         right: _inCheck.left; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
                               text: "Microfone interno"; color: System.textPrimary
                               font.pixelSize: Theme.fontBody; elide: Text.ElideRight }
                        SvgIcon { id: _inCheck
                            anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                            source: "qrc:/icons/check.svg"; color: System.accent; size: Theme.iconS }
                    }
                }
            }

            // ── App volumes row ───────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 66
                radius: Theme.radiusL; color: Qt.rgba(1,1,1,0.05); clip: true
                Rectangle { anchors.fill: parent
                            color: _appArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                Rectangle { id: _appBadge
                    anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                    width: 36; height: 36; radius: 18; color: System.surface2
                    SvgIcon { anchors.centerIn: parent; source: "qrc:/icons/sliders.svg"
                              color: System.textSecondary; size: Theme.iconS } }
                Column {
                    anchors { left: _appBadge.right; leftMargin: Theme.spaceM
                              right: _appChevron.left; rightMargin: Theme.spaceS; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Text { text: "App volumes"; color: System.textPrimary
                           font.pixelSize: Theme.fontBody; font.weight: Font.Medium }
                    Text { text: "Nenhum app tocando áudio"; color: System.textSecondary
                           font.pixelSize: 12 }
                }
                SvgIcon { id: _appChevron
                    anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                    source: "qrc:/icons/chevron-right.svg"; color: System.textSecondary; size: Theme.iconS }
                MouseArea { id: _appArea; anchors.fill: parent }
            }
        }
    }
