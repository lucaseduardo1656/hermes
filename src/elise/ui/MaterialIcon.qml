import QtQuick
import Elise

// Port of Caelestia's components/MaterialIcon.qml, adapted to render Material
// Symbols by CODEPOINT rather than ligature name (this Qt build doesn't apply
// the font's `liga` substitution, so the ligature names rendered as plain text).
//
// Callers set `symbol` to the icon name (e.g. "arrow_back"); if it's a known
// Material Symbol the mapped glyph is shown, otherwise the raw string is shown
// (so non-icon text like a number still renders normally).
Text {
    id: root

    property string symbol: ""
    property real fill: 0
    property int  grade: Colours.light ? 0 : -25
    property font fontStyle: Tokens.font.icon.small

    text: {
        const cp = MaterialSymbolsCodepoints.map[symbol];
        return cp !== undefined ? String.fromCharCode(cp) : symbol;
    }

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Colours.palette.m3onSurface

    font.family: MaterialSymbols.family
    font.pointSize: fontStyle.pointSize

    Behavior on color { CAnim {} }
}
