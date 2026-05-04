import QtQuick

Item {
    id: root

    property bool active: false
    signal dismissed()

    visible: active

    Rectangle {
        anchors.fill: parent
        color:        "transparent"
    }

    MouseArea {
        anchors.fill:        parent
        enabled:             root.active
        propagateComposedEvents: false
        onClicked:           root.dismissed()
    }
}
