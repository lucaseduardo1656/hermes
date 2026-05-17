import QtQuick
import QtLocation
import QtPositioning
import Elise

// Thin wrapper around Qt Location's MapView. Sets up the OSM raster
// plugin, drives the camera from Qt Positioning, and overlays a GPS
// pose marker.
//
// Default position: Lagoa da Prata, MG. Replaced as soon as
// PositionSource lands a real fix from NMEA / serial.
Item {
    id: root

    property bool interactive: true
    readonly property var currentCoord: _pos.position.coordinate

    function recenter() {
        if (_pos.position.coordinate.isValid)
            _mapView.map.center = _pos.position.coordinate
    }

    PositionSource {
        id: _pos
        updateInterval: 1000
        active: true
        // Qt picks among the installed position plugins (nmea +
        // positionpoll on this image). With a GPS HAT feeding NMEA on
        // /dev/serial0, qtposition_nmea exposes a fix automatically.
        // Without hardware the position stays invalid and the marker
        // is hidden — no mock pose needed since the map itself shows.
    }

    Plugin {
        id: _osm
        name: "osm"
        PluginParameter { name: "osm.useragent"; value: "Elise/0.1 hermes-infotainment" }
        // Suppress the optional provider repository fetch; the OSM
        // plugin tries to GET https://maps-redirect.qt.io on startup
        // and waiting for that times out when the cache is cold.
        PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: "true" }
        PluginParameter { name: "osm.mapping.host"; value: "https://tile.openstreetmap.org/" }
        PluginParameter { name: "osm.mapping.copyright"; value: "© OpenStreetMap" }
        PluginParameter { name: "osm.mapping.highdpi_tiles"; value: "true" }
    }

    MapView {
        id: _mapView
        anchors.fill: parent
        // Qt's MapView ships its own pan/pinch/double-tap gestures,
        // wheel zoom included. Disable when an overlay (player,
        // settings) is on top.
        map.plugin: _osm
        map.center: QtPositioning.coordinate(-20.0294, -45.5390)
        map.zoomLevel: 14
        map.activeMapType: map.supportedMapTypes.length > 0
                             ? map.supportedMapTypes[0] : null
        enabled: root.interactive

        // GPS pose marker — circle + heading wedge.
        MapQuickItem {
            id: _gpsMarker
            visible: _pos.position.coordinate.isValid
            coordinate: _pos.position.coordinate
            anchorPoint.x: 14
            anchorPoint.y: 14
            sourceItem: Item {
                width: 28; height: 28
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: System.accent
                    border.color: "#000000"
                    border.width: 3
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top; anchors.bottomMargin: -4
                    width: 6; height: 14
                    radius: 2
                    color: System.accent
                    rotation: _pos.position.directionValid
                                ? _pos.position.direction : 0
                    visible: _pos.position.speedValid
                          && _pos.position.speed > 0.3
                }
            }
        }
    }

    // Block taps when overlay is open (e.g. expanded player).
    MouseArea {
        anchors.fill: parent
        enabled: !root.interactive
        propagateComposedEvents: false
    }
}
