import QtQuick

Rectangle {
    id: root
    color: "#2A2A2A"

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
}
