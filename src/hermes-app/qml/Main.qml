import QtQuick
import QtQuick.Controls

Window {
    id: root
    width: 1024
    height: 600
    visible: true
    title: "Hermes"

    // Fundo escuro — base do tema automotivo
    Rectangle {
        anchors.fill: parent
        color: "#0d0d0d"

        Column {
            anchors.centerIn: parent
            spacing: 24

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "HERMES"
                font.pixelSize: 64
                font.letterSpacing: 12
                font.weight: Font.Light
                color: "#ffffff"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Car System"
                font.pixelSize: 20
                font.letterSpacing: 4
                color: "#888888"
            }
        }
    }
}
