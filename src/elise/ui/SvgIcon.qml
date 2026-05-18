import QtQuick
import QtQuick.Effects

Item {
    id: root

    property url   source
    property color color:  System.textPrimary
    property real  size:   24

    implicitWidth:  size
    implicitHeight: size

    Image {
        id: _img
        anchors.fill: parent
        source:       root.source
        fillMode:     Image.PreserveAspectFit
        smooth:       true
        visible:      false
    }

    MultiEffect {
        source:           _img
        anchors.fill:     parent
        colorization:     1.0
        colorizationColor: root.color
    }
}
