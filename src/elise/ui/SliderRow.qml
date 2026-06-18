pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Elise

// Port of Caelestia's modules/nexus/common/SliderRow.qml — a labelled slider on
// a ConnectedRect. Adapted: the leading icon is an SvgIcon (`iconSource`) since
// the Material Symbols glyph font doesn't render on this Qt build; the wheel
// step is a local constant (no GlobalConfig).
ConnectedRect {
    id: root

    property url iconSource
    property alias label: label.text
    property alias valueLabel: valueLabel.text
    property real value
    readonly property real _step: 0.05

    signal moved(value: real)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins + rowLayout.anchors.topMargin

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.largeIncreased
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.medium

        SvgIcon {
            visible: root.iconSource != ""
            source: root.iconSource
            color: Colours.palette.m3onSurfaceVariant
            size: Theme.iconS
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    id: label

                    Layout.fillWidth: true
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    id: valueLabel

                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }

            CustomMouseArea {
                function onWheel(event: WheelEvent): void {
                    if (event.angleDelta.y > 0)
                        root.moved(Math.min(1, root.value + root._step));
                    else if (event.angleDelta.y < 0)
                        root.moved(Math.max(0, root.value - root._step));
                }

                Layout.fillWidth: true
                implicitHeight: Tokens.padding.medium * 2

                StyledSlider {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: parent.implicitHeight

                    radius: Tokens.rounding.small
                    value: root.value
                    enabled: root.enabled
                    onInteraction: v => root.moved(v)
                }
            }
        }
    }
}
