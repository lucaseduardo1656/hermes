import QtQuick

Rectangle {
    id: root
    color: "#2A2A2A"

    // Exposed for future map engine integration
    property real mapScale: 1.0
    property real mapX: 0.0
    property real mapY: 0.0

    Item {
        anchors.fill: parent
        opacity: 0.35

        Repeater {
            model: Math.ceil(root.height / 56) + 1
            Rectangle {
                y: index * 56
                width: root.width
                height: 1
                color: "#383838"
            }
        }

        Repeater {
            model: Math.ceil(root.width / 56) + 1
            Rectangle {
                x: index * 56
                height: root.height
                width: 1
                color: "#383838"
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "MAP"
        color: "#383838"
        font.pixelSize: 11
        font.letterSpacing: 6
        font.weight: Font.Light
    }

    // Pinch-to-zoom — atualiza mapScale para o futuro motor de mapa
    PinchHandler {
        id: pinch
        target: null
        onActiveScaleChanged: {
            root.mapScale = Math.max(0.5, Math.min(8.0, root.mapScale * pinch.activeScale))
        }
    }

    // Pan por drag com um dedo
    DragHandler {
        id: drag
        target: null
        onTranslationChanged: {
            root.mapX += drag.translation.x
            root.mapY += drag.translation.y
        }
    }
}
