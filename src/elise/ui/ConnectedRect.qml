import QtQuick
import Elise

// Port of Caelestia's modules/nexus/common/ConnectedRect.qml — a surface card
// that rounds its outer corners only when it's the first/last of a connected
// group, giving the M3 "grouped list" look.
StyledRect {
    property bool first
    property bool last

    color: Colours.tPalette.m3surfaceContainer
    topLeftRadius: first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    topRightRadius: first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomLeftRadius: last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomRightRadius: last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
}
