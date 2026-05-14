import QtQuick
import Elise

// Single key in SoftKeyboard. Pill rectangle with optional icon.
Rectangle {
    id: root

    property string text:       ""
    property string iconSource: ""
    property bool   accent:     false
    property color  bgColor:    System.surface2
    property color  downColor:  System.pressOverlay
    property color  textColor:  System.textPrimary
    property color  iconColor:  System.textPrimary
    signal tapped()

    width:  64
    height: 56
    radius: height / 2
    color:  _area.pressed ? root.downColor : root.bgColor

    Text {
        anchors.centerIn: parent
        text:  root.text
        color: root.textColor
        font.pixelSize: Theme.fontLabel
        font.weight: Font.Medium
        visible: root.iconSource === ""
    }
    SvgIcon {
        anchors.centerIn: parent
        source:  root.iconSource
        color:   root.iconColor
        size:    Theme.iconM
        visible: root.iconSource !== ""
    }

    MouseArea { id: _area
        anchors.fill: parent
        onClicked: root.tapped()
    }
}
