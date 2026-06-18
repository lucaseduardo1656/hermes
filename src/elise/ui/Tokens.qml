pragma Singleton
import QtQuick

// Port of Caelestia's `Caelestia.Config` Tokens (a compiled module upstream),
// reimplemented as a QML singleton with the same member structure the ported
// components reference: rounding / padding / spacing / anim (durations +
// easings) / font / transparency. Material 3 Expressive values.
QtObject {
    id: root

    // Real Caelestia token values (plugin/src/Caelestia/Config/tokens.hpp).
    readonly property QtObject rounding: QtObject {
        readonly property real scale:               1.0
        readonly property int none:                 0
        readonly property int extraSmall:           4
        readonly property int small:                8
        readonly property int medium:               12
        readonly property int large:                16
        readonly property int largeIncreased:       20
        readonly property int extraLarge:           28
        readonly property int extraLargeIncreased:  32
        readonly property int extraExtraLarge:      48
        readonly property int full:                 9999
    }

    readonly property QtObject padding: QtObject {
        readonly property int extraSmall:           4
        readonly property int small:                8
        readonly property int medium:               12
        readonly property int large:                16
        readonly property int largeIncreased:       20
        readonly property int extraLarge:           28
        readonly property int extraLargeIncreased:  32
        readonly property int extraExtraLarge:      48
    }

    readonly property QtObject spacing: QtObject {
        readonly property int extraSmall:           4
        readonly property int small:                8
        readonly property int medium:               12
        readonly property int large:                16
        readonly property int largeIncreased:       20
        readonly property int extraLarge:           28
        readonly property int extraLargeIncreased:  32
        readonly property int extraExtraLarge:      48
    }

    readonly property QtObject transparency: QtObject {
        readonly property bool enabled: false
        readonly property real base:    1.0
        readonly property real layers:  1.0
    }

    readonly property QtObject anim: QtObject {
        readonly property QtObject durations: QtObject {
            readonly property int small:      200
            readonly property int normal:     300
            readonly property int large:      400
            readonly property int extraLarge: 500
            readonly property int expressiveFastSpatial:    350
            readonly property int expressiveDefaultSpatial: 500
            readonly property int expressiveSlowSpatial:    650
            readonly property int expressiveFastEffects:    150
            readonly property int expressiveDefaultEffects: 200
            readonly property int expressiveSlowEffects:    300
        }
        // Material 3 easing curves (cubic bezier control points, ending at 1,1).
        readonly property var standard:      ({ type: Easing.BezierSpline, bezierCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0] })
        readonly property var standardAccel: ({ type: Easing.BezierSpline, bezierCurve: [0.3, 0.0, 1.0, 1.0, 1.0, 1.0] })
        readonly property var standardDecel: ({ type: Easing.BezierSpline, bezierCurve: [0.0, 0.0, 0.0, 1.0, 1.0, 1.0] })
        readonly property var emphasized:    ({ type: Easing.BezierSpline, bezierCurve: [0.3, 0.0, 0.0, 1.0, 1.0, 1.0] })
        readonly property var expressiveFastSpatial:    standard
        readonly property var expressiveDefaultSpatial: emphasized
        readonly property var expressiveSlowSpatial:    emphasized
        readonly property var expressiveFastEffects:    standard
        readonly property var expressiveDefaultEffects: standard
        readonly property var expressiveSlowEffects:    standard
    }

    readonly property QtObject font: QtObject {
        // UI text family (Caelestia uses JetBrains Mono).
        readonly property string family: "JetBrains Mono"
        readonly property QtObject body: QtObject {
            readonly property font small:  Qt.font({ family: "JetBrains Mono", pointSize: 11 })
            readonly property font medium: Qt.font({ family: "JetBrains Mono", pointSize: 13 })
            readonly property font large:  Qt.font({ family: "JetBrains Mono", pointSize: 15 })
        }
        readonly property QtObject label: QtObject {
            readonly property font small:  Qt.font({ family: "JetBrains Mono", pointSize: 9 })
            readonly property font medium: Qt.font({ family: "JetBrains Mono", pointSize: 10 })
            readonly property font large:  Qt.font({ family: "JetBrains Mono", pointSize: 11 })
        }
        readonly property QtObject icon: QtObject {
            readonly property font small:  Qt.font({ family: "Material Symbols Rounded", pointSize: 16 })
            readonly property font medium: Qt.font({ family: "Material Symbols Rounded", pointSize: 20 })
            readonly property font large:  Qt.font({ family: "Material Symbols Rounded", pointSize: 28 })
            function size(pt) { return Qt.font({ family: "Material Symbols Rounded", pointSize: pt }); }
        }
        // Fluent font builders (upstream Tokens.font.title.builders.*). Each
        // builder exposes weight(w).build() → a `font` value.
        readonly property QtObject title: QtObject {
            readonly property font large:  Qt.font({ family: "JetBrains Mono", pointSize: 18, weight: Font.Medium })
            readonly property font medium: Qt.font({ family: "JetBrains Mono", pointSize: 15, weight: Font.Medium })
            readonly property var builders: ({
                medium: {
                    weight: function (w) {
                        return { build: function () { return Qt.font({ family: "JetBrains Mono", pointSize: 16, weight: w }); } };
                    }
                }
            })
        }
    }
}
