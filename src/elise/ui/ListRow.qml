pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Canonical list row — a circular icon badge, a title + optional subtitle, and a
// trailing slot, over a StateLayer ripple. The single component for the app's
// flat lists (search results, and later Wi-Fi/Bluetooth/POI) so the touch
// feedback and layout stay identical instead of being re-built per screen.
//
// Provide the badge via `icon` (Material symbol) or `iconSource` (svg). Anything
// placed as a child fills the trailing slot.
StateLayer {
    id: root

    property string icon
    property url    iconSource
    property string title
    property string subtitle
    property color  badgeColor:   Colours.palette.m3secondaryContainer
    property color  badgeOnColor: Colours.palette.m3onSecondaryContainer

    default property alias trailing: _trailing.data

    radius: Tokens.rounding.small
    implicitWidth: ListView.view ? ListView.view.width : (parent ? parent.width : 0)
    implicitHeight: 60
    anchors.fill: undefined

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        // Circular icon badge.
        Rectangle {
            visible: root.icon !== "" || root.iconSource != ""
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 38; implicitHeight: 38
            radius: width / 2
            color: root.badgeColor
            MaterialIcon {
                anchors.centerIn: parent
                visible: root.icon !== ""
                symbol: root.icon
                color: root.badgeOnColor
                fontStyle: Tokens.font.icon.small
            }
            SvgIcon {
                anchors.centerIn: parent
                visible: root.iconSource != ""
                source: root.iconSource
                color: root.badgeOnColor
                size: Theme.iconS
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        // Trailing slot (distance label, chevron, switch, …).
        Item {
            id: _trailing
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
