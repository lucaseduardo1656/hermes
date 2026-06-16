import QtQuick
import QtQuick.Shapes
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

    // True while the map is locked on to the GPS position.
    // Becomes false when the user pans; auto-restores after 8 s.
    property bool _following: true
    readonly property bool following: _following

    // Smoothed lat/lon — explicit animations so the first fix snaps immediately
    // instead of sliding from (0,0) to real position.
    property real _smoothLat: 0
    property real _smoothLon: 0
    readonly property var _smoothCoord: QtPositioning.coordinate(_smoothLat, _smoothLon)

    NumberAnimation { id: _latAnim; target: root; property: "_smoothLat"; duration: 1000; easing.type: Easing.Linear }
    NumberAnimation { id: _lonAnim; target: root; property: "_smoothLon"; duration: 1000; easing.type: Easing.Linear }

    property real _speedKph: 0
    NumberAnimation { id: _speedAnim; target: root; property: "_speedKph"; duration: 500; easing.type: Easing.Linear }

    // Continuously nudge the map center to the animated coord while following.
    Timer {
        id: _followTick
        interval: 32
        repeat: true
        running: _following && GPS.valid
        onTriggered: _map.center = root._smoothCoord
    }

    // Approximate meters-per-pixel at current zoom + latitude.
    // Used to scale the GPS accuracy ring to screen pixels.
    readonly property real _mpp: _map
        ? (156543.034
           * Math.cos(_smoothLat * Math.PI / 180)
           / Math.pow(2, _map.zoomLevel))
        : 10
    // Height in pixels from the bottom to exclude from map drag gestures.
    // Set from Main.qml when the player bar is visible so swipe-up in that
    // zone expands the player instead of panning the map.
    property real gestureBottomExclude: 0
    property real bottomOffset: 0
    property int  _markerStyle: 0          // 0=dot  1=pulse  2=arrow
    property bool _markerPickerVisible: false
    property var  _selectedPoi: null       // POI tapped → info card + route

    function _poiColor(cat) {
        switch (cat) {
        case "fuel":        return "#F57C00"
        case "charging":    return "#2E7D32"
        case "food":        return "#C2185B"
        case "supermarket": return "#1565C0"
        case "shopping":    return "#6A1B9A"
        case "bank":        return "#00695C"
        case "hospital":    return "#D32F2F"
        case "pharmacy":    return "#00897B"
        case "lodging":     return "#5D4037"
        default:            return "#555555"
        }
    }
    function _poiIcon(cat) {
        switch (cat) {
        case "fuel":        return "qrc:/icons/fuel.svg"
        case "charging":    return "qrc:/icons/charging.svg"
        case "food":        return "qrc:/icons/food.svg"
        case "supermarket": return "qrc:/icons/supermarket.svg"
        case "shopping":    return "qrc:/icons/shopping.svg"
        case "bank":        return "qrc:/icons/bank.svg"
        case "hospital":    return "qrc:/icons/hospital.svg"
        case "pharmacy":    return "qrc:/icons/pharmacy.svg"
        case "lodging":     return "qrc:/icons/lodging.svg"
        default:            return "qrc:/icons/place.svg"
        }
    }
    function _poiCatLabel(cat) {
        switch (cat) {
        case "fuel":        return "Posto"
        case "charging":    return "Carregador"
        case "food":        return "Alimentação"
        case "supermarket": return "Mercado"
        case "shopping":    return "Loja"
        case "bank":        return "Banco"
        case "hospital":    return "Saúde"
        case "pharmacy":    return "Farmácia"
        case "lodging":     return "Hospedagem"
        default:            return "Local"
        }
    }

    signal swipeUpFromBottom()
    property var  destination: null         // QtPositioning.coordinate or null
    // MapLibre style JSON URL. Set by the outer Loader from
    // Settings.appearance.mapStyleUrl. Changing it requires recreating
    // CarMap (the Plugin reads it at construction time), which the
    // Loader does for us.
    property string styleUrl: "https://tiles.openfreemap.org/styles/dark"

    readonly property bool  hasDestination: destination !== null
                                         && destination.isValid
    // Human label for the active destination (POI name or address), shown
    // persistently in the search bar / route header so navigation always
    // says where we're going.
    property string destinationName: ""
    // True while the POI side panel is open — lets Main hide the right-edge
    // FABs so they don't sit under the panel.
    readonly property bool poiPanelOpen: _selectedPoi !== null
    // Map bearing exposed so a floating compass can mirror it.
    readonly property real  bearing: _map ? _map.bearing : 0

    function resetBearing() { _map.bearing = 0 }
    readonly property real  routeDistanceM: _routes.count > 0
                                              ? _routes.get(0).distance : 0
    readonly property real  routeDurationS: _routes.count > 0
                                              ? _routes.get(0).travelTime : 0

    function recenter() {
        _following = true
        _unfollowTimer.stop()
        _map.bearing = GPS.directionValid && GPS.speed > 3.0
                        ? GPS.direction : 0
        _map.tilt = Nav.active ? 45 : 0
        if (GPS.valid) {
            _map.center = root._smoothCoord
            if (_map.zoomLevel < 15) _map.zoomLevel = Nav.active ? 17 : 16
        }
    }

    function setDestination(coord, name) {
        // Snapshot the current view as the route origin BEFORE the
        // destination triggers a viewport fit — otherwise the next
        // route query uses the destination as both endpoints (no
        // real GPS yet) and OSRM rejects start==end.
        _routeOrigin = GPS.valid
                         ? GPS.coordinate
                         : _map.center
        destinationName = name || ""
        destination = coord
    }

    // The point we use as "where the car is" for routing. Real GPS
    // when valid, else the map centre at the moment a destination is
    // chosen (so the user can pan to where they are before searching).
    property var _routeOrigin: null

    function clearDestination() {
        destination = null
        destinationName = ""
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
    // Re-enable auto-follow 8 s after the user last panned the map.
    Timer {
        id: _unfollowTimer
        interval: 8000
        repeat: false
        onTriggered: {
            _following = true
            if (GPS.valid)
                _map.center = GPS.coordinate
        }
    }

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
    // GPS is a C++ GpsController singleton injected via rootContext.
    // It connects to gpsd on localhost:2947 using the gpsd JSON protocol.

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
            const here = GPS.valid
                           ? GPS.coordinate
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

    onDestinationChanged: { _routeDebounce.restart(); root._remainingPath = [] }

    // Remaining route path — trimmed to current position so only the ahead
    // portion is drawn (Waze/Google Maps style).
    property var _remainingPath: []

    // Reroute throttle: max once per 4 s.
    Timer { id: _rerouteThrottle; interval: 4000; repeat: false }

    // _closestPathIdx: last known index on route.path closest to GPS.
    // Persisted so _updateRemainingPath doesn't scan from 0 every tick.
    property int _closestPathIdx: 0

    function _updateRemainingPath() {
        if (!GPS.valid || _routes.count === 0) return
        const path = _routes.get(0).path
        if (!path || path.length < 2) return
        const here = GPS.coordinate
        // Scan from _closestPathIdx - 5 (never go backwards more than 5 pts)
        const start = Math.max(0, root._closestPathIdx - 5)
        let minIdx = start, minDist = here.distanceTo(path[start])
        for (let i = start + 1; i < path.length; ++i) {
            const d = here.distanceTo(path[i])
            if (d < minDist) { minDist = d; minIdx = i }
            else if (d > minDist + 200) break  // getting further — stop early
        }
        root._closestPathIdx = minIdx
        // Keep one point behind for a smooth join at current position
        root._remainingPath = path.slice(Math.max(0, minIdx - 1))
    }

    function _checkReroute() {
        if (!GPS.valid || !root.hasDestination || _routes.count === 0) return
        if (_rerouteThrottle.running) return
        // Use closestPathIdx distance already computed in _updateRemainingPath
        const path = _routes.get(0).path
        if (!path || path.length === 0) return
        const d = GPS.coordinate.distanceTo(path[root._closestPathIdx])
        if (d > 30) {
            _rerouteThrottle.start()
            _routeDebounce.restart()
        }
    }

    Connections {
        target: GPS
        function onPositionChanged() {
            if (root.hasDestination) { _updateRemainingPath(); _recomputeManeuver(); _checkReroute() }
            if (!GPS.valid) return

            _speedAnim.to = GPS.speed * 3.6
            _speedAnim.restart()

            const lat = GPS.coordinate.latitude
            const lon = GPS.coordinate.longitude

            // First fix: snap immediately; subsequent fixes: animate.
            if (root._smoothLat === 0 && root._smoothLon === 0) {
                root._smoothLat = lat
                root._smoothLon = lon
            } else {
                _latAnim.to = lat; _latAnim.restart()
                _lonAnim.to = lon; _lonAnim.restart()
            }

            // Heading-up only at driving speed (>3 m/s = ~10 km/h).
            if (_following && GPS.directionValid && GPS.speed > 3.0)
                _map.bearing = GPS.direction
        }
    }

    // Auto-tilt: 45° when navigation starts, flat when it ends.
    Connections {
        target: Nav
        function onActiveChanged() {
            if (Nav.active) {
                _map.tilt = 45
                if (_map.zoomLevel < 15) _map.zoomLevel = 17
            } else {
                _map.tilt = 0
            }
        }
    }

    Connections {
        target: _routes
        function onCountChanged() {
            root._closestPathIdx = 0
            root._remainingPath  = []
            if (_routes.count > 0) {
                const r = _routes.get(0)
                if (r && r.path && r.path.length > 0)
                    _fitRouteToViewport(r.path)
            }
            _recomputeManeuver()
            _updateRemainingPath()
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
        const here  = GPS.valid
                        ? GPS.coordinate
                        : _map.center
        if (!route || !route.segments || route.segments.length === 0) {
            Nav.update(false, "", "", "straight", 0)
            return
        }

        // Pick the nearest maneuver that is roughly ahead of the user.
        // When driving, exclude maneuvers more than 110° behind the heading
        // (they have already been passed). Below driving speed the heading
        // filter is disabled so the banner still shows while stationary.
        const heading = GPS.directionValid && GPS.speed > 1.5 ? GPS.direction : -1
        let bestIdx  = -1
        let bestDist = Number.POSITIVE_INFINITY
        for (let i = 0; i < route.segments.length; ++i) {
            const m = route.segments[i].maneuver
            if (!m || !m.valid) continue
            const d = here.distanceTo(m.position)
            if (heading >= 0 && d > 25) {
                const az   = here.azimuthTo(m.position)
                const diff = Math.abs(((az - heading + 540) % 360) - 180)
                if (diff > 110) continue
            }
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

        // Smooth heading rotation when following in navigation mode.
        Behavior on bearing {
            enabled: _following && GPS.valid && GPS.speed > 3.0
            RotationAnimation {
                duration: 900
                direction: RotationAnimation.Shortest
                easing.type: Easing.Linear
            }
        }

        // Smooth tilt animation for 2D↔3D transitions.
        Behavior on tilt {
            NumberAnimation { duration: 700; easing.type: Easing.InOutCubic }
        }

        // ── Gestures ─────────────────────────────────────────────────────────
        // Bare Map has no built-in gestures in Qt 6; wire them with the
        // modern Pointer Handlers. Each handler tracks a delta against
        // its own previous frame so the pan is responsive without
        // multiplying-by-total-translation jumps.
        DragHandler {
            id: _drag
            target: null
            enabled: root.interactive
            minimumPointCount: 1
            maximumPointCount: 1
            property real _lastX: 0
            property real _lastY: 0
            property bool _inExcludedZone: false

            onActiveChanged: {
                if (active) {
                    _lastX = 0; _lastY = 0
                    _inExcludedZone = root.gestureBottomExclude > 0
                        && centroid.pressPosition.y > (root.height - root.gestureBottomExclude)
                    if (!_inExcludedZone) {
                        _following = false
                        _unfollowTimer.restart()
                    }
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

        // Two-finger vertical drag → pitch (3D tilt).
        // Swipe up = more tilt; swipe down = flatten.
        DragHandler {
            id: _pitchDrag
            minimumPointCount: 2
            maximumPointCount: 2
            target: null
            enabled: root.interactive
            property real _startTilt: 0
            onActiveChanged: if (active) _startTilt = _map.tilt
            onTranslationChanged: {
                if (!active) return
                _map.tilt = Math.max(0, Math.min(45,
                    _startTilt - translation.y * 0.35))
            }
        }

        WheelHandler {
            enabled: root.interactive
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
            visible: GPS.valid
            coordinate: root._smoothCoord
            anchorPoint.x: 32; anchorPoint.y: 32
            sourceItem: Item {
                width: 64; height: 64

                // ── Style 0: classic dot + chevron ───────────────────────────
                Item {
                    visible: root._markerStyle === 0
                    anchors.fill: parent

                    Rectangle {
                        readonly property real _r: Math.min(
                            GPS.accuracyValid && GPS.horizontalAccuracy > 0
                                ? GPS.horizontalAccuracy / root._mpp : 0, 80)
                        anchors.centerIn: parent
                        width: _r * 2; height: _r * 2; radius: _r
                        color: System.accent; opacity: 0.15
                        visible: _r > 18
                    }
                    Item {
                        anchors.centerIn: parent; width: 64; height: 64
                        rotation: GPS.directionValid ? ((GPS.direction - root.bearing) % 360 + 360) % 360 : 0
                        visible: GPS.speed > 1.5
                        Shape { anchors.fill: parent
                            ShapePath { fillColor: "white"; strokeColor: "transparent"
                                PathMove { x:32; y: 4 } PathLine { x:40; y:23 }
                                PathLine { x:32; y:18 } PathLine { x:24; y:23 }
                                PathLine { x:32; y: 4 } } }
                    }
                    Rectangle { anchors.centerIn: parent; width:28; height:28; radius:14; color:"white" }
                    Rectangle { anchors.centerIn: parent; width:22; height:22; radius:11; color:System.accent }
                }

                // ── Style 1: pulse beacon ─────────────────────────────────────
                Item {
                    visible: root._markerStyle === 1
                    anchors.fill: parent

                    Rectangle {
                        anchors.centerIn: parent; width:22; height:22; radius:11
                        color:"transparent"; border.color:System.accent; border.width:2
                        SequentialAnimation on scale { loops:Animation.Infinite
                            NumberAnimation { from:1; to:3.2; duration:1300; easing.type:Easing.OutQuad }
                            PauseAnimation  { duration:400 } }
                        SequentialAnimation on opacity { loops:Animation.Infinite
                            NumberAnimation { from:0.75; to:0; duration:1300; easing.type:Easing.OutQuad }
                            PauseAnimation  { duration:400 } }
                    }
                    Item {
                        anchors.centerIn: parent; width:64; height:64
                        rotation: GPS.directionValid ? ((GPS.direction - root.bearing) % 360 + 360) % 360 : 0
                        visible: GPS.speed > 1.5
                        Shape { anchors.fill: parent
                            ShapePath { fillColor:"white"; strokeColor:"transparent"
                                PathMove { x:32; y: 4 } PathLine { x:40; y:23 }
                                PathLine { x:32; y:18 } PathLine { x:24; y:23 }
                                PathLine { x:32; y: 4 } } }
                    }
                    Rectangle { anchors.centerIn: parent; width:20; height:20; radius:10; color:"white" }
                    Rectangle { anchors.centerIn: parent; width:14; height:14; radius: 7; color:System.accent }
                }

                // ── Style 2: navigation arrow ─────────────────────────────────
                Item {
                    visible: root._markerStyle === 2
                    anchors.fill: parent
                    rotation: GPS.directionValid && GPS.speed > 0.5
                                 ? ((GPS.direction - root.bearing) % 360 + 360) % 360 : 0
                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            fillColor: System.accent; strokeColor:"white"; strokeWidth:2
                            PathMove { x:32; y: 5 }
                            PathLine { x:50; y:52 }
                            PathLine { x:32; y:40 }
                            PathLine { x:14; y:52 }
                            PathLine { x:32; y: 5 }
                        }
                    }
                }

                // Tap → open style picker
                MouseArea {
                    anchors.fill: parent
                    onClicked: root._markerPickerVisible = !root._markerPickerVisible
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

        // ── Route polyline — trimmed to remaining path (Waze/Tesla style) ───
        MapPolyline {
            visible: root.hasDestination && root._remainingPath.length > 1
            path: root._remainingPath
            line.color: System.accent
            line.width: 6
            opacity: 0.85
        }

        // ── POI markers ──────────────────────────────────────────────────────
        MapItemView {
            model: RoadInfo.poisVisible ? RoadInfo.pois : []
            delegate: MapQuickItem {
                required property var modelData
                readonly property bool _sel: root._selectedPoi
                    && root._selectedPoi.lat === modelData.lat
                    && root._selectedPoi.lon === modelData.lon
                // Hide the POI dot that is the active destination — the
                // teardrop pin already marks it, avoid stacking both.
                readonly property bool _isDest: root.hasDestination
                    && Math.abs(root.destination.latitude  - modelData.lat) < 1e-7
                    && Math.abs(root.destination.longitude - modelData.lon) < 1e-7
                visible: !_isDest
                coordinate: QtPositioning.coordinate(modelData.lat, modelData.lon)
                anchorPoint.x: _sel ? 18 : 14; anchorPoint.y: _sel ? 18 : 14
                z: _sel ? 10 : 0
                sourceItem: Rectangle {
                    width: _sel ? 36 : 28; height: width; radius: width / 2
                    color: root._poiColor(modelData.category)
                    border.color: "white"; border.width: _sel ? 3 : 2
                    Behavior on width { NumberAnimation { duration: 120 } }
                    SvgIcon {
                        anchors.centerIn: parent
                        size: parent.width * 0.58; color: "white"
                        source: root._poiIcon(modelData.category)
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root._selectedPoi = modelData
                    }
                }
            }
        }

        // ── Speed-camera markers ─────────────────────────────────────────────
        MapItemView {
            model: RoadInfo.cameras
            delegate: MapQuickItem {
                required property var modelData
                coordinate: QtPositioning.coordinate(modelData.lat, modelData.lon)
                anchorPoint.x: 15; anchorPoint.y: 15
                sourceItem: Rectangle {
                    width: 30; height: 30; radius: 15
                    color: "#222"
                    border.color: "#FFC107"; border.width: 3
                    SvgIcon {
                        anchors.centerIn: parent
                        size: 16; color: "#FFC107"
                        source: "qrc:/icons/speed-camera.svg"
                    }
                }
            }
        }
    }

    // ── Speed HUD ────────────────────────────────────────────────────────────
    Rectangle {
        id: _speedHud
        anchors {
            left: parent.left; bottom: parent.bottom
            leftMargin: Theme.spaceL
            bottomMargin: Theme.spaceL + root.bottomOffset
        }
        width: 64; height: 64; radius: 32
        color: RoadInfo.overLimit ? "#D32F2F" : System.surface
        opacity: 0.92
        border.color: RoadInfo.overLimit ? "#FF6B6B" : System.border
        border.width: 1
        visible: GPS.valid && GPS.speed > 0.3

        Behavior on color { ColorAnimation { duration: 250 } }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 10 }
            text: Math.round(root._speedKph)
            color: RoadInfo.overLimit ? "white" : System.textPrimary
            font.pixelSize: 22; font.weight: Font.Bold
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 9 }
            text: "km/h"
            color: RoadInfo.overLimit ? "#FFE0E0" : System.textSecondary
            font.pixelSize: 11
        }
    }

    // ── Speed-limit sign (Brazil/EU style: red ring, number) ──────────────────
    Rectangle {
        id: _limitSign
        visible: GPS.valid && RoadInfo.speedLimit > 0
        anchors {
            left: _speedHud.right; verticalCenter: _speedHud.verticalCenter
            leftMargin: Theme.spaceS
        }
        width: 60; height: 60; radius: 30
        color: "white"
        border.color: "#D32F2F"; border.width: 6

        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            anchors.centerIn: parent
            text: RoadInfo.speedLimit
            color: "#111111"
            font.pixelSize: RoadInfo.speedLimit >= 100 ? 22 : 26
            font.weight: Font.Black
        }
    }

    // ── POI side panel (tap a place → details + actions) — Tesla style ────────
    Rectangle {
        id: _poiCard
        visible: root._selectedPoi !== null
        z: 950
        anchors {
            right: parent.right; top: parent.top; bottom: parent.bottom
            rightMargin: Theme.spaceL; topMargin: Theme.spaceL
            bottomMargin: Theme.spaceL + root.bottomOffset
        }
        width: 360
        radius: Theme.radiusL
        color: System.surface
        border.color: System.border; border.width: 1
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        readonly property var  poi: root._selectedPoi || ({})
        readonly property color catColor: root._poiColor(poi.category)
        readonly property real distM: root._selectedPoi && GPS.valid
            ? QtPositioning.coordinate(poi.lat, poi.lon).distanceTo(GPS.coordinate) : -1
        readonly property string distStr: distM < 0 ? ""
            : (distM >= 1000 ? (distM/1000).toFixed(1) + " km" : Math.round(distM) + " m")
        readonly property bool hasPhone: poi.phone && ("" + poi.phone).length > 0
        readonly property bool hasWeb:   poi.website && ("" + poi.website).length > 0
        readonly property bool hasAddr:  poi.address && ("" + poi.address).length > 0
        property bool fav: false
        onPoiChanged: fav = root._selectedPoi
                        ? RoadInfo.isFavorite(poi.lat, poi.lon) : false

        // slide-in from the right
        transform: Translate { x: _poiCard.visible ? 0 : 40
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }

        Flickable {
            anchors.fill: parent
            anchors.margins: Theme.spaceL
            contentHeight: _poiCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: _poiCol
                width: parent.width
                spacing: Theme.spaceL

                // Header: name + close
                Item {
                    width: parent.width
                    height: Math.max(_poiName.height, 30)
                    Text {
                        id: _poiName
                        anchors { left: parent.left; right: _panelClose.left
                                  rightMargin: Theme.spaceS; top: parent.top }
                        text: _poiCard.poi.name && _poiCard.poi.name.length
                                ? _poiCard.poi.name : root._poiCatLabel(_poiCard.poi.category)
                        color: System.textPrimary
                        font.pixelSize: 22; font.weight: Font.Bold
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                    Rectangle {
                        id: _panelClose
                        width: 30; height: 30; radius: 15
                        anchors { right: parent.right; top: parent.top }
                        color: _pcArea.pressed ? System.border : "transparent"
                        SvgIcon {
                            anchors.centerIn: parent; size: 16; color: System.textSecondary
                            source: "qrc:/icons/close.svg"
                        }
                        MouseArea { id: _pcArea; anchors.fill: parent
                                    onClicked: root._selectedPoi = null }
                    }
                }

                // Category + distance sub-line
                Row {
                    spacing: Theme.spaceS
                    SvgIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16; color: _poiCard.catColor
                        source: root._poiIcon(_poiCard.poi.category)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._poiCatLabel(_poiCard.poi.category)
                              + (_poiCard.distStr ? "   ·   " + _poiCard.distStr : "")
                        color: System.textSecondary; font.pixelSize: 14
                    }
                }

                // ── Action button row (navigate · call · site · save) ────────
                Row {
                    id: _actRow
                    width: parent.width
                    spacing: Theme.spaceS
                    readonly property real btnW: (width - 3 * spacing) / 4

                    component ActionBtn: Rectangle {
                        id: _ab
                        property string icon
                        property string label
                        property bool primary: false
                        property bool enabledAct: true
                        property bool active: false
                        signal act()
                        width: _actRow.btnW; height: 64; radius: Theme.radiusM
                        color: _ab.primary ? (_aArea.pressed ? System.accentDim : System.accent)
                                           : (_ab.active ? Qt.rgba(System.accent.r, System.accent.g, System.accent.b, 0.18)
                                                         : (_aArea.pressed ? System.border : "transparent"))
                        border.color: _ab.primary ? "transparent"
                                                  : (_ab.active ? System.accent : System.border)
                        border.width: _ab.primary ? 0 : 1
                        opacity: _ab.enabledAct ? 1 : 0.35
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            SvgIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: 22
                                color: _ab.primary ? "#000000"
                                                   : (_ab.active ? System.accent : System.textPrimary)
                                source: _ab.icon
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: _ab.label
                                color: _ab.primary ? "#000000"
                                                   : (_ab.active ? System.accent : System.textSecondary)
                                font.pixelSize: 11; font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: _aArea; anchors.fill: parent
                            enabled: _ab.enabledAct
                            onClicked: _ab.act()
                        }
                    }

                    ActionBtn {
                        icon: "qrc:/icons/arrow-straight.svg"; label: "Navegar"
                        primary: true
                        onAct: {
                            root.setDestination(
                                QtPositioning.coordinate(_poiCard.poi.lat, _poiCard.poi.lon),
                                _poiCard.poi.name || root._poiCatLabel(_poiCard.poi.category))
                            root._selectedPoi = null
                        }
                    }
                    ActionBtn {
                        icon: "qrc:/icons/phone.svg"; label: "Ligar"
                        enabledAct: _poiCard.hasPhone
                    }
                    ActionBtn {
                        icon: "qrc:/icons/globe.svg"; label: "Site"
                        enabledAct: _poiCard.hasWeb
                    }
                    ActionBtn {
                        icon: "qrc:/icons/star.svg"; label: "Salvar"
                        active: _poiCard.fav
                        onAct: {
                            RoadInfo.toggleFavorite(_poiCard.poi.lat, _poiCard.poi.lon,
                                _poiCard.poi.name || root._poiCatLabel(_poiCard.poi.category))
                            _poiCard.fav = !_poiCard.fav
                        }
                    }
                }

                // Divider
                Rectangle { width: parent.width; height: 1; color: System.border
                            visible: _poiCard.hasAddr || _poiCard.hasPhone }

                // Address
                Row {
                    width: parent.width
                    visible: _poiCard.hasAddr
                    spacing: Theme.spaceM
                    SvgIcon {
                        size: 18; color: System.textSecondary
                        source: "qrc:/icons/place.svg"
                    }
                    Text {
                        width: parent.width - 18 - Theme.spaceM
                        text: "" + (_poiCard.poi.address || "")
                        color: System.textPrimary; font.pixelSize: 14
                        wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: 3
                    }
                }

                // Phone
                Row {
                    width: parent.width
                    visible: _poiCard.hasPhone
                    spacing: Theme.spaceM
                    SvgIcon {
                        size: 18; color: System.textSecondary
                        source: "qrc:/icons/phone.svg"
                    }
                    Text {
                        text: "" + (_poiCard.poi.phone || "")
                        color: System.textPrimary; font.pixelSize: 14
                    }
                }
            }
        }
    }

    // ── Speed-camera proximity alert ──────────────────────────────────────────
    Rectangle {
        id: _camAlert
        visible: RoadInfo.cameraAlert
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Theme.spaceL + root.bottomOffset
        }
        width: _camRow.width + 28; height: 48; radius: 24
        color: "#222"
        border.color: "#FFC107"; border.width: 2
        opacity: 0.96

        // Pulse to draw the eye
        SequentialAnimation on border.width {
            running: RoadInfo.cameraAlert
            loops: Animation.Infinite
            NumberAnimation { from: 2; to: 3.5; duration: 600 }
            NumberAnimation { from: 3.5; to: 2; duration: 600 }
        }

        Row {
            id: _camRow
            anchors.centerIn: parent; spacing: 8
            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 22; color: "#FFC107"
                source: "qrc:/icons/speed-camera.svg"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var d = RoadInfo.nearestCameraDist
                    var s = d >= 1000 ? (d/1000).toFixed(1) + " km" : Math.round(d/10)*10 + " m"
                    return RoadInfo.nearestCameraLimit > 0
                             ? s + " · " + RoadInfo.nearestCameraLimit
                             : s
                }
                color: "white"; font.pixelSize: 17; font.weight: Font.Bold
            }
        }
    }

    // ── Marker style picker ───────────────────────────────────────────────────
    Rectangle {
        visible: root._markerPickerVisible
        z: 900
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: Theme.spaceL
            bottomMargin: Theme.spaceL + root.bottomOffset + 72
        }
        width: 196; height: 64; radius: 32
        color: System.surface
        opacity: 0.96
        border.color: System.border; border.width: 1

        Row {
            anchors.centerIn: parent; spacing: 8

            Repeater {
                model: ["●", "◎", "▲"]
                delegate: Rectangle {
                    required property int    index
                    required property string modelData
                    width: 52; height: 52; radius: 26
                    color: root._markerStyle === index
                               ? Qt.rgba(System.accent.r, System.accent.g,
                                         System.accent.b, 0.22)
                               : "transparent"
                    border.color: root._markerStyle === index ? System.accent : System.border
                    border.width: root._markerStyle === index ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: root._markerStyle === index ? System.accent : System.textSecondary
                        font.pixelSize: 22
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root._markerStyle = index
                            root._markerPickerVisible = false
                        }
                    }
                }
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
