import QtQuick
import QtQuick.Effects
import Elise

// Port of Caelestia's components/effects/Elevation.qml — an M3 elevation shadow
// whose blur/spread/offset scale with `level` (0-5 → dp).
RectangularShadow {
    property int level
    property real dp: [0, 1, 3, 6, 8, 12][level]

    color: Qt.alpha(Colours.palette.m3shadow, 0.7)
    blur: (dp * 5) ** 0.7
    spread: -dp * 0.3 + (dp * 0.1) ** 2
    offset.y: dp / 2

    Behavior on dp {
        Anim {
            type: Anim.SlowEffects
        }
    }
}
