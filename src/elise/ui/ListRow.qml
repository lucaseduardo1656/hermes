pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Canonical flat-list row — matches the settings NavRow visual (a plain leading
// MaterialIcon, a title + optional subtitle, and a trailing slot) over a
// StateLayer ripple, but without NavRow's ConnectedRect background so it works
// inside a plain ListView (search results, etc.). The settings rows are the
// reference; this keeps non-settings lists identical to them.
//
// Provide the leading icon via `icon` (Material symbol) or `iconSource` (svg).
// Anything placed as a child fills the trailing slot.
StateLayer {
    id: root

    property string icon
    property url    iconSource
    property string title
    property string subtitle

    default property alias trailing: _trailing.data

    radius: Tokens.rounding.small
    implicitWidth: ListView.view ? ListView.view.width : (parent ? parent.width : 0)
    implicitHeight: rowLayout.implicitHeight + Tokens.padding.medium * 2
    anchors.fill: undefined

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            visible: root.icon !== ""
            symbol: root.icon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
            Layout.alignment: Qt.AlignVCenter
        }
        SvgIcon {
            visible: root.iconSource != ""
            source: root.iconSource
            color: Colours.palette.m3onSurfaceVariant
            size: Theme.iconM
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
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

        Item {
            id: _trailing
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
