import QtQuick
import Elise

// Port of Caelestia's components/containers/StyledFlickable.qml — a Flickable
// with a faster max flick velocity and a rebound transition that does a tiny
// fake flick so the scroll geometry settles on first load.
Flickable {
    id: root

    property bool doneFakeFlick

    maximumFlickVelocity: 3000

    rebound: Transition {
        onRunningChanged: {
            if (!running && !root.doneFakeFlick) {
                root.doneFakeFlick = true;
                root.flick(1, 1);
                root.flick(-1, -1);
                Qt.callLater(() => root.cancelFlick());
            }
        }

        Anim {
            properties: "x,y"
        }
    }

    Timer {
        running: root.doneFakeFlick
        interval: 10
        onTriggered: root.doneFakeFlick = false
    }
}
