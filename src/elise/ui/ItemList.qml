pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Port of Caelestia's modules/nexus/common/ItemList.qml — a ConnectedRect that
// hosts a ListView, cross-fading to a centered placeholder (icon + text) when
// the list is empty or hidden. Used for the Wi-Fi/Bluetooth device lists.
ConnectedRect {
    id: root

    property bool showList
    property string placeholderIcon
    property string placeholderText
    property int extraHeight

    property alias model: list.model
    property alias delegate: list.delegate
    readonly property alias list: list

    Layout.fillWidth: true
    implicitHeight: (showList && list.count > 0 ? list.contentHeight : placeholder.implicitHeight + Tokens.padding.extraLarge * 2) + extraHeight
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    Behavior on implicitHeight {
        Anim {}
    }

    Loader {
        id: placeholder

        anchors.centerIn: parent
        active: opacity > 0
        opacity: root.showList && list.count > 0 ? 0 : 1

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                symbol: root.placeholderIcon
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.placeholderText
                color: Colours.palette.m3outline
                font: Tokens.font.body.large
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        spacing: 0
        interactive: false
        opacity: root.showList ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
