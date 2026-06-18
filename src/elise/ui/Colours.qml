pragma Singleton
import QtQuick
import Elise

// Material 3 role palette for the ported Caelestia components. Upstream
// generates this from the wallpaper (Material You); we derive a proper TONAL
// layering from our System theme so the surface-container levels and the
// primary/secondary containers are visually distinct (a flat mapping made the
// UI look wrong vs Caelestia). Works for both light and dark System themes.
QtObject {
    id: root

    readonly property bool light: !System.darkTheme

    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1);
    }
    // Higher container levels move toward the ink (lighter in dark, darker in
    // light) — the M3 surface-container elevation ladder.
    function _tone(t) { return _mix(System.surface, System.textPrimary, t); }

    // Elevation tint: raise a colour toward the ink by `n` steps.
    function layer(c, n) { return _mix(c, System.textPrimary, n * 0.018); }

    readonly property QtObject transparency: QtObject {
        readonly property bool enabled: false
        readonly property real base:    1.0
        readonly property real layers:  1.0
    }
    readonly property QtObject tPalette: palette

    readonly property QtObject palette: QtObject {
        // Primary (accent)
        readonly property color m3primary:              System.accent
        readonly property color m3onPrimary:            root._mix(System.accent, "#000000", 0.72)
        readonly property color m3primaryContainer:     root._mix(System.surface, System.accent, 0.40)
        readonly property color m3onPrimaryContainer:   root._mix(System.accent, System.textPrimary, 0.15)
        readonly property color m3inversePrimary:       System.accentDim
        // Secondary (muted accent tonal — used for active nav item / containers)
        readonly property color m3secondary:            root._mix(System.accent, System.textPrimary, 0.10)
        readonly property color m3onSecondary:          root._mix(System.accent, "#000000", 0.72)
        readonly property color m3secondaryContainer:   root._mix(System.surface2, System.accent, 0.30)
        readonly property color m3onSecondaryContainer: root.light ? root._mix(System.accent, "#000000", 0.55)
                                                                    : root._mix(System.accent, "#ffffff", 0.25)
        // Tertiary (reuse accent)
        readonly property color m3tertiary:             System.accent
        readonly property color m3onTertiary:           root._mix(System.accent, "#000000", 0.72)
        readonly property color m3tertiaryContainer:    root._mix(System.surface2, System.accent, 0.30)
        readonly property color m3onTertiaryContainer:  root._mix(System.accent, System.textPrimary, 0.20)
        // Surfaces — distinct elevation ladder
        readonly property color m3background:           System.background
        readonly property color m3onBackground:         System.textPrimary
        readonly property color m3surface:              System.surface
        readonly property color m3surfaceDim:           System.background
        readonly property color m3surfaceBright:        root._tone(0.12)
        readonly property color m3surfaceContainerLowest: System.background
        readonly property color m3surfaceContainerLow:  root._tone(0.02)
        readonly property color m3surfaceContainer:     root._tone(0.04)
        readonly property color m3surfaceContainerHigh: root._tone(0.07)
        readonly property color m3surfaceContainerHighest: root._tone(0.10)
        readonly property color m3surfaceVariant:       root._tone(0.06)
        readonly property color m3onSurface:            System.textPrimary
        readonly property color m3onSurfaceVariant:     System.textSecondary
        readonly property color m3inverseSurface:       System.textPrimary
        readonly property color m3inverseOnSurface:     System.surface
        // Outline / utility
        readonly property color m3outline:              System.textMuted
        readonly property color m3outlineVariant:       System.border
        readonly property color m3error:                System.danger
        readonly property color m3onError:              "#ffffff"
        readonly property color m3success:              System.success
        readonly property color m3shadow:               "#000000"
        readonly property color m3scrim:                "#000000"
    }
}
