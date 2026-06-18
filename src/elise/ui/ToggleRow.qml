pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Full-width switch row on a ConnectedRect: a label (+ optional subtext) on the
// left and an M3 StyledSwitch on the right. Tapping anywhere on the row flips
// the switch. (Caelestia's upstream ToggleRow drives the label through
// Switch.contentItem with anchors, which this Qt build lays out at zero width,
// so the row is built explicitly here instead.)
ConnectedRect {
    id: root

    property string text
    property string subtext
    property bool checked
    signal toggled(bool checked)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight
                    + Tokens.padding.medium * 2

    StateLayer {
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.text
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.subtext !== ""
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
            }
        }

        StyledSwitch {
            Layout.alignment: Qt.AlignVCenter
            cLayer: 2
            checked: root.checked
        }
    }
}
