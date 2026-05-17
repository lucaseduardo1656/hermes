pragma Singleton
import QtQuick

// Global keyboard controller. Any page can request input by calling:
//
//   Keyboard.show({
//       title:    "Senha de " + ssid,
//       password: true,
//       initial:  "",                       // optional pre-filled text
//       onSubmit: (text) => doSomething(text),
//       onCancel: () => {}                  // optional
//   })
//
// The actual UI (input bar + on-screen keyboard) lives at the top of
// Main.qml's z-stack so it covers settings sidebar, modals, anything else.
QtObject {
    id: root

    property bool   active:   false
    property string title:    ""
    property string buffer:   ""
    property bool   password: false
    // bare = no dim overlay and no floating modal card; only the
    // QWERTY tray docks at the bottom. The caller keeps showing its
    // own input surface, mirrored via the `buffer` property.
    property bool   bare:     false

    // Callbacks (functions). Stored as `var` so JS closures can be assigned.
    property var _onSubmit: null
    property var _onCancel: null

    function show(opts) {
        title     = opts.title    || ""
        password  = opts.password === true
        bare      = opts.bare === true
        buffer    = opts.initial  || ""
        _onSubmit = opts.onSubmit || null
        _onCancel = opts.onCancel || null
        active    = true
    }

    function append(c)   { buffer += c }
    function backspace() { buffer = buffer.slice(0, -1) }
    function clear()     { buffer = "" }

    function submit() {
        const t = buffer
        const cb = _onSubmit
        _close()
        if (cb) cb(t)
    }
    function dismiss() {
        const cb = _onCancel
        _close()
        if (cb) cb()
    }

    function _close() {
        active    = false
        buffer    = ""
        title     = ""
        password  = false
        bare      = false
        _onSubmit = null
        _onCancel = null
    }
}
