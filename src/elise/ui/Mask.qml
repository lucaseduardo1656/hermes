import QtQuick.Effects

// Port of Caelestia's components/effects/Mask.qml — a MultiEffect configured as
// an alpha mask (used by VerticalFadeFlickable to fade the scroll edges).
MultiEffect {
    maskEnabled: true
    maskSpreadAtMin: 1
    maskThresholdMin: 0.5
}
