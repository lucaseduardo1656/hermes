pragma Singleton
import QtQuick

// Global action-sheet controller. Any page can show a contextual menu by
// calling:
//
//   ActionSheet.show({
//       title: "Trapaceiro",
//       items: [
//           { label: "Conectar",         onSelected: () => ... },
//           { label: "Esquecer rede",    onSelected: () => ..., destructive: true },
//           { label: "Detalhes",         onSelected: () => ... },
//       ]
//   })
//
// Renderer lives in Main.qml at top z (above settings + keyboard sheet).
QtObject {
    id: root

    property bool   active: false
    property string title:  ""
    property var    items:  []     // [{ label, onSelected, destructive? }]

    function show(opts) {
        title  = opts.title || ""
        items  = opts.items || []
        active = true
    }
    function dismiss() { active = false; items = []; title = "" }

    function pick(index) {
        if (index < 0 || index >= items.length) { dismiss(); return }
        const it = items[index]
        dismiss()
        if (it && it.onSelected) it.onSelected()
    }
}
