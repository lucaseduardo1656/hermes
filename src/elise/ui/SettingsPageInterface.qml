import QtQuick
import Elise

// Page: Interface — tema, cor de destaque, animações, mapa.
Flickable {
    id: root
    contentWidth:  width
    contentHeight: _col.implicitHeight + Theme.spaceXL * 2
    clip: true

    Column {
        id: _col
        anchors {
            top: parent.top; topMargin: Theme.spaceXL
            left: parent.left; leftMargin: Theme.spaceXL
            right: parent.right; rightMargin: Theme.spaceXL
        }
        spacing: Theme.spaceXL

        SettingsCard {
            title: "Aparência"

            SettingsToggle {
                label: "Tema escuro"
                checked: System.darkTheme
                onToggled: (v) => System.darkTheme = v
            }
            SettingsAction {
                label: "Cor de destaque"
                sublabel: {
                    const cur = System.accentKey
                    const opts = System.accentOptions
                    for (let i = 0; i < opts.length; ++i)
                        if (opts[i].key === cur) return opts[i].label
                    return cur
                }
                onTriggered: ActionSheet.show({
                    title: "Cor de destaque",
                    items: System.accentOptions.map(o => ({
                        label: o.label,
                        onSelected: function() { System.accentKey = o.key }
                    }))
                })
            }
            SettingsAction { label: "Tamanho da fonte";   sublabel: "Padrão" }
            SettingsAction { label: "Densidade do layout"; sublabel: "Confortável" }
        }

        SettingsCard {
            title: "Mapa"

            SettingsAction {
                label: "Estilo do mapa"
                sublabel: {
                    const cur = Settings.appearance.mapStyle
                    const opts = Settings.appearance.mapStyleOptions
                    for (let i = 0; i < opts.length; ++i)
                        if (opts[i].key === cur) return opts[i].label
                    return cur
                }
                onTriggered: ActionSheet.show({
                    title: "Estilo do mapa",
                    items: Settings.appearance.mapStyleOptions.map(o => ({
                        label: o.label,
                        onSelected: function() { Settings.appearance.setMapStyle(o.key) }
                    }))
                })
            }
        }

        SettingsCard {
            title: "Movimento"

            SettingsToggle {
                label: "Animações"
                checked: Settings.appearance.animationsEnabled
                onToggled: (v) => Settings.appearance.setAnimationsEnabled(v)
            }
        }
    }
}
