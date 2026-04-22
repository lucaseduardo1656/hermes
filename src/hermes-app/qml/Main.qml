import QtQuick
import QtQuick.Controls
import QtQuick.VirtualKeyboard

Window {
    id: root
    width: 1024
    height: 600
    visible: true
    title: "Hermes"

    property bool settingsOpen: false

    MapView {
        anchors.fill: parent
    }

    TopBar {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        onSettingsRequested: root.settingsOpen = true
    }

    SettingsPanel {
        anchors.fill: parent
        open: root.settingsOpen
        onCloseRequested: root.settingsOpen = false
    }

    InputPanel {
        id: inputPanel
        z: 50
        x: 0
        width: parent.width
        y: active ? parent.height - height : parent.height
        Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }
}
