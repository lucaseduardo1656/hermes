import QtQuick
import Elise

// Port of Caelestia's components/StyledRect.qml — a Rectangle that animates
// colour changes through CAnim.
Rectangle {
    id: root

    color: "transparent"

    Behavior on color {
        CAnim {}
    }
}
