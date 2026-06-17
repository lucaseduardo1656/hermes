import QtQuick
import Elise

// Page: Connected devices — Bluetooth toggle + saved devices, with a "pair new
// device" sub-view that scans. Same grouped-card layout as the Network page.
Item {
    id: root
    clip: true

    property string view: "main"      // "main" | "pair"

    // Header surfaced by SettingsMenu: in the pair sub-view the right-pane title
    // becomes "Parear novo dispositivo" + a back arrow, instead of the section
    // label "Connected devices".
    property string navTitle:  view === "pair" ? "Parear novo dispositivo" : ""
    property bool   canGoBack: view === "pair"
    function goBack() { Settings.bluetooth.stopScan(); view = "main" }

    function _saved() {
        const out = []
        const ds = Settings.bluetooth.devices
        for (let i = 0; i < ds.length; ++i) if (ds[i].paired) out.push(ds[i])
        return out
    }
    function _available() {
        const out = []
        const ds = Settings.bluetooth.devices
        for (let i = 0; i < ds.length; ++i) if (!ds[i].paired) out.push(ds[i])
        return out
    }
    function _onDeviceTap(d) {
        if (d.connected) { Settings.bluetooth.disconnectDevice(d.address); return }
        if (d.paired)    { Settings.bluetooth.connectDevice(d.address);    return }
        Settings.bluetooth.pair(d.address)
    }
    function _onDeviceOptions(d) {
        const items = []
        if (d.connected)
            items.push({ label: "Desconectar", onSelected: function() { Settings.bluetooth.disconnectDevice(d.address) } })
        else
            items.push({ label: "Conectar", onSelected: function() { Settings.bluetooth.connectDevice(d.address) } })
        items.push({ label: "Esquecer dispositivo", destructive: true,
                     onSelected: function() { Settings.bluetooth.forget(d.address) } })
        ActionSheet.show({ title: d.alias, items: items })
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.view === "main" ? _mainView : _pairView
    }

    // ── Main view ───────────────────────────────────────────────────────────
    Component {
        id: _mainView
        Flickable {
            anchors.fill: parent
            contentHeight: _outer.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: _outer
                width: parent.width
                spacing: Theme.spaceL

                // Bluetooth toggle card (first item of the group → top rounded)
                Column {
                    width: parent.width
                    spacing: Theme.spaceXS

                    Rectangle {
                        width: parent.width; height: 64
                        topLeftRadius: Theme.radiusL; topRightRadius: Theme.radiusL
                        bottomLeftRadius: 0; bottomRightRadius: 0
                        color: Qt.rgba(1,1,1,0.05); clip: true
                        Rectangle { anchors.fill: parent
                                    color: _btRowArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                        Text { anchors { left: parent.left; leftMargin: Theme.spaceL
                                         verticalCenter: parent.verticalCenter }
                               text: "Bluetooth"; color: System.textPrimary
                               font.pixelSize: Theme.fontBody; font.weight: Font.Medium }
                        StyledSwitch {
                            id: _btSwitch
                            anchors { right: parent.right; rightMargin: Theme.spaceL
                                      verticalCenter: parent.verticalCenter }
                            checked: Settings.bluetooth.powered
                            onToggled: Settings.bluetooth.setPowered(checked)
                        }
                        MouseArea { id: _btRowArea
                            anchors { left: parent.left; right: _btSwitch.left; top: parent.top; bottom: parent.bottom }
                            onClicked: Settings.bluetooth.setPowered(!Settings.bluetooth.powered) }
                    }

                    // Devices card (continues the group → bottom rounded)
                    Rectangle {
                        width: parent.width; height: _devCol.height
                        topLeftRadius: 0; topRightRadius: 0
                        bottomLeftRadius: Theme.radiusL; bottomRightRadius: Theme.radiusL
                        color: Qt.rgba(1,1,1,0.05); clip: true

                        Column {
                            id: _devCol
                            width: parent.width

                            // Empty state
                            Item {
                                width: parent.width; height: 132
                                visible: root._saved().length === 0
                                Column {
                                    anchors.centerIn: parent; spacing: Theme.spaceS
                                    SvgIcon { anchors.horizontalCenter: parent.horizontalCenter
                                              source: "qrc:/icons/bluetooth.svg"
                                              color: System.textMuted; size: Theme.iconXL }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter
                                           text: Settings.bluetooth.powered ? "Nenhum dispositivo salvo"
                                                                            : "Bluetooth desativado"
                                           color: System.textSecondary; font.pixelSize: Theme.fontBody }
                                }
                            }

                            Repeater {
                                model: root._saved()
                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: _devCol.width; height: 60
                                    Rectangle { anchors.fill: parent
                                                color: _dArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                                    SvgIcon { id: _dIcon
                                        anchors { left: parent.left; leftMargin: Theme.spaceL
                                                  verticalCenter: parent.verticalCenter }
                                        source: "qrc:/icons/bluetooth.svg"
                                        color: modelData.connected ? System.accent : System.textSecondary
                                        size: Theme.iconS }
                                    Column {
                                        anchors { left: _dIcon.right; leftMargin: Theme.spaceM
                                                  right: _dGear.left; rightMargin: Theme.spaceS
                                                  verticalCenter: parent.verticalCenter }
                                        spacing: 1
                                        Text { width: parent.width; text: modelData.alias
                                               color: modelData.connected ? System.accent : System.textPrimary
                                               font.pixelSize: Theme.fontBody
                                               font.weight: modelData.connected ? Font.Medium : Font.Normal
                                               elide: Text.ElideRight }
                                        Text { width: parent.width
                                               text: modelData.connected ? "Conectado" : "Salvo"
                                               color: System.textSecondary; font.pixelSize: 12 }
                                    }
                                    Rectangle { id: _dGear
                                        anchors { right: parent.right; rightMargin: Theme.spaceL
                                                  verticalCenter: parent.verticalCenter }
                                        width: Theme.btnMedium; height: Theme.btnMedium; radius: width/2
                                        color: _gArea.pressed ? System.surface2 : "transparent"
                                        SvgIcon { anchors.centerIn: parent; source: "qrc:/icons/cog.svg"
                                                  color: System.textSecondary; size: Theme.iconS }
                                        MouseArea { id: _gArea; anchors.fill: parent
                                                    onClicked: root._onDeviceOptions(modelData) } }
                                    MouseArea { id: _dArea
                                        anchors { left: parent.left; right: _dGear.left; top: parent.top; bottom: parent.bottom }
                                        onClicked: root._onDeviceTap(modelData) }
                                    Rectangle { visible: index < root._saved().length - 1
                                                anchors { left: _dIcon.left; right: parent.right
                                                          rightMargin: Theme.spaceL; bottom: parent.bottom }
                                                height: 1; color: Qt.rgba(1,1,1,0.06) }
                                }
                            }

                            // Pair new device row
                            Item {
                                width: parent.width; height: 56
                                Rectangle { anchors.fill: parent
                                            color: _pairArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                                Row { anchors { left: parent.left; leftMargin: Theme.spaceL
                                                verticalCenter: parent.verticalCenter }
                                      spacing: Theme.spaceM
                                    SvgIcon { anchors.verticalCenter: parent.verticalCenter
                                              source: "qrc:/icons/plus.svg"; color: System.accent; size: Theme.iconS }
                                    Text { anchors.verticalCenter: parent.verticalCenter
                                           text: "Parear novo dispositivo"; color: System.accent
                                           font.pixelSize: Theme.fontBody } }
                                MouseArea { id: _pairArea; anchors.fill: parent
                                            enabled: Settings.bluetooth.powered
                                            onClicked: { Settings.bluetooth.startScan(); root.view = "pair" } }
                            }
                        }
                    }
                }

                // Discoverable toggle card
                Rectangle {
                    width: parent.width; height: 64
                    radius: Theme.radiusL
                    color: Qt.rgba(1,1,1,0.05); clip: true
                    Rectangle { anchors.fill: parent
                                color: _discRow.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                    Column {
                        anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter
                                  right: _discSwitch.left; rightMargin: Theme.spaceM }
                        spacing: 1
                        Text { text: "Visível para outros"; color: System.textPrimary
                               font.pixelSize: Theme.fontBody; font.weight: Font.Medium }
                        Text { text: "Permite que dispositivos próximos encontrem este"
                               color: System.textSecondary; font.pixelSize: 12; elide: Text.ElideRight
                               width: parent.width }
                    }
                    StyledSwitch {
                        id: _discSwitch
                        anchors { right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                        checked: Settings.bluetooth.discoverable
                        onToggled: Settings.bluetooth.setDiscoverable(checked)
                    }
                    MouseArea { id: _discRow
                        anchors { left: parent.left; right: _discSwitch.left; top: parent.top; bottom: parent.bottom }
                        onClicked: Settings.bluetooth.setDiscoverable(!Settings.bluetooth.discoverable) }
                }
            }
        }
    }

    // ── Pair view (scan) ────────────────────────────────────────────────────
    Component {
        id: _pairView
        Flickable {
            anchors.fill: parent
            contentHeight: _pairCard.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Rectangle {
                id: _pairCard
                width: parent.width; height: _pairCol.height
                radius: Theme.radiusL
                color: Qt.rgba(1,1,1,0.05); clip: true

                Column {
                    id: _pairCol
                    width: parent.width

                    // header + scan bar
                    Item {
                        width: parent.width; height: 44
                        Text { anchors { left: parent.left; leftMargin: Theme.spaceL
                                         verticalCenter: parent.verticalCenter }
                               text: "Dispositivos disponíveis"; color: System.textSecondary
                               font.pixelSize: Theme.fontLabel; font.weight: Font.Medium }
                    }
                    Item {
                        id: _scanGap
                        width: parent.width; height: 3; clip: true
                        Rectangle { id: _seg
                            width: parent.width * 0.35; height: 2; radius: 1
                            anchors.verticalCenter: parent.verticalCenter; color: System.accent
                            visible: Settings.bluetooth.discovering
                            SequentialAnimation on x { running: Settings.bluetooth.discovering; loops: Animation.Infinite
                                NumberAnimation { from: -_seg.width; to: _scanGap.width; duration: 1000; easing.type: Easing.InOutQuad } }
                        }
                    }

                    Item {
                        width: parent.width; height: 100
                        visible: root._available().length === 0
                        Text { anchors.centerIn: parent
                               text: Settings.bluetooth.discovering ? "Procurando…" : "Nenhum dispositivo encontrado"
                               color: System.textSecondary; font.pixelSize: Theme.fontBody }
                    }

                    Repeater {
                        model: root._available()
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: _pairCol.width; height: 60
                            Rectangle { anchors.fill: parent
                                        color: _aArea.pressed ? Qt.rgba(1,1,1,0.05) : "transparent" }
                            SvgIcon { id: _aIcon
                                anchors { left: parent.left; leftMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                                source: "qrc:/icons/bluetooth.svg"; color: System.textSecondary; size: Theme.iconS }
                            Column {
                                anchors { left: _aIcon.right; leftMargin: Theme.spaceM
                                          right: parent.right; rightMargin: Theme.spaceL; verticalCenter: parent.verticalCenter }
                                spacing: 1
                                Text { width: parent.width; text: modelData.alias || modelData.address
                                       color: System.textPrimary; font.pixelSize: Theme.fontBody; elide: Text.ElideRight }
                                Text { width: parent.width; text: modelData.address
                                       color: System.textSecondary; font.pixelSize: 12; elide: Text.ElideRight }
                            }
                            MouseArea { id: _aArea; anchors.fill: parent
                                        onClicked: Settings.bluetooth.pair(modelData.address) }
                            Rectangle { visible: index < root._available().length - 1
                                        anchors { left: _aIcon.left; right: parent.right
                                                  rightMargin: Theme.spaceL; bottom: parent.bottom }
                                        height: 1; color: Qt.rgba(1,1,1,0.06) }
                        }
                    }
                }
            }
        }
    }
}
