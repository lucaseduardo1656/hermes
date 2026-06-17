pragma Singleton
import QtQuick

// Shim for Caelestia's `Caelestia` C++ CUtils helper — only the members the
// ported QML components reference. Add more as needed.
QtObject {
    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(v, hi));
    }
}
