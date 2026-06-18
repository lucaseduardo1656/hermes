pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Port of Caelestia's modules/nexus/common/NavRow.qml — a tappable row on a
// ConnectedRect: optional leading MaterialIcon, a label + optional status
// subline, and a trailing chevron. Used for navigation and for opening pickers
// (ActionSheet) in place of the old SettingsAction.
ConnectedRect {
    id: root

    property string icon                 // MaterialIcon symbol; empty = no icon
    property alias label: label.text
    property alias status: status.text
    property bool chevron: true

    signal clicked

    Layout.fillWidth: true
    implicitHeight: navLayout.implicitHeight + navLayout.anchors.margins * 2

    StateLayer {
        onClicked: root.clicked()
    }

    RowLayout {
        id: navLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                id: status

                Layout.fillWidth: true
                visible: text
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        MaterialIcon {
            visible: root.chevron
            symbol: "chevron_right"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
