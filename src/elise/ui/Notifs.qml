pragma Singleton
import QtQuick

// Notification backend — mirrors the shape of Caelestia's Notifs service: a
// model of live popups, each with a summary/body/urgency, plus per-popup
// auto-dismiss timers that can be paused (e.g. on hover). UI binds to `model`
// and calls notify()/dismiss(). Later this is where a real source (BT MAP phone
// notifications over D-Bus) feeds in.
//
// urgency: 0 = low, 1 = normal, 2 = critical.
QtObject {
    id: root

    property ListModel model: ListModel {}

    property int defaultTimeoutMs: 6000
    property int criticalTimeoutMs: 12000
    // Small screen — keep at most this many on screen; older ones fall off.
    property int maxVisible: 4

    // Per-uid QtTimer instances so each popup dismisses (and can be paused)
    // independently, like Caelestia's per-notification timer.
    property var _timers: ({})
    property int _seq: 0

    function notify(summary, body, urgency) {
        const u = urgency === undefined ? 1 : urgency
        const uid = ++root._seq
        root.model.insert(0, {
            uid: uid,
            summary: summary || "",
            body: body || "",
            urgency: u
        })
        _arm(uid, u >= 2 ? root.criticalTimeoutMs : root.defaultTimeoutMs)
        // Cap the visible stack — dismiss the oldest beyond the limit so the
        // small screen never overflows (they leave with the normal animation).
        while (root.model.count > root.maxVisible)
            dismiss(root.model.get(root.model.count - 1).uid)
        return uid
    }

    function _arm(uid, ms) {
        const t = _timerComp.createObject(root, { uid: uid, interval: ms })
        const m = root._timers
        m[uid] = t
        root._timers = m
        t.start()
    }

    function pause(uid) { const t = root._timers[uid]; if (t) t.stop() }
    function resume(uid) {
        const t = root._timers[uid]
        if (t) t.start()
    }

    function dismiss(uid) {
        const t = root._timers[uid]
        if (t) { t.stop(); t.destroy(); delete root._timers[uid] }
        for (let i = 0; i < root.model.count; ++i)
            if (root.model.get(i).uid === uid) { root.model.remove(i); break }
    }

    function _indexOf(uid) {
        for (let i = 0; i < root.model.count; ++i)
            if (root.model.get(i).uid === uid) return i
        return -1
    }

    property Component _timerComp: Component {
        Timer {
            property int uid
            repeat: false
            onTriggered: root.dismiss(uid)
        }
    }
}
