pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Page: Interface — tema, cor de destaque, animações, mapa. Wired to System
// (theme/accent) and Settings.appearance (map style/animations). Pickers reuse
// the global ActionSheet; nexus-styled rows.
VerticalFadeFlickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: _col.implicitHeight + topMargin + bottomMargin
    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.extraLarge

    function _accentLabel() {
        const cur = System.accentKey
        const opts = System.accentOptions
        for (let i = 0; i < opts.length; ++i)
            if (opts[i].key === cur) return opts[i].label
        return cur
    }
    function _mapStyleLabel() {
        const cur = Settings.appearance.mapStyle
        const opts = Settings.appearance.mapStyleOptions
        for (let i = 0; i < opts.length; ++i)
            if (opts[i].key === cur) return opts[i].label
        return cur
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
        spacing: Tokens.spacing.extraSmall / 2

        // ── Aparência ───────────────────────────────────────────────────────
        SectionHeader { first: true; text: "Aparência" }
        ToggleRow {
            first: true
            text: "Tema escuro"
            checked: System.darkTheme
            onToggled: System.darkTheme = checked
        }
        NavRow {
            label: "Cor de destaque"
            status: root._accentLabel()
            onClicked: ActionSheet.show({
                title: "Cor de destaque",
                items: System.accentOptions.map(o => ({
                    label: o.label,
                    onSelected: function() { System.accentKey = o.key }
                }))
            })
        }
        NavRow {
            label: "Tamanho da fonte"
            status: "Padrão"
        }
        NavRow {
            last: true
            label: "Densidade do layout"
            status: "Confortável"
        }

        // ── Mapa ────────────────────────────────────────────────────────────
        SectionHeader { text: "Mapa" }
        NavRow {
            first: true; last: true
            label: "Estilo do mapa"
            status: root._mapStyleLabel()
            onClicked: ActionSheet.show({
                title: "Estilo do mapa",
                items: Settings.appearance.mapStyleOptions.map(o => ({
                    label: o.label,
                    onSelected: function() { Settings.appearance.setMapStyle(o.key) }
                }))
            })
        }

        // ── Movimento ───────────────────────────────────────────────────────
        SectionHeader { text: "Movimento" }
        ToggleRow {
            first: true; last: true
            text: "Animações"
            checked: Settings.appearance.animationsEnabled
            onToggled: Settings.appearance.setAnimationsEnabled(checked)
        }
    }
}
