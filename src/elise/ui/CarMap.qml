import QtQuick
import QtLocation
import QtPositioning
import Elise

// Single source of truth for the car map. Owns:
//   * Qt Location plugin (OSM raster + Nominatim geocode + OSRM routing)
//   * Qt Positioning source (NMEA via serial, GPSD via socket if running)
//   * the Map render with gestures, GPS pose marker, destination pin
//     and route polyline
//   * pure-JS helpers (geocode / setDestination / recenter) that the
//     outer UI calls
//
// Default centre: Lagoa da Prata, MG until a real fix lands.
Item {
    id: root

    // Register with the global bridge so pages outside Main (offline
    // maps settings, navigation overlays, etc.) can call into us
    // without having to thread a property through every Loader.
    Component.onCompleted:  MapBridge.current = root
    Component.onDestruction: if (MapBridge.current === root)
                                MapBridge.current = null

    // ── Public API ───────────────────────────────────────────────────────────
    property bool interactive: true
    // Height in pixels from the bottom to exclude from map drag gestures.
    // Set from Main.qml when the player bar is visible so swipe-up in that
    // zone expands the player instead of panning the map.
    property real gestureBottomExclude: 0
    signal swipeUpFromBottom()
    property var  destination: null         // QtPositioning.coordinate or null
    // MapLibre style JSON URL. Set by the outer Loader from
    // Settings.appearance.mapStyleUrl. Changing it requires recreating
    // CarMap (the Plugin reads it at construction time), which the
    // Loader does for us.
    property string styleUrl: "https://tiles.openfreemap.org/styles/dark"

    readonly property bool  hasDestination: destination !== null
                                         && destination.isValid
    // Map bearing exposed so a floating compass can mirror it.
    readonly property real  bearing: _map ? _map.bearing : 0

    function resetBearing() { _map.bearing = 0 }
    readonly property real  routeDistanceM: _routes.count > 0
                                              ? _routes.get(0).distance : 0
    readonly property real  routeDurationS: _routes.count > 0
                                              ? _routes.get(0).travelTime : 0

    function recenter() {
        // Recenter on GPS and snap the bearing back to north so the
        // user isn't stuck looking at a rotated viewport.
        _map.bearing = 0
        if (_pos.position.coordinate.isValid)
            _map.center = _pos.position.coordinate
    }

    function setDestination(coord) {
        // Snapshot the current view as the route origin BEFORE the
        // destination triggers a viewport fit — otherwise the next
        // route query uses the destination as both endpoints (no
        // real GPS yet) and OSRM rejects start==end.
        _routeOrigin = _pos.position.coordinate.isValid
                         ? _pos.position.coordinate
                         : _map.center
        destination = coord
    }

    // The point we use as "where the car is" for routing. Real GPS
    // when valid, else the map centre at the moment a destination is
    // chosen (so the user can pan to where they are before searching).
    property var _routeOrigin: null

    function clearDestination() {
        destination = null
        Nav.update(false, "", "", "straight", 0)
    }

    // Bounding box of what the user can currently see. Used by the
    // offline-maps page to capture the visible region for caching.
    function visibleBounds() {
        const tl = _map.toCoordinate(Qt.point(0, 0), false)
        const br = _map.toCoordinate(Qt.point(_map.width, _map.height), false)
        return {
            north: tl.latitude,
            south: br.latitude,
            west:  tl.longitude,
            east:  br.longitude,
            zoom:  _map.zoomLevel
        }
    }

    // Walk a bbox at the given zoom level, panning the viewport over
    // a coarse grid so MapLibre fetches and caches every tile. The
    // disk cache (maplibre.cache.*) then keeps them around for
    // offline use.
    //
    // We don't try to drive minZoom→maxZoom in one go — it'd thrash
    // the renderer. The caller passes one zoom level; multiple
    // zooms = call multiple times in sequence from QML.
    property var _preloadQueue: []
    property bool _preloadActive: false
    Timer {
        id: _preloadTick
        interval: 350
        repeat: true
        onTriggered: {
            if (root._preloadQueue.length === 0) {
                running = false
                root._preloadActive = false
                root.preloadDone()
                return
            }
            const next = root._preloadQueue.shift()
            _map.center = QtPositioning.coordinate(next.lat, next.lon)
            _map.zoomLevel = next.zoom
        }
    }
    signal preloadProgress(int done, int total)
    signal preloadDone()

    function preloadRegion(north, south, east, west, minZoom, maxZoom) {
        _preloadQueue = []
        // For each zoom level, sample center points spaced one
        // viewport apart (≈360° / 2^zoom of lon for a 1 tile width
        // viewport, scaled by viewport tile count).
        for (let z = minZoom; z <= maxZoom; ++z) {
            // Step ≈ size of one tile in degrees at this zoom.
            const step = 360 / Math.pow(2, z)
            for (let lat = south; lat <= north; lat += step) {
                for (let lon = west; lon <= east; lon += step) {
                    _preloadQueue.push({ lat: lat, lon: lon, zoom: z })
                }
            }
        }
        if (_preloadQueue.length === 0) return
        _preloadActive = true
        _preloadTick.start()
    }

    // Async geocode wrapper. cb receives [{address, coordinate}, ...].
    // Queues a single follow-up request if the user keeps typing while
    // a previous lookup is still loading — calling update() mid-flight
    // crashes the QML engine on some Qt 6 builds.
    function geocode(query, cb) {
        if (_geocoder.status === GeocodeModel.Loading) {
            _geocoder._pending  = cb
            _geocoder._queued   = query
            return
        }
        _geocoder._pending = cb
        _geocoder._queued  = ""
        _geocoder.query    = query
        _geocoder.update()
    }

    // ── Positioning ──────────────────────────────────────────────────────────
    PositionSource {
        id: _pos
        updateInterval: 1000
        active: true
        // The `nmea` plugin (installed by qt6positioning) auto-detects
        // a NMEA stream on /dev/serial0 once a GPS HAT is wired. Until
        // then position.coordinate is invalid and the GPS marker stays
        // hidden — the map itself still shows.
    }

    // ── Plugin (single instance shared by Map + Geocode + Route) ─────────────
    // MapLibre Native plugin — GPU-rendered vector tiles, smooth zoom,
    // identical engine the Tesla/BMW iX HMIs use. Style URL points at
    // OpenFreeMap's Liberty style (free, no API key, OpenMapTiles
    // schema), which is the closest open equivalent to Tesla's dark
    // base map. Swap to a different styleUrl later if you sign up for
    // MapTiler/Mapbox and want a more polished theme.
    Plugin {
        id: _osm
        name: "maplibre"
        PluginParameter {
            name: "maplibre.map.styles"
            value: root.styleUrl
        }
        // Persistent on-disk cache. Tiles, glyphs and sprites visited
        // here stay around for the next boot, so once a region has
        // been browsed it works offline. Half a gig is plenty for a
        // mid-sized state at z14..16 (≈40k tiles).
        PluginParameter {
            name: "maplibre.cache.directory"
            value: "/var/cache/elise-maplibre"
        }
        PluginParameter {
            name: "maplibre.cache.size"
            value: "536870912"   // 512 MiB
        }
        // maplibre.cache.memory is intentionally absent — the plugin
        // code unconditionally sets cache to `:memory:` if the param
        // is present (regardless of value), and only overrides it
        // back to disk if mkpath succeeds. Leaving it out makes the
        // disk-backed path the default.
        // OSRM + Nominatim still come from Qt's OSM-side defaults —
        // maplibre plugin only handles map rendering. We register a
        // second Plugin for routing/geocoding.
    }

    // Routing + geocoding plugin (OSM) — kept as the QtLocation OSM
    // plugin which wraps OSRM + Nominatim. We can't ask maplibre for
    // these; it's render-only.
    Plugin {
        id: _osmServices
        name: "osm"
        PluginParameter { name: "osm.useragent"
                          value: "Elise/0.1 hermes-infotainment" }
        PluginParameter { name: "osm.mapping.providersrepository.disabled"
                          value: "true" }
    }

    // ── Geocoding ────────────────────────────────────────────────────────────
    GeocodeModel {
        id: _geocoder
        plugin: _osmServices
        autoUpdate: false
        limit: 5
        property var    _pending: null
        property string _queued:  ""

        onStatusChanged: {
            if (status === GeocodeModel.Ready) {
                const cb = _pending; _pending = null
                const out = []
                for (let i = 0; i < count; ++i) {
                    const loc = get(i)
                    out.push({
                        address:    loc.address.text,
                        coordinate: loc.coordinate
                    })
                }
                if (cb) cb(out)
            } else if (status === GeocodeModel.Error) {
                const cb = _pending; _pending = null
                if (cb) cb([])
            }
            // Drain queued follow-up if the user typed more characters
            // while we were busy.
            if (status !== GeocodeModel.Loading && _queued !== "") {
                const q = _queued; _queued = ""
                root.geocode(q, _pending)
            }
        }
    }

    // ── Routing ──────────────────────────────────────────────────────────────
    // RouteQuery defaults are CarTravel + FastestRoute — we deliberately
    // omit the enum bindings, Qt 6's QML namespacing leaves the enum
    // names undefined and assigning [undefined] zeroes the flags.
    RouteQuery { id: _routeQuery }

    RouteModel {
        id: _routes
        plugin: _osmServices
        query: _routeQuery
        autoUpdate: false
    }

    Timer {
        id: _routeDebounce
        interval: 1500
        repeat: false
        onTriggered: {
            if (!root.hasDestination) return
            const here = _pos.position.coordinate.isValid
                           ? _pos.position.coordinate
                           : (_routeOrigin || _map.center)
            if (here.latitude === root.destination.latitude
                && here.longitude === root.destination.longitude) {
                // Routing demands distinct start/end. Skip — the user
                // hasn't moved away from the destination yet.
                return
            }
            _routeQuery.clearWaypoints()
            _routeQuery.addWaypoint(here)
            _routeQuery.addWaypoint(root.destination)
            _routes.update()
        }
    }

    onDestinationChanged: _routeDebounce.restart()
    Connections {
        target: _pos
        function onPositionChanged() {
            // Keep the active maneuver in sync with the user's
            // position, but don't re-issue the route query — that
            // would flip the polyline back to map.center the moment
            // the positionpoll plugin emits its initial reading.
            if (root.hasDestination) _recomputeManeuver()
        }
    }

    Connections {
        target: _routes
        function onCountChanged() {
            if (_routes.count > 0) {
                const r = _routes.get(0)
                if (r && r.path && r.path.length > 0)
                    _fitRouteToViewport(r.path)
            }
            _recomputeManeuver()
        }
    }

    // Frame the whole route polyline in the viewport. We do the
    // bounding box math by hand because QtPositioning.shapeToRectangle
    // wraps a GeoPath into a too-tight rectangle on some Qt 6 builds
    // and fitViewportToGeoShape ends up centring on a single endpoint.
    function _fitRouteToViewport(path) {
        let minLat =  90, maxLat = -90, minLon =  180, maxLon = -180
        for (let i = 0; i < path.length; ++i) {
            const c = path[i]
            if (c.latitude  < minLat) minLat = c.latitude
            if (c.latitude  > maxLat) maxLat = c.latitude
            if (c.longitude < minLon) minLon = c.longitude
            if (c.longitude > maxLon) maxLon = c.longitude
        }
        const rect = QtPositioning.rectangle(
            QtPositioning.coordinate(maxLat, minLon),
            QtPositioning.coordinate(minLat, maxLon))
        _map.fitViewportToGeoShape(rect, 80)
    }

    // ── Turn-by-turn maneuver tracking ───────────────────────────────────────
    // Walks the first route's segment list, finds the maneuver closest
    // ahead of the user's current position, and pushes its instruction
    // / distance / direction to the global Nav controller. The
    // NavigationOverlay banner up top binds to Nav.
    function _recomputeManeuver() {
        if (!root.hasDestination || _routes.count === 0) {
            Nav.update(false, "", "", "straight", 0)
            return
        }
        const route = _routes.get(0)
        const here  = _pos.position.coordinate.isValid
                        ? _pos.position.coordinate
                        : _map.center
        if (!route || !route.segments || route.segments.length === 0) {
            Nav.update(false, "", "", "straight", 0)
            return
        }

        // Pick the maneuver with the smallest forward distance.
        let bestIdx  = -1
        let bestDist = Number.POSITIVE_INFINITY
        for (let i = 0; i < route.segments.length; ++i) {
            const m = route.segments[i].maneuver
            if (!m || !m.valid) continue
            const d = here.distanceTo(m.position)
            if (d < bestDist) {
                bestDist = d
                bestIdx  = i
            }
        }
        if (bestIdx < 0) {
            Nav.update(false, "", "", "straight", 0)
            return
        }
        const m = route.segments[bestIdx].maneuver
        const dist = bestDist >= 1000
                       ? (bestDist / 1000).toFixed(1) + " km"
                       : Math.round(bestDist) + " m"
        Nav.update(true, m.instructionText, dist,
                   _maneuverDir(m.direction),
                   here.azimuthTo(m.position))
    }

    // Map QGeoManeuver::InstructionDirection (Qt enum int) to the
    // overlay's icon key (left/right/straight).
    function _maneuverDir(d) {
        // 0 NoDirection · 1 DirectionForward · 2 DirectionBearRight ·
        // 3 DirectionLightRight · 4 DirectionRight · 5 DirectionHardRight ·
        // 6 DirectionUTurnRight · 7 DirectionUTurnLeft · 8 DirectionHardLeft ·
        // 9 DirectionLeft · 10 DirectionLightLeft · 11 DirectionBearLeft
        if (d >= 2 && d <= 6) return "right"
        if (d >= 7 && d <= 11) return "left"
        return "straight"
    }

    // ── Map ──────────────────────────────────────────────────────────────────
    Map {
        id: _map
        anchors.fill: parent
        plugin: _osm
        center: QtPositioning.coordinate(-20.0294, -45.5390)   // Lagoa da Prata, MG
        zoomLevel: 14
        copyrightsVisible: false        // we render our own attribution
        activeMapType: supportedMapTypes.length > 0
                         ? supportedMapTypes[0] : null

        // ── Gestures ─────────────────────────────────────────────────────────
        // Bare Map has no built-in gestures in Qt 6; wire them with the
        // modern Pointer Handlers. Each handler tracks a delta against
        // its own previous frame so the pan is responsive without
        // multiplying-by-total-translation jumps.
        DragHandler {
            id: _drag
            target: null
            enabled: root.interactive
            property real _lastX: 0
            property real _lastY: 0
            property bool _inExcludedZone: false

            onActiveChanged: {
                if (active) {
                    _lastX = 0; _lastY = 0
                    _inExcludedZone = root.gestureBottomExclude > 0
                        && centroid.pressPosition.y > (root.height - root.gestureBottomExclude)
                } else {
                    if (_inExcludedZone && translation.y < -20)
                        root.swipeUpFromBottom()
                    _inExcludedZone = false
                }
            }
            onTranslationChanged: {
                if (_inExcludedZone) return
                const dx = translation.x - _lastX
                const dy = translation.y - _lastY
                _lastX = translation.x
                _lastY = translation.y
                _map.pan(-dx, -dy)
            }
        }

        PinchHandler {
            target: null
            enabled: root.interactive
            // Two-finger gesture drives both zoom and bearing — Qt's
            // PinchHandler reports activeScale (>0) and activeRotation
            // (degrees) during the same gesture.
            property real _startZoom:    14
            property real _startBearing: 0
            onActiveChanged: {
                if (active) {
                    _startZoom    = _map.zoomLevel
                    _startBearing = _map.bearing
                }
            }
            onActiveScaleChanged: {
                _map.zoomLevel = Math.max(2, Math.min(19,
                    _startZoom + Math.log(activeScale) / Math.log(2)))
            }
            onActiveRotationChanged: {
                // Finger rotates clockwise → map content should follow
                // clockwise, which means the camera bearing decreases.
                // Subtract to keep gesture and rendered direction aligned.
                let b = _startBearing - activeRotation
                while (b < 0)   b += 360
                while (b > 360) b -= 360
                _map.bearing = b
            }
        }

        WheelHandler {
            enabled: root.interactive
            // angleDelta.y is 120 per notch on most mice; one notch
            // moves a third of a zoom level — feels close to Google
            // Maps' wheel cadence.
            onWheel: (ev) => {
                _map.zoomLevel = Math.max(2, Math.min(19,
                    _map.zoomLevel + ev.angleDelta.y / 360))
            }
        }

        TapHandler {
            enabled: root.interactive
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onDoubleTapped: _map.zoomLevel = Math.min(19, _map.zoomLevel + 1)
        }


        // ── GPS pose marker ──────────────────────────────────────────────────
        MapQuickItem {
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
                // Heading wedge — only when actually moving.
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

        // ── Destination pin ──────────────────────────────────────────────────
        MapQuickItem {
            visible: root.hasDestination
            coordinate: root.destination || QtPositioning.coordinate(0, 0)
            anchorPoint.x: 18
            anchorPoint.y: 44
            sourceItem: Item {
                width: 36; height: 44

                Rectangle {       // shadow under tip
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: -2
                    width: 14; height: 5
                    radius: height / 2
                    color: "#40000000"
                }
                Rectangle {       // tip
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 24
                    width: 14; height: 14
                    rotation: 45
                    color: System.accent
                    border.color: "#FFFFFF"
                    border.width: 3
                    z: -1
                }
                Rectangle {       // head
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: 36; height: 36
                    radius: 18
                    color: System.accent
                    border.color: "#FFFFFF"
                    border.width: 3
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 12
                        radius: 6
                        color: "#FFFFFF"
                    }
                }
            }
        }

        // ── Route polyline ───────────────────────────────────────────────────
        MapItemView {
            model: _routes
            delegate: MapRoute {
                route: routeData
                line.color: System.accent
                line.width: 6
                opacity: 0.85
            }
        }
    }

    // ── OSM attribution ──────────────────────────────────────────────────────
    Text {
        anchors { right: parent.right; bottom: parent.bottom
                  rightMargin: 6; bottomMargin: 4 }
        text: "© OpenStreetMap"
        color: "#FFFFFF"
        opacity: 0.7
        font.pixelSize: 10
        style: Text.Outline
        styleColor: "#000000"
    }

    // Tap blocker when something is overlaying the map.
    MouseArea {
        anchors.fill: parent
        enabled: !root.interactive
        propagateComposedEvents: false
    }
}
