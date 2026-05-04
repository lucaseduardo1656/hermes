import QtQuick

Item {
    id: root
    property bool interactive: true

    // Base gradient — replace with real map integration
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#0F1318" }
            GradientStop { position: 1.0; color: "#0A0A0A" }
        }
    }

    // Subtle grid to suggest map tiles
    Item {
        anchors.fill: parent
        opacity: 0.04
        Repeater {
            model: 20
            Rectangle {
                x: index * 60; y: 0
                width: 1; height: parent.height
                color: "white"
            }
        }
        Repeater {
            model: 20
            Rectangle {
                x: 0; y: index * 60
                width: parent.width; height: 1
                color: "white"
            }
        }
    }

    // Map placeholder label
    Text {
        anchors.centerIn: parent
        text:  "MAP"
        color: "#FFFFFF"
        font.pixelSize: 11
        font.letterSpacing: 6
        opacity: 0.06
    }

    // Passthrough blocker when UI is over map
    MouseArea {
        anchors.fill: parent
        enabled:      !root.interactive
        propagateComposedEvents: false
    }
}
