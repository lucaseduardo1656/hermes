import QtQuick
import Elise

// Page: Som — volume, EQ, saída de áudio, reprodução.
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
            title: "Volume"

            SettingsSlider {
                label: "Volume geral"
                value: Settings.audio.volume
                onMoved: (v) => Settings.audio.setVolume(v)
            }
            SettingsAction {
                label: "Equalizador"
                sublabel: {
                    const cur  = Settings.audio.eqPreset
                    const opts = Settings.audio.eqOptions
                    for (let i = 0; i < opts.length; ++i)
                        if (opts[i].key === cur) return opts[i].label
                    return cur
                }
                onTriggered: ActionSheet.show({
                    title: "Equalizador",
                    items: Settings.audio.eqOptions.map(o => ({
                        label: o.label,
                        onSelected: function() { Settings.audio.setEqPreset(o.key) }
                    }))
                })
            }
        }

        SettingsCard {
            title: "Saída de áudio"

            SettingsAction { label: "Dispositivo"; sublabel: "Alto-falantes do veículo" }
            SettingsToggle {
                label: "Áudio espacial"
                checked: Settings.audio.spatialAudio
                onToggled: (v) => Settings.audio.setSpatialAudio(v)
            }
        }

        SettingsCard {
            title: "Reprodução"

            SettingsToggle {
                label: "Retomar ao iniciar"
                checked: Settings.audio.resumeOnStart
                onToggled: (v) => Settings.audio.setResumeOnStart(v)
            }
        }
    }
}
