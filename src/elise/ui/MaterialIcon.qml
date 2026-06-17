import QtQuick
import Elise

// Port of Caelestia's components/MaterialIcon.qml. Upstream builds the font via
// a fluent Tokens.font.icon.size().weight().vaxes().fill().grade() chain; we set
// the Material Symbols Rounded variable font directly with its FILL/GRAD/opsz/
// wght axes. Same public API (fill, grade, fontStyle).
Text {
    id: root

    property real fill: 0
    property int  grade: Colours.light ? 0 : -25
    property font fontStyle: Tokens.font.icon.small

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Colours.palette.m3onSurface

    font.family: "Material Symbols Rounded"
    font.pointSize: fontStyle.pointSize
    font.variableAxes: ({
        "FILL": root.fill.toFixed(1),
        "wght": 400,
        "GRAD": root.grade,
        "opsz": fontStyle.pointSize
    })

    Behavior on color { CAnim {} }
}
