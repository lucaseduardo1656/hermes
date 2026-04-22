import QtQuick
import QtQuick.Controls

Item {
    id: root
    height: 44

    signal settingsRequested()

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#CC414141" }
            GradientStop { position: 1.0; color: "#00414141" }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Rectangle {
            width: 8; height: 8
            radius: 4
            color: "#2ECC71"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "WiFi"
            color: "#757575"
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        id: timeLabel
        anchors.centerIn: parent
        text: Qt.formatTime(new Date(), "HH:mm")
        color: "#F0F0F0"
        font.pixelSize: 18
        font.weight: Font.Medium
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: timeLabel.text = Qt.formatTime(new Date(), "HH:mm")
    }

    Item {
        id: settingsBtn
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 44; height: 44

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: settingsTap.pressed ? "#4D4D4D" : "transparent"

            Image {
                anchors.centerIn: parent
                source: "qrc:/icons/settings.svg"
                width: 20; height: 20
                opacity: 0.45
            }
        }

        TapHandler {
            id: settingsTap
            onTapped: root.settingsRequested()
        }
    }
}
