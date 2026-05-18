pragma Singleton
import QtQuick

// Global registry for the current CarMap instance. CarMap registers
// itself on Component.onCompleted; pages outside Main (e.g. the
// offline-maps settings page) read `MapBridge.current` to call
// methods on the live map without having to thread a property
// through every Loader between them.
QtObject {
    property var current: null
}
