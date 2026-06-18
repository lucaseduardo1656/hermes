import QtQuick
import Elise

// Indeterminate spinner — the Material Symbols "progress_activity" glyph spun
// continuously. Stands in for Caelestia's components/LoadingIndicator.qml at the
// call sites that show a connecting/pairing state.
MaterialIcon {
    id: root

    property int implicitSize: 18

    symbol: "progress_activity"
    color: Colours.palette.m3primary
    fontStyle: Tokens.font.icon.size(Math.round(implicitSize * 0.75))

    RotationAnimator on rotation {
        from: 0; to: 360
        duration: 1000
        loops: Animation.Infinite
        running: root.visible
    }
}
