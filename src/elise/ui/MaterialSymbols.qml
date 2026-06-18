pragma Singleton
import QtQuick

// Loads the Material Symbols Rounded variable font directly into Qt's
// application font registry via FontLoader, bypassing fontconfig (whose cache
// may be empty on the flashed image, so matching by family name alone fails and
// MaterialIcon renders the ligature name as plain text). `family` is the real
// resolved family name to bind MaterialIcon.font.family to.
QtObject {
    readonly property string family: _loader.status === FontLoader.Ready
                                       ? _loader.name : "Material Symbols Rounded"

    readonly property FontLoader _loader: FontLoader {
        source: "file:///usr/share/fonts/material/MaterialSymbolsRounded.ttf"
    }
}
