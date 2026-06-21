import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
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

    // ── POI viewport feed ─────────────────────────────────────────────────────
    // Debounced: on every pan/zoom we hand the visible bbox + zoom to RoadInfo,
    // which re-clusters the POIs for that region (so panning to a far city shows
    // its POIs too). Skipped while POIs are hidden.
    Timer {
        id: _vpDebounce
        interval: 140; repeat: false
        onTriggered: root._pushViewport()
    }
    function _pushViewport() {
        if (!_map) return
        const pts = [Qt.point(0, 0), Qt.point(width, 0),
                     Qt.point(0, height), Qt.point(width, height)]
        let minLat = 90, maxLat = -90, minLon = 180, maxLon = -180, ok = false
        for (let i = 0; i < pts.length; ++i) {
            const c = _map.toCoordinate(pts[i], false)
            if (!c.isValid || isNaN(c.latitude) || isNaN(c.longitude)) continue
            ok = true
            minLat = Math.min(minLat, c.latitude); maxLat = Math.max(maxLat, c.latitude)
            minLon = Math.min(minLon, c.longitude); maxLon = Math.max(maxLon, c.longitude)
        }
        if (ok) RoadInfo.updateViewport(minLat, minLon, maxLat, maxLon, _map.zoomLevel)
    }
    Connections {
        target: RoadInfo
        function onPoisVisibleChanged() { if (RoadInfo.poisVisible) root._pushViewport() }
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

    // Current-location indicator (reverse-geocoded street · area).
    property string _curStreet: ""
    property string _curArea:   ""
    property real   _lastGeoLat: 1000
    property real   _lastGeoLon: 1000

    // Long-press dropped pin (Google-style "drop a pin").
    property var _droppedPin: null         // QtPositioning.coordinate or null

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
        case "worship":     return "#7B5E57"
        case "park":        return "#388E3C"
        case "education":   return "#F9A825"
        case "attraction":  return "#E64A19"
        case "beauty":      return "#AD1457"
        case "gym":         return "#283593"
        case "automotive":  return "#455A64"
        default:            return "#607D8B"   // generic place
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
        case "worship":     return "qrc:/icons/church.svg"
        case "park":        return "qrc:/icons/park.svg"
        case "education":   return "qrc:/icons/school.svg"
        case "attraction":  return "qrc:/icons/attraction.svg"
        case "beauty":      return "qrc:/icons/beauty.svg"
        case "gym":         return "qrc:/icons/gym.svg"
        case "automotive":  return "qrc:/icons/car.svg"
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
        case "worship":     return "Templo"
        case "park":        return "Parque"
        case "education":   return "Educação"
        case "attraction":  return "Atração"
        case "beauty":      return "Beleza"
        case "gym":         return "Academia"
        case "automotive":  return "Automotivo"
        default:            return "Local"
        }
    }
    // Human label from the fine Overture/OSM category (falls back to bucket).
    readonly property var _subLabels: ({
        "restaurant":"Restaurante","bar":"Bar","pub":"Bar","cafe":"Café",
        "coffee_shop":"Cafeteria","fast_food_restaurant":"Fast food","bakery":"Padaria",
        "pizza_restaurant":"Pizzaria","ice_cream_shop":"Sorveteria","snack_bar":"Lanchonete",
        "churrascaria":"Churrascaria","steakhouse":"Churrascaria",
        "beauty_salon":"Salão de beleza","nail_salon":"Manicure","hair_salon":"Cabeleireiro",
        "barber":"Barbearia","spa":"Spa",
        "supermarket":"Supermercado","grocery_store":"Mercearia","convenience_store":"Conveniência",
        "pharmacy":"Farmácia","drugstore":"Farmácia",
        "hospital":"Hospital","clinic":"Clínica","doctor":"Médico","dentist":"Dentista",
        "bank":"Banco","atm":"Caixa eletrônico",
        "hotel":"Hotel","motel":"Motel","pousada":"Pousada",
        "gas_station":"Posto de combustível","clothing_store":"Loja de roupas",
        "shoe_store":"Calçados","furniture_store":"Móveis","hardware_store":"Material de construção",
        "electronics_store":"Eletrônicos","pet_store":"Pet shop","bookstore":"Livraria",
        "gym":"Academia","school":"Escola","church":"Igreja","place_of_worship":"Igreja",
        "cathedral":"Catedral","chapel":"Capela","mosque":"Mesquita","temple":"Templo",
        "park":"Parque","garden":"Jardim","playground":"Playground","beach":"Praia",
        "museum":"Museu","viewpoint":"Mirante","monument":"Monumento","art_gallery":"Galeria",
        "college_university":"Faculdade","university":"Universidade","library":"Biblioteca",
        "stadium":"Estádio","zoo":"Zoológico","theme_park":"Parque temático",
        "landmark_and_historical_building":"Ponto histórico"
    })
    function _poiLabel(poi) {
        const s = poi.subcat
        if (s && s.length) {
            if (_subLabels[s]) return _subLabels[s]
            return s.replace(/_/g, " ").replace(/\b\w/g, function(c){ return c.toUpperCase() })
        }
        return _poiCatLabel(poi.category)
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
    // A picked destination first enters a *preview* (route drawn + ETA card,
    // map framed on the whole route). Turn-by-turn / heading-up / auto-tilt
    // only kick in once the user taps "Iniciar" → navStarted = true.
    property bool navStarted: false
    // True while the POI side panel is open — lets Main hide the right-edge
    // FABs so they don't sit under the panel.
    readonly property bool poiPanelOpen: _selectedPoi !== null
    // Map bearing exposed so a floating compass can mirror it.
    readonly property real  bearing: _map ? _map.bearing : 0

    function resetBearing() { _map.bearing = 0 }

    // Camera snapshot / restore — used when the style switch recreates the map
    // so zoom/tilt/bearing/centre survive the theme change.
    function cameraState() {
        return { lat: _map.center.latitude, lon: _map.center.longitude,
                 zoom: _map.zoomLevel, tilt: _map.tilt, bearing: _map.bearing,
                 following: root._following }
    }
    function applyCamera(s) {
        if (!s) return
        root._following = false           // don't let the follow-tick fight the restore
        _map.zoomLevel = s.zoom
        _map.tilt      = s.tilt
        _map.bearing   = s.bearing
        _map.center    = QtPositioning.coordinate(s.lat, s.lon)
        root._following = s.following
    }
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

    function setDestination(coord, name, address) {
        // Snapshot the current view as the route origin BEFORE the
        // destination triggers a viewport fit — otherwise the next
        // route query uses the destination as both endpoints (no
        // real GPS yet) and OSRM rejects start==end.
        _routeOrigin = GPS.valid
                         ? GPS.coordinate
                         : _map.center
        destinationName = name || ""
        navStarted = false            // show the preview first
        destination = coord
        if (name)
            RoadInfo.addRecent(coord.latitude, coord.longitude, name, address || "")
    }

    // Commit to a previewed route: start turn-by-turn navigation.
    function startNavigation() {
        if (!hasDestination) return
        navStarted = true
        _recomputeManeuver()
        recenter()
    }

    // The point we use as "where the car is" for routing. Real GPS
    // when valid, else the map centre at the moment a destination is
    // chosen (so the user can pan to where they are before searching).
    property var _routeOrigin: null

    function clearDestination() {
        destination = null
        destinationName = ""
        navStarted = false
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

    // Reverse geocoder — coordinate → address. Used by the bottom location
    // indicator and the long-press dropped pin. One in-flight request at a
    // time (cb receives {street, area, text} or null).
    GeocodeModel {
        id: _revGeo
        plugin: _osmServices
        autoUpdate: false
        limit: 1
        property var _cb: null
        onStatusChanged: {
            if (status === GeocodeModel.Ready) {
                const cb = _cb; _cb = null
                if (cb) {
                    if (count > 0) {
                        const a = get(0).address
                        cb({ street: a.street,
                             area:  a.district || a.city || a.county || a.state,
                             text:  a.text })
                    } else cb(null)
                }
            } else if (status === GeocodeModel.Error) {
                const cb = _cb; _cb = null; if (cb) cb(null)
            }
        }
    }
    function reverseGeocode(coord, cb) {
        if (_revGeo.status === GeocodeModel.Loading) return   // busy → skip
        _revGeo._cb   = cb
        _revGeo.query = coord
        _revGeo.update()
    }

    // Long-press → drop a pin. While the search panel is setting Home/Work the
    // pin is saved to that slot; otherwise it opens the info card so you can
    // navigate or save it. The address fills in once reverse geocoding returns.
    function _dropPinAt(coord) {
        if (RoadInfo.pendingPlace !== "") {
            RoadInfo.savePlace(RoadInfo.pendingPlace, coord.latitude, coord.longitude,
                RoadInfo.pendingPlace === "home" ? "Casa" : "Trabalho")
            return
        }
        root._selectedPoi = { lat: coord.latitude, lon: coord.longitude,
                              category: "place", name: "Ponto no mapa",
                              subcat: "", address: "", _dropped: true }
        reverseGeocode(coord, function(a) {
            const p = root._selectedPoi
            if (a && p && p._dropped)
                root._selectedPoi = { lat: p.lat, lon: p.lon, category: "place",
                    name: a.street || "Ponto no mapa", subcat: "",
                    address: a.text || "", _dropped: true }
        })
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

            // Refresh the location indicator after moving ~120 m (Nominatim
            // reverse geocode — online; left blank when it fails/offline).
            if (root._distM(root._lastGeoLat, root._lastGeoLon, lat, lon) > 120) {
                root._lastGeoLat = lat; root._lastGeoLon = lon
                root.reverseGeocode(GPS.coordinate, function(a) {
                    if (a) { root._curStreet = a.street || a.area || ""
                             root._curArea   = a.street ? (a.area || "") : "" }
                })
            }
        }
    }

    // Small equirect distance (m) for the indicator throttle.
    function _distM(la1, lo1, la2, lo2) {
        if (la1 > 999) return 1e9
        const mlat = (la1 + la2) * 0.5 * Math.PI / 180
        const dx = (lo2 - lo1) * 111320 * Math.cos(mlat)
        const dy = (la2 - la1) * 111320
        return Math.sqrt(dx*dx + dy*dy)
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
                // Frame the whole route only in preview; once navigating we
                // stay locked on the car instead.
                if (r && r.path && r.path.length > 0 && !root.navStarted)
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
        // While previewing (route shown but trip not started) Nav stays
        // inactive — no turn-by-turn banner, no auto-tilt/heading-up.
        if (!root.hasDestination || _routes.count === 0 || !root.navStarted) {
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

        // Re-cluster POIs when the viewport changes.
        onCenterChanged:    _vpDebounce.restart()
        onZoomLevelChanged: _vpDebounce.restart()
        Component.onCompleted: _vpDebounce.restart()   // initial POI load

        // Smooth heading rotation when following in navigation mode.
        Behavior on bearing {
            enabled: _following && GPS.valid && GPS.speed > 3.0
            RotationAnimation {
                duration: 900
                direction: RotationAnimation.Shortest
                easing.type: Easing.Linear
            }
        }

        // Smooth tilt animation for programmatic 2D↔3D transitions (recenter,
        // navigation). Disabled while the user is actively shoving so the pitch
        // tracks the fingers 1:1 — any angle between flat and 45° — instead of
        // the animation fighting every frame and snapping to the extremes.
        Behavior on tilt {
            enabled: _twoFinger._mode !== "tilt"
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
            // Whole-gesture accumulation. The eGalax fragments one finger drag
            // into many short active/inactive cycles, so we track the gesture
            // across cycles and only judge tap-vs-pan once the finger is truly
            // up (no new cycle for _tapEnd.interval). Small total travel = tap.
            property bool _gActive: false
            property real _gStartX: 0
            property real _gStartY: 0
            property real _gLastX: 0
            property real _gLastY: 0
            property double _gStartTime: 0

            onActiveChanged: {
                if (active) {
                    _lastX = 0; _lastY = 0
                    _tapEnd.stop()
                    if (!_gActive) {
                        _gActive = true
                        _gStartX = centroid.pressPosition.x
                        _gStartY = centroid.pressPosition.y
                        _gStartTime = Date.now()
                    }
                    _gLastX = centroid.position.x
                    _gLastY = centroid.position.y
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
                    _tapEnd.restart()              // maybe gesture ended — wait & judge
                }
            }
            onTranslationChanged: {
                if (_inExcludedZone) return
                const dx = translation.x - _lastX
                const dy = translation.y - _lastY
                _lastX = translation.x
                _lastY = translation.y
                _map.pan(-dx, -dy)
                _gLastX = centroid.position.x      // remember where we ended up
                _gLastY = centroid.position.y
            }
        }

        // Fires once the finger has truly lifted (no new drag cycle for its
        // interval). A tap = short and ends near where it began (net
        // displacement, so a transient jitter spike that springs back doesn't
        // count); a pan travels far and/or lasts long → no pin.
        Timer {
            id: _tapEnd
            interval: 220; repeat: false
            onTriggered: {
                const dx = _drag._gLastX - _drag._gStartX
                const dy = _drag._gLastY - _drag._gStartY
                const net = Math.sqrt(dx * dx + dy * dy)
                const dt  = Date.now() - _drag._gStartTime
                console.warn("TAP end net=" + net.toFixed(0) + " dt=" + dt)
                _drag._gActive = false
                if (net < 35 && dt < 600) {
                    const c = _map.toCoordinate(Qt.point(_drag._gStartX, _drag._gStartY), false)
                    if (c && c.isValid) root._dropPinAt(c)
                }
            }
        }

        // Two-finger zoom / rotate / tilt from the raw touch points. Working
        // with the actual finger positions (in px) gives a clean discriminator
        // that PinchHandler's jittery activeScale never did:
        //   • separation changes  → zoom (+ twist → rotate)
        //   • fingers stay the same distance apart and move vertically → tilt
        // The mode locks on the first decisive motion and never flips, so a
        // tremor during zoom can't tilt, and a shove can't zoom.
        MultiPointTouchArea {
            id: _twoFinger
            anchors.fill: parent
            enabled: root.interactive
            minimumTouchPoints: 2
            maximumTouchPoints: 2
            mouseEnabled: false
            touchPoints: [ TouchPoint { id: _tpA }, TouchPoint { id: _tpB } ]

            property real   _d0: 1
            property real   _cy0: 0
            property real   _ang0: 0
            property real   _startZoom: 14
            property real   _startTilt: 0
            property real   _startBearing: 0
            property string _mode: ""        // "" | zoom | tilt

            function _dist()  { const dx = _tpB.x - _tpA.x, dy = _tpB.y - _tpA.y
                                return Math.max(1, Math.sqrt(dx*dx + dy*dy)) }
            function _cy()    { return (_tpA.y + _tpB.y) / 2 }
            function _angle() { return Math.atan2(_tpB.y - _tpA.y, _tpB.x - _tpA.x) * 180 / Math.PI }

            onPressed: {
                _d0 = _dist(); _cy0 = _cy(); _ang0 = _angle()
                _startZoom = _map.zoomLevel; _startTilt = _map.tilt; _startBearing = _map.bearing
                _mode = ""
            }
            onUpdated: {
                const d = _dist(), cy = _cy()
                const sepDev  = Math.abs(d - _d0)          // px the fingers spread/closed
                const vertDev = Math.abs(cy - _cy0)        // px the pair moved vertically

                if (_mode === "") {
                    if      (sepDev > 24)                  _mode = "zoom"
                    else if (vertDev > 34 && sepDev < 14)  _mode = "tilt"
                    else return                            // not decisive yet
                }

                if (_mode === "zoom") {
                    _map.zoomLevel = Math.max(2, Math.min(19,
                        _startZoom + Math.log(d / _d0) / Math.log(2)))
                    let b = _startBearing - (_angle() - _ang0)
                    while (b < 0)   b += 360
                    while (b > 360) b -= 360
                    _map.bearing = b
                } else if (_mode === "tilt") {
                    _map.tilt = Math.max(0, Math.min(45,
                        _startTilt - (cy - _cy0) * 0.30))
                }
            }
            onReleased: _mode = ""
        }

        WheelHandler {
            enabled: root.interactive
            onWheel: (ev) => {
                _map.zoomLevel = Math.max(2, Math.min(19,
                    _map.zoomLevel + ev.angleDelta.y / 360))
            }
        }

        // Double-tap zooms; a single tap on empty map drops a pin (exactly how
        // Tesla's map works — long-press isn't usable on this eGalax panel,
        // whose firmware anti-jitter can't report a sustained hold). POI markers
        // consume their own taps, so this only fires on bare map.
        TapHandler {
            id: _tap
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
                        color: Colours.palette.m3primary; opacity: 0.15
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
                    Rectangle { anchors.centerIn: parent; width:22; height:22; radius:11; color:Colours.palette.m3primary }
                }

                // ── Style 1: pulse beacon ─────────────────────────────────────
                Item {
                    visible: root._markerStyle === 1
                    anchors.fill: parent

                    Rectangle {
                        anchors.centerIn: parent; width:22; height:22; radius:11
                        color:"transparent"; border.color:Colours.palette.m3primary; border.width:2
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
                    Rectangle { anchors.centerIn: parent; width:14; height:14; radius: 7; color:Colours.palette.m3primary }
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
                            fillColor: Colours.palette.m3primary; strokeColor:"white"; strokeWidth:2
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

        // ── Dropped pin (long-press) ──────────────────────────────────────────
        MapQuickItem {
            visible: root._selectedPoi && root._selectedPoi._dropped === true
            coordinate: visible
                ? QtPositioning.coordinate(root._selectedPoi.lat, root._selectedPoi.lon)
                : QtPositioning.coordinate(0, 0)
            anchorPoint.x: 16; anchorPoint.y: 40
            z: 5
            sourceItem: Item {
                width: 32; height: 40
                Rectangle {       // tip
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 20
                    width: 12; height: 12; rotation: 45
                    color: "#D32F2F"; border.color: "white"; border.width: 2; z: -1
                }
                Rectangle {       // head
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: 30; height: 30; radius: 15
                    color: "#D32F2F"; border.color: "white"; border.width: 2
                    Rectangle { anchors.centerIn: parent; width: 10; height: 10
                                radius: 5; color: "white" }
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
                    color: Colours.palette.m3primary
                    border.color: "#FFFFFF"
                    border.width: 3
                    z: -1
                }
                Rectangle {       // head
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: 36; height: 36
                    radius: 18
                    color: Colours.palette.m3primary
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
            line.color: Colours.palette.m3primary
            line.width: 6
            opacity: 0.85
        }

        // ── POI markers (importance + collision declutter, Google-style) ─────
        // RoadInfo.clusters yields a "point" (full marker) for prominent POIs
        // and a "dot" (minor) for the rest that survive collision; dots promote
        // to full markers as you zoom in. Icons are plain white Images (no
        // MultiEffect shader per marker → cheap at scale).
        MapItemView {
            model: RoadInfo.poisVisible ? RoadInfo.clusters : []
            delegate: MapQuickItem {
                required property var modelData
                readonly property bool _isDot: modelData.type === "dot"
                readonly property bool _sel: !!root._selectedPoi
                    && root._selectedPoi.lat === modelData.lat
                    && root._selectedPoi.lon === modelData.lon
                readonly property bool _isDest: root.hasDestination
                    && Math.abs(root.destination.latitude  - modelData.lat) < 1e-7
                    && Math.abs(root.destination.longitude - modelData.lon) < 1e-7
                visible: !_isDest
                coordinate: QtPositioning.coordinate(modelData.lat, modelData.lon)
                anchorPoint.x: width / 2; anchorPoint.y: height / 2
                z: _sel ? 10 : (_isDot ? 0 : 1)

                sourceItem: Loader {
                    sourceComponent: _isDot ? _dotDelegate : _pointDelegate
                }

                // Full marker — colored disc + white icon.
                Component {
                    id: _pointDelegate
                    Rectangle {
                        width: _sel ? 36 : 28; height: width; radius: width / 2
                        color: root._poiColor(modelData.category)
                        border.color: "white"; border.width: _sel ? 3 : 2
                        Behavior on width { NumberAnimation { duration: 120 } }
                        Image {
                            anchors.centerIn: parent
                            width: parent.width * 0.58; height: width
                            source: root._poiIcon(modelData.category)
                            sourceSize.width: 32; sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit; smooth: true
                        }
                        MouseArea { anchors.fill: parent
                                    onClicked: root._selectedPoi = modelData }
                    }
                }
                // Minor POI — small category-colored dot, still tappable.
                Component {
                    id: _dotDelegate
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: root._poiColor(modelData.category)
                        border.color: "white"; border.width: 1.5
                        MouseArea { anchors.fill: parent
                                    onClicked: root._selectedPoi = modelData }
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
        color: RoadInfo.overLimit ? "#D32F2F" : Colours.palette.m3surfaceContainerHigh
        opacity: 0.92
        border.color: RoadInfo.overLimit ? "#FF6B6B" : Colours.palette.m3outlineVariant
        border.width: 1
        visible: GPS.valid && GPS.speed > 0.3

        Behavior on color { ColorAnimation { duration: 250 } }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 10 }
            text: Math.round(root._speedKph)
            color: RoadInfo.overLimit ? "white" : Colours.palette.m3onSurface
            font.pixelSize: 22; font.weight: Font.Bold
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 9 }
            text: "km/h"
            color: RoadInfo.overLimit ? "#FFE0E0" : Colours.palette.m3onSurfaceVariant
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

    // ── POI card (tap a place / drop a pin → details + actions) — Tesla style ─
    // Full-height side panel on the LEFT with the same edge gap as the toasts,
    // so it has room for richer content (place photos, search, reviews) later.
    Rectangle {
        id: _poiCard
        readonly property bool _open: root._selectedPoi !== null
        // Keep the card mounted while it animates out, and keep showing the last
        // place so the content doesn't blank mid-slide.
        property var _lastPoi: ({})
        on_OpenChanged: if (_open) _lastPoi = root._selectedPoi

        visible: opacity > 0.01
        z: 950
        anchors {
            left: parent.left; top: parent.top; bottom: parent.bottom
            leftMargin: Theme.spaceL
            topMargin: Theme.spaceL
            bottomMargin: Theme.spaceL + root.bottomOffset
        }
        width: 380
        radius: Theme.radiusL
        color: Colours.palette.m3surfaceContainerHigh
        border.color: Colours.palette.m3outlineVariant; border.width: 1

        // Slide in/out from the left edge + fade (Tesla-style), emphasized motion.
        opacity: _open ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }

        readonly property var  poi: root._selectedPoi || _lastPoi || ({})
        readonly property color catColor: root._poiColor(poi.category)
        readonly property real distM: root._selectedPoi && GPS.valid
            ? QtPositioning.coordinate(poi.lat, poi.lon).distanceTo(GPS.coordinate) : -1
        readonly property string distStr: distM < 0 ? ""
            : (distM >= 1000 ? (distM/1000).toFixed(1) + " km" : Math.round(distM) + " m")
        readonly property bool hasPhone: !!poi.phone   && ("" + poi.phone).length > 0
        readonly property bool hasWeb:   !!poi.website && ("" + poi.website).length > 0
        readonly property bool hasAddr:  !!poi.address && ("" + poi.address).length > 0
        property bool fav: false
        onPoiChanged: fav = root._selectedPoi
                        ? RoadInfo.isFavorite(poi.lat, poi.lon) : false

        transform: Translate { x: _poiCard._open ? 0 : -(_poiCard.width + Theme.spaceL * 2)
            Behavior on x { Anim { easing: Tokens.anim.emphasizedDecel } } }

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

                // Header: name + close. Name elides to two lines (Tesla-style);
                // anchored to the top so a long title never overflows upward and
                // hides behind the panel edge.
                Item {
                    width: parent.width
                    height: Math.max(_poiName.implicitHeight, _panelClose.height)
                    StyledText {
                        id: _poiName
                        anchors { left: parent.left; right: _panelClose.left
                                  rightMargin: Theme.spaceS; top: parent.top }
                        text: _poiCard.poi.name && _poiCard.poi.name.length
                                ? _poiCard.poi.name : root._poiCatLabel(_poiCard.poi.category)
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.title.large
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                    IconButton {
                        id: _panelClose
                        anchors { right: parent.right; top: parent.top }
                        isRound: true
                        type: IconButton.Text
                        icon: "close"
                        onClicked: root._selectedPoi = null
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
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._poiLabel(_poiCard.poi)
                              + (_poiCard.distStr ? "   ·   " + _poiCard.distStr : "")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }

                // ── Actions — a prominent "Navegar" + round quick actions, all
                //    real ButtonBase components (ripple + radius morph). ────────
                RowLayout {
                    width: parent.width
                    spacing: Theme.spaceS

                    // All action buttons share one height; the round quick
                    // actions are square at that height so they line up with the
                    // prominent "Navegar".
                    readonly property int _btnH: 52

                    IconTextButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: parent._btnH
                        type: IconTextButton.Filled
                        icon: "navigation"
                        text: "Navegar"
                        iconLabel.fill: 1
                        onClicked: {
                            root.setDestination(
                                QtPositioning.coordinate(_poiCard.poi.lat, _poiCard.poi.lon),
                                _poiCard.poi.name || root._poiCatLabel(_poiCard.poi.category))
                            root._selectedPoi = null
                        }
                    }
                    IconButton {
                        Layout.preferredWidth: parent._btnH; Layout.preferredHeight: parent._btnH
                        isRound: true
                        type: IconButton.Tonal
                        icon: "call"
                        disabled: !_poiCard.hasPhone
                    }
                    IconButton {
                        Layout.preferredWidth: parent._btnH; Layout.preferredHeight: parent._btnH
                        isRound: true
                        type: IconButton.Tonal
                        icon: "language"
                        disabled: !_poiCard.hasWeb
                    }
                    IconButton {
                        Layout.preferredWidth: parent._btnH; Layout.preferredHeight: parent._btnH
                        isRound: true
                        isToggle: true
                        type: IconButton.Tonal
                        icon: "star"
                        checked: _poiCard.fav
                        onClicked: {
                            RoadInfo.toggleFavorite(_poiCard.poi.lat, _poiCard.poi.lon,
                                _poiCard.poi.name || root._poiCatLabel(_poiCard.poi.category))
                            _poiCard.fav = !_poiCard.fav
                        }
                    }
                }

                // Divider
                Rectangle { width: parent.width; height: 1; color: Colours.palette.m3outlineVariant
                            visible: _poiCard.hasAddr || _poiCard.hasPhone }

                // Address
                Row {
                    width: parent.width
                    visible: _poiCard.hasAddr
                    spacing: Theme.spaceM
                    MaterialIcon {
                        symbol: "location_on"; fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                    StyledText {
                        width: parent.width - Theme.iconS - Theme.spaceM
                        text: "" + (_poiCard.poi.address || "")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: 3
                    }
                }

                // Phone
                Row {
                    width: parent.width
                    visible: _poiCard.hasPhone
                    spacing: Theme.spaceM
                    MaterialIcon {
                        symbol: "call"; fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                    StyledText {
                        text: "" + (_poiCard.poi.phone || "")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
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
        color: Colours.palette.m3surfaceContainerHigh
        opacity: 0.96
        border.color: Colours.palette.m3outlineVariant; border.width: 1

        Row {
            anchors.centerIn: parent; spacing: 8

            Repeater {
                model: ["●", "◎", "▲"]
                delegate: Rectangle {
                    required property int    index
                    required property string modelData
                    width: 52; height: 52; radius: 26
                    color: root._markerStyle === index
                               ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g,
                                         Colours.palette.m3primary.b, 0.22)
                               : "transparent"
                    border.color: root._markerStyle === index ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                    border.width: root._markerStyle === index ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: root._markerStyle === index ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
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

    // ── Current-location indicator (Tesla-style) — street · area ──────────────
    // Reverse-geocoded from the GPS fix; hidden entirely when there's no fix
    // or no address (Tesla does the same when location is unavailable).
    Rectangle {
        id: _locPill
        visible: GPS.valid && root._curStreet !== "" && !RoadInfo.cameraAlert
                 && !root.poiPanelOpen
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Theme.spaceL + root.bottomOffset
        }
        width: _locCol.width + Theme.spaceL * 2
        height: _locCol.height + Theme.spaceS * 2
        radius: Theme.radiusM
        color: Colours.palette.m3surfaceContainerHigh
        opacity: 0.94
        border.color: Colours.palette.m3outlineVariant; border.width: 1

        Column {
            id: _locCol
            anchors.centerIn: parent
            spacing: 1
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root._curStreet
                color: Colours.palette.m3onSurface
                font.pixelSize: 15; font.weight: Font.Bold
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 360)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root._curArea !== ""
                text: root._curArea
                color: Colours.palette.m3onSurfaceVariant; font.pixelSize: 12
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 360)
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
