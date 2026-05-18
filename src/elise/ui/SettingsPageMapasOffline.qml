import QtQuick
import Elise

// Page: Mapas offline — gerencia regiões pré-carregadas no cache do
// MapLibre. Cache vive em /var/cache/elise-maplibre; o que entra ali
// fica disponível offline na próxima vez. Cada "região salva" é só
// metadata (nome + bbox) — a tile data está no cache global.
Flickable {
    id: root
    contentWidth:  width
    contentHeight: _col.implicitHeight + Theme.spaceXL * 2
    clip: true

    function _humanBytes(n) {
        if (n < 1024) return n + " B"
        if (n < 1024 * 1024) return (n / 1024).toFixed(0) + " KB"
        if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB"
        return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    Column {
        id: _col
        anchors {
            top: parent.top; topMargin: Theme.spaceXL
            left: parent.left; leftMargin: Theme.spaceXL
            right: parent.right; rightMargin: Theme.spaceXL
        }
        spacing: Theme.spaceXL

        SettingsCard {
            title: "Cache do mapa"

            SettingsAction {
                label: "Tamanho atual"
                sublabel: root._humanBytes(Settings.offlineMaps.cacheBytes)
                onTriggered: Settings.offlineMaps.refresh()
            }
            SettingsAction {
                label: "Atualizar"
                sublabel: "Recontar arquivos do cache"
                onTriggered: Settings.offlineMaps.refresh()
            }
            SettingsAction {
                label: "Limpar cache"
                sublabel: "Apaga todos os tiles baixados"
                onTriggered: ActionSheet.show({
                    title: "Limpar cache?",
                    items: [{
                        label: "Apagar",
                        destructive: true,
                        onSelected: function() {
                            Settings.offlineMaps.clearCache()
                        }
                    }]
                })
            }
        }

        SettingsCard {
            title: "Regiões salvas"

            SettingsAction {
                label: "Salvar área visível"
                sublabel: "Pré-carrega a vista atual + 1 zoom abaixo e acima"
                onTriggered: {
                    if (!MapBridge.current) return
                    Keyboard.show({
                        title: "Nome da região",
                        initial: "",
                        onSubmit: function(name) {
                            if (name.trim() === "") return
                            const b = MapBridge.current.visibleBounds()
                            const z = Math.round(b.zoom)
                            Settings.offlineMaps.saveRegion(
                                name, b.north, b.south, b.east, b.west,
                                Math.max(1, z - 1), Math.min(19, z + 1))
                            MapBridge.current.preloadRegion(
                                b.north, b.south, b.east, b.west,
                                Math.max(1, z - 1), Math.min(19, z + 1))
                        }
                    })
                }
            }

            Repeater {
                model: Settings.offlineMaps.regions
                SettingsAction {
                    label: modelData.name
                    sublabel: "z " + modelData.minZoom + "–" + modelData.maxZoom
                              + "  ·  " + modelData.north.toFixed(2) + "/"
                              + modelData.west.toFixed(2)
                    onTriggered: ActionSheet.show({
                        title: modelData.name,
                        items: [
                            { label: "Recarregar (re-baixar)", onSelected: function() {
                                if (MapBridge.current)
                                    MapBridge.current.preloadRegion(
                                        modelData.north, modelData.south,
                                        modelData.east,  modelData.west,
                                        modelData.minZoom, modelData.maxZoom)
                            }},
                            { label: "Esquecer", destructive: true,
                              onSelected: function() {
                                Settings.offlineMaps.deleteRegion(modelData.name)
                            }}
                        ]
                    })
                }
            }
        }
    }
}
