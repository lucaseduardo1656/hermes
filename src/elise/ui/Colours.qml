pragma Singleton
import QtQuick
import Elise

// Port of Caelestia's `qs.services` Colours: the full Material 3 role vocabulary
// (palette.m3*) + `light` + `layer()`. Backed by our System singleton so the
// hues follow the Elise theme (sand accent, light/dark) while exposing the same
// token names the ported components reference.
QtObject {
    id: root

    readonly property bool light: !System.darkTheme

    // Transparency config (upstream lives in Colours). Flat opaque theme.
    readonly property QtObject transparency: QtObject {
        readonly property bool enabled: false
        readonly property real base:    1.0
        readonly property real layers:  1.0
    }

    // Translucent palette — upstream applies window transparency. With
    // transparency disabled it equals the opaque palette.
    readonly property QtObject tPalette: palette

    // Elevation tint helper (upstream blends the container toward the surface
    // per level). We keep the container colour — sufficient for our flat theme.
    function layer(c, n) { return c }

    readonly property QtObject palette: QtObject {
        // Primary
        readonly property color m3primary:              System.accent
        readonly property color m3onPrimary:            System.surface
        readonly property color m3primaryContainer:     Qt.rgba(System.accent.r, System.accent.g, System.accent.b, 0.28)
        readonly property color m3onPrimaryContainer:   System.textPrimary
        readonly property color m3inversePrimary:       System.accentDim
        // Secondary
        readonly property color m3secondary:            System.accent
        readonly property color m3onSecondary:          System.surface
        readonly property color m3secondaryContainer:   Qt.rgba(System.accent.r, System.accent.g, System.accent.b, 0.22)
        readonly property color m3onSecondaryContainer: System.textPrimary
        // Tertiary
        readonly property color m3tertiary:             System.accent
        readonly property color m3onTertiary:           System.surface
        readonly property color m3tertiaryContainer:    Qt.rgba(System.accent.r, System.accent.g, System.accent.b, 0.22)
        readonly property color m3onTertiaryContainer:  System.textPrimary
        // Surfaces
        readonly property color m3background:           System.background
        readonly property color m3onBackground:         System.textPrimary
        readonly property color m3surface:              System.surface
        readonly property color m3surfaceDim:           System.background
        readonly property color m3surfaceBright:        System.surface2
        readonly property color m3surfaceContainerLowest: System.background
        readonly property color m3surfaceContainerLow:  System.surface
        readonly property color m3surfaceContainer:     System.surface2
        readonly property color m3surfaceContainerHigh: System.surface2
        readonly property color m3surfaceContainerHighest: System.surface2
        readonly property color m3surfaceVariant:       System.surface2
        readonly property color m3onSurface:            System.textPrimary
        readonly property color m3onSurfaceVariant:     System.textSecondary
        readonly property color m3inverseSurface:       System.textPrimary
        readonly property color m3inverseOnSurface:     System.surface
        // Outline / utility
        readonly property color m3outline:              System.border
        readonly property color m3outlineVariant:       System.border
        readonly property color m3error:                System.danger
        readonly property color m3onError:              System.surface
        readonly property color m3success:              System.success
        readonly property color m3shadow:               "#000000"
        readonly property color m3scrim:                "#000000"
    }
}
