pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Page: Mapas offline — gerencia regiões pré-carregadas no cache do MapLibre.
// Cache vive em /var/cache/elise-maplibre. Cada "região salva" é metadata
// (nome + bbox); a tile data está no cache global. Nexus-styled.
VerticalFadeFlickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: _col.implicitHeight + topMargin + bottomMargin
    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.extraLarge

    function _humanBytes(n) {
        if (n < 1024) return n + " B"
        if (n < 1024 * 1024) return (n / 1024).toFixed(0) + " KB"
        if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB"
        return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
        spacing: Tokens.spacing.extraSmall / 2

        // ── Cache do mapa ───────────────────────────────────────────────────
        SectionHeader { first: true; text: "Cache do mapa" }
        NavRow {
            first: true
            chevron: false
            label: "Tamanho atual"
            status: root._humanBytes(Settings.offlineMaps.cacheBytes)
            onClicked: Settings.offlineMaps.refresh()
        }
        NavRow {
            label: "Atualizar"
            status: "Recontar arquivos do cache"
            onClicked: Settings.offlineMaps.refresh()
        }
        NavRow {
            last: true
            label: "Limpar cache"
            status: "Apaga todos os tiles baixados"
            onClicked: ActionSheet.show({
                title: "Limpar cache?",
                items: [{
                    label: "Apagar", destructive: true,
                    onSelected: function() { Settings.offlineMaps.clearCache() }
                }]
            })
        }

        // ── Regiões salvas ──────────────────────────────────────────────────
        SectionHeader { text: "Regiões salvas" }
        NavRow {
            first: true
            last: Settings.offlineMaps.regions.length === 0
            label: "Salvar área visível"
            status: "Pré-carrega a vista atual + 1 zoom abaixo e acima"
            onClicked: {
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
            delegate: NavRow {
                required property var modelData
                required property int index
                last: index === Settings.offlineMaps.regions.length - 1
                label: modelData.name
                status: "z " + modelData.minZoom + "–" + modelData.maxZoom
                        + "  ·  " + modelData.north.toFixed(2) + "/"
                        + modelData.west.toFixed(2)
                onClicked: ActionSheet.show({
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
