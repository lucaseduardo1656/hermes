import QtQuick
import QtQuick.Layouts
import Elise

// Sidebar nav item — ported from Caelestia's modules/nexus/navpane/NavLocations
// item: a surface card whose corners morph (active = very round, group
// start/end = rounded, middle = square), a circular icon badge, title +
// description, StateLayer ripple. Uses SvgIcon for the badge (the Material
// Symbols glyph font doesn't render on this Qt build).
Item {
    id: root

    property url    icon
    property string label
    property string sublabel: ""
    property bool   active: false
    property bool   first: false
    property bool   last:  false
    signal clicked()

    width:  parent ? parent.width : 0
    height: 64

    StyledRect {
        id: bg
        anchors.fill: parent

        color: root.active ? Colours.palette.m3secondaryContainer
                           : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        topLeftRadius:     _area.pressed ? Tokens.rounding.medium : root.active ? Tokens.rounding.extraLargeIncreased : root.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        topRightRadius:    _area.pressed ? Tokens.rounding.medium : root.active ? Tokens.rounding.extraLargeIncreased : root.first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        bottomLeftRadius:  _area.pressed ? Tokens.rounding.medium : root.active ? Tokens.rounding.extraLargeIncreased : root.last  ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        bottomRightRadius: _area.pressed ? Tokens.rounding.medium : root.active ? Tokens.rounding.extraLargeIncreased : root.last  ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

        Behavior on topLeftRadius     { Anim { type: Anim.DefaultEffects } }
        Behavior on topRightRadius    { Anim { type: Anim.DefaultEffects } }
        Behavior on bottomLeftRadius  { Anim { type: Anim.DefaultEffects } }
        Behavior on bottomRightRadius { Anim { type: Anim.DefaultEffects } }

        StateLayer {
            id: _area
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            onClicked: root.clicked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.fillHeight: true
                implicitWidth: height
                radius: Tokens.rounding.full
                color: root.active ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                SvgIcon {
                    anchors.centerIn: parent
                    source: root.icon
                    color: root.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                    size: Theme.iconS
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.label
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.sublabel !== ""
                    text: root.sublabel
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
