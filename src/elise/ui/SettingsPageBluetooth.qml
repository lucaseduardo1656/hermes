pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Page: Connected devices — Caelestia nexus BluetoothPage. Bluetooth ToggleRow
// over an ItemList of saved devices, a "Pair new device" row that opens the
// scanning sub-view, and a Discoverable toggle. The SettingsMenu host renders
// the shared header; this page drives title/back via navTitle/canGoBack/goBack.
Item {
    id: root
    clip: true

    property string view: "main"      // "main" | "pair"
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
        VerticalFadeFlickable {
            clip: true
            contentWidth: width
            contentHeight: _mainCol.implicitHeight + topMargin + bottomMargin
            topMargin: Tokens.padding.large
            bottomMargin: Tokens.padding.extraLarge

            ColumnLayout {
                id: _mainCol
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
                spacing: Tokens.spacing.extraSmall / 2

                ToggleRow {
                    first: true
                    text: "Bluetooth"
                    labelFont: Tokens.font.body.medium
                    checked: Settings.bluetooth.powered
                    onToggled: Settings.bluetooth.setPowered(checked)
                }

                ItemList {
                    id: savedList
                    showList: Settings.bluetooth.powered
                    placeholderIcon: Settings.bluetooth.powered ? "devices_other" : "bluetooth_disabled"
                    placeholderText: Settings.bluetooth.powered ? "Nenhum dispositivo salvo" : "Bluetooth desativado"
                    model: Settings.bluetooth.powered ? root._saved() : []

                    delegate: StateLayer {
                        id: dev
                        required property var modelData
                        required property int index

                        readonly property bool connected: modelData.connected === true
                        readonly property bool loading: modelData.address === Settings.bluetooth.connectingAddr

                        anchors.left: savedList.list.contentItem.left
                        anchors.right: savedList.list.contentItem.right
                        anchors.fill: undefined
                        implicitHeight: devLayout.implicitHeight + devLayout.anchors.margins * 2
                        radius: Tokens.rounding.extraSmall
                        disabled: loading
                        onClicked: if (!loading) root._onDeviceTap(modelData)

                        RowLayout {
                            id: devLayout
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.largeIncreased
                            spacing: Tokens.spacing.medium

                            StyledRect {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: implicitHeight
                                implicitHeight: devIcon.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.full
                                color: dev.connected ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
                                MaterialIcon {
                                    id: devIcon
                                    anchors.centerIn: parent
                                    symbol: Icons.getBluetoothIcon(dev.modelData.icon ?? "")
                                    color: dev.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                                    fontStyle: Tokens.font.icon.medium
                                    fill: dev.connected ? 1 : 0
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.fillWidth: true
                                    text: dev.modelData.alias || dev.modelData.address
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: dev.loading ? "Conectando…" : dev.connected ? "Conectado" : "Salvo"
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    animate: true
                                }
                            }

                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: Theme.iconM
                                implicitHeight: Theme.iconM
                                LoadingIndicator {
                                    anchors.centerIn: parent
                                    visible: dev.loading
                                    implicitSize: Theme.iconM
                                }
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: !dev.loading
                                    symbol: "settings"
                                    color: dev.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.medium
                                }
                                StateLayer {
                                    disabled: dev.loading
                                    onClicked: root._onDeviceOptions(dev.modelData)
                                }
                            }
                        }
                    }
                }

                // Pair new device
                ConnectedRect {
                    Layout.fillWidth: true
                    last: true
                    implicitHeight: pairLayout.implicitHeight + pairLayout.anchors.margins * 2

                    StateLayer {
                        disabled: !Settings.bluetooth.powered
                        onClicked: { Settings.bluetooth.startScan(); root.view = "pair" }
                    }

                    RowLayout {
                        id: pairLayout
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.medium
                        opacity: Settings.bluetooth.powered ? 1 : 0.5
                        Behavior on opacity { CAnim {} }

                        MaterialIcon {
                            symbol: "add"
                            fontStyle: Tokens.font.icon.medium
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Parear novo dispositivo"
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }
                    }
                }

                // Discoverable
                ToggleRow {
                    Layout.topMargin: Tokens.spacing.large - parent.spacing
                    first: true; last: true
                    text: "Visível para outros"
                    subtext: "Permite que dispositivos próximos encontrem este"
                    enabled: Settings.bluetooth.powered
                    opacity: Settings.bluetooth.powered ? 1 : 0.5
                    checked: Settings.bluetooth.discoverable
                    onToggled: Settings.bluetooth.setDiscoverable(checked)
                    Behavior on opacity { CAnim {} }
                }
            }
        }
    }

    // ── Pair view (scan sub-page) ───────────────────────────────────────────
    Component {
        id: _pairView
        VerticalFadeFlickable {
            clip: true
            contentWidth: width
            contentHeight: _pairCol.implicitHeight + topMargin + bottomMargin
            topMargin: Tokens.padding.large
            bottomMargin: Tokens.padding.extraLarge

            ColumnLayout {
                id: _pairCol
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
                spacing: Tokens.spacing.extraSmall / 2

                // Header card
                ConnectedRect {
                    Layout.fillWidth: true
                    first: true
                    implicitHeight: pairHeader.implicitHeight + Tokens.padding.medium * 2
                    StyledText {
                        id: pairHeader
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.large
                        text: "Dispositivos disponíveis"
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }

                ItemList {
                    id: availList
                    last: true
                    showList: true
                    extraHeight: scanIndicator.implicitHeight
                    placeholderIcon: "bluetooth_searching"
                    placeholderText: Settings.bluetooth.discovering ? "Procurando dispositivos…" : "Nenhum dispositivo encontrado"
                    list.anchors.top: scanIndicator.bottom
                    model: root._available()

                    delegate: StateLayer {
                        id: nd
                        required property var modelData
                        required property int index

                        readonly property bool pairing: modelData.address === Settings.bluetooth.connectingAddr

                        anchors.left: availList.list.contentItem.left
                        anchors.right: availList.list.contentItem.right
                        anchors.fill: undefined
                        implicitHeight: ndLayout.implicitHeight + ndLayout.anchors.margins * 2
                        radius: Tokens.rounding.extraSmall
                        bottomLeftRadius: index === availList.list.count - 1 ? Tokens.rounding.extraLarge : radius
                        bottomRightRadius: index === availList.list.count - 1 ? Tokens.rounding.extraLarge : radius
                        disabled: pairing
                        onClicked: if (!pairing) Settings.bluetooth.pair(modelData.address)

                        RowLayout {
                            id: ndLayout
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.largeIncreased
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                symbol: Icons.getBluetoothIcon(nd.modelData.icon ?? "")
                                color: Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.medium
                                opacity: nd.pairing ? 0.5 : 1
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                opacity: nd.pairing ? 0.5 : 1
                                StyledText {
                                    Layout.fillWidth: true
                                    text: nd.modelData.alias || nd.modelData.address || "Dispositivo desconhecido"
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: nd.pairing ? "Pareando…" : (nd.modelData.address ?? "")
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    animate: true
                                }
                            }
                            LoadingIndicator {
                                Layout.alignment: Qt.AlignVCenter
                                visible: nd.pairing
                                implicitSize: Theme.iconM
                            }
                        }
                    }

                    StyledProgressBar {
                        id: scanIndicator
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 1
                        implicitHeight: Tokens.rounding.extraSmall
                        indeterminate: true
                    }
                }
            }
        }
    }
}
