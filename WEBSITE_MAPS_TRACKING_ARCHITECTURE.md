# K-TRASH Maps Tracking - System Architecture Diagram

## 1. HIGH-LEVEL SYSTEM ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          BROWSER (USER)                                         │
│                    (TrackingPetugas.js component)                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌────────────────────────┐         ┌──────────────────────────────────────┐  │
│  │  Leaflet Map Display   │         │  Socket.io Listener                  │  │
│  │  ├─ Driver Marker      │◄────────┤  ├─ subscribe('driver:location_      │  │
│  │  ├─ User Marker        │         │  │   updated')                       │  │
│  │  ├─ Route Polyline     │         │  ├─ subscribe('order:status_        │  │
│  │  └─ Fit Bounds         │         │  │   changed')                       │  │
│  └────────────────────────┘         └──────────────────────────────────────┘  │
│           ▲                                      ▲                              │
│           │ setDriverLocation()                 │ Socket events               │
│           │ setRouteGeoJson()                   │                            │
│           │                                     │                            │
│  ┌────────┴─────────────────────────────────────┴──────────────────────────┐  │
│  │                    React Component State                                 │  │
│  │  ├─ driverLocation: [lat, lng]                                          │  │
│  │  ├─ userLocation: [lat, lng]                                            │  │
│  │  ├─ routeGeoJson: {type: 'LineString', coordinates: [...]}             │  │
│  │  ├─ orderStatus: 'on_the_way' | 'arrived' | 'completed'               │  │
│  │  └─ orderData: {id, user_lat, user_lng, driver_name, ...}             │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
           │ HTTP API                        │ WebSocket
           ▼                                 ▼
       (Polling)                        (Real-time)
           
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        BACKEND API SERVER                                       │
│                         (Node.js + Express)                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────┐   ┌──────────────────────────────────┐   │
│  │  HTTP Routes                    │   │  Socket.io Handlers              │   │
│  │  GET /tracking/{orderId}────────┼───┤  - join:order_room               │   │
│  │  POST /driver/location──────────┼───┤  - driver:update_location        │   │
│  │  GET /orders/{orderId}──────────┼───┤  - order:state                   │   │
│  │  PATCH /orders/status/{id}──────┼───┤  - order:status_changed          │   │
│  │  POST /harga/...────────────────┼───┤  - disconnect                    │   │
│  └─────────────────────────────────┘   └──────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │               socketService.emitToOrder(orderId, event, data)            │  │
│  │               ↓                                                           │  │
│  │  Broadcasts event to all in room: order_${orderId}                      │  │
│  │  - broadcast 'driver:location_updated'                                  │  │
│  │  - broadcast 'order:status_changed'                                     │  │
│  │  - broadcast 'order:completed'                                          │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└────────────────────────────────┬────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   MySQL Database       │
                    │  ┌──────────────────┐  │
                    │  │ orders table      │  │
                    │  ├─ id              │  │
                    │  ├─ user_id         │  │
                    │  ├─ driver_id       │  │
                    │  ├─ status          │  │
                    │  ├─ user_lat/lng    │  │
                    │  └─ address         │  │
                    │  ┌──────────────────┐  │
                    │  │ driver_locations │  │
                    │  ├─ id              │  │
                    │  ├─ driver_id       │  │
                    │  ├─ order_id        │  │
                    │  ├─ lat/lng         │  │
                    │  └─ created_at      │  │
                    │  ┌──────────────────┐  │
                    │  │ users table       │  │
                    │  ├─ id              │  │
                    │  ├─ name            │  │
                    │  ├─ email           │  │
                    │  └─ role            │  │
                    └────────────────────────┘
```

---

## 2. DRIVER LOCATION UPDATE FLOW

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    DRIVER BROWSER (TrackingUser.js)                            │
│                                                                                 │
│  Geolocation API (GPS)                                                         │
│  navigator.geolocation.watchPosition({                                        │
│    enableHighAccuracy: true,                                                   │
│    maximumAge: 0,                                                              │
│    timeout: 15000                                                              │
│  })                                                                             │
│  ↓                                                                              │
│  Every GPS position change                                                     │
│  {coords: {latitude, longitude, accuracy, ...}}                               │
│  ↓                                                                              │
│  Calculate Haversine Distance                                                  │
│  from last known position                                                      │
│  ↓                                                                              │
│  ╔═ If distance > 15 meters ════════════════════════════════════════════════┐  │
│  ║                                                                           │  │
│  ║  ┌─────────────────────────────────────────────────────────────────┐    │  │
│  ║  │ 1. Update React State                                           │    │  │
│  ║  │    setDriverLocation([lat, lng])                                │    │  │
│  ║  │    ↓                                                             │    │  │
│  ║  │    Re-render map with new position                              │    │  │
│  ║  └─────────────────────────────────────────────────────────────────┘    │  │
│  ║                                                                           │  │
│  ║  ┌─────────────────────────────────────────────────────────────────┐    │  │
│  ║  │ 2. HTTP API Call (Persistence)                                 │    │  │
│  ║  │    POST /driver/location                                        │    │  │
│  ║  │    {                                                             │    │  │
│  ║  │      driver_id: 5,                                              │    │  │
│  ║  │      order_id: 123,                                             │    │  │
│  ║  │      lat: -7.6234,                                              │    │  │
│  ║  │      lng: 110.8234                                              │    │  │
│  ║  │    }                                                             │    │  │
│  ║  │    ↓                                                             │    │  │
│  ║  │    Backend inserts into driver_locations table                  │    │  │
│  ║  └─────────────────────────────────────────────────────────────────┘    │  │
│  ║                                                                           │  │
│  ║  ┌─────────────────────────────────────────────────────────────────┐    │  │
│  ║  │ 3. Socket.io Event (Real-time Broadcast)                       │    │  │
│  ║  │    updateDriverLocation(orderId, lat, lng)                     │    │  │
│  ║  │    ↓                                                             │    │  │
│  ║  │    emit('driver:update_location', {                            │    │  │
│  ║  │      orderId: 123,                                              │    │  │
│  ║  │      lat: -7.6234,                                              │    │  │
│  ║  │      lng: 110.8234                                              │    │  │
│  ║  │    })                                                            │    │  │
│  ║  └─────────────────────────────────────────────────────────────────┘    │  │
│  ║                                                                           │  │
│  ╚═══════════════════════════════════════════════════════════════════════════╝  │
│  Else: Movement < 15m → Skip                                                  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
           │ HTTP                                │ WebSocket
           ▼                                     ▼
  ┌─────────────────────────┐        ┌──────────────────────────┐
  │   Backend API Server    │        │   Socket.io Namespace    │
  │  POST /driver/location  │        │   (connected drivers)    │
  │          ↓              │        │          ↓               │
  │  Insert into DB         │        │  Receive event           │
  │  driver_locations table │        │          ↓               │
  │          ↓              │        │  socketService.emitTo    │
  │  (continues...)         │        │  Order(orderId, event)   │
  └─────────────────────────┘        └──────────────────────────┘
                                              │
                                              ▼
                    ┌─────────────────────────────────────────┐
                    │  Broadcast to Room: order_123           │
                    │  Event: 'driver:location_updated'       │
                    │  Payload: {                             │
                    │    orderId: 123,                        │
                    │    driverId: 5,                         │
                    │    lat: -7.6234,                        │
                    │    lng: 110.8234,                       │
                    │    timestamp: '2024-01-01T12:00:00Z'   │
                    │  }                                      │
                    └─────────────────────────────────────────┘
                                    │
                    ┌───────────────┬────────────────┐
                    ▼               ▼                ▼
        ┌─────────────────────┐ ┌──────────────┐ ┌──────────────┐
        │ USER BROWSER        │ │ OTHER DRIVER │ │ ADMIN PANEL  │
        │ (In order_123 room) │ │ (In room)    │ │ (monitoring) │
        └─────────────────────┘ └──────────────┘ └──────────────┘
               │ Receives event
               ▼
        subscribe('driver:location_updated', (data) => {
          setDriverLocation([data.lat, data.lng])  // Update marker
          fetchRouteManaged(...)                   // Recalc route
        })
               ▼
        Map updates → Marker moves smoothly (800ms)
```

---

## 3. REAL-TIME vs POLLING TRACKING

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                         REAL-TIME PATH (Fast)                                  │
│                                                                                 │
│  GPS Change → Socket Emit → Backend Receives → Broadcasts → User Updates      │
│     (ms)        (5ms)          (10ms)            (5ms)        (20ms)           │
│     │──────────────────────────────────────────────────────────────│           │
│                          ~40ms TOTAL LATENCY                        │           │
│                                                                     │           │
│  ✅ Smooth real-time tracking                                      │           │
│  ✅ Responsive to driver movement                                  │           │
│  ⚠️  Depends on Socket connection                                  │           │
│                                                                     │           │
└────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────┐
│                      POLLING PATH (Fallback)                                   │
│                                                                                 │
│  Every 3 seconds:                                                              │
│  User Browser → HTTP GET /tracking/123 → Backend Query → Return Latest         │
│     (poll)                                                                      │
│     │────────────────────────────────────────│                                │
│                          ~500-1000ms LATENCY                                    │
│                                                                                 │
│  ✅ Works even if Socket disconnected                                          │
│  ✅ Guaranteed update rate (predictable)                                       │
│  ⚠️  Delayed updates (up to 3 seconds)                                         │
│                                                                                 │
└────────────────────────────────────────────────────────────────────────────────┘

                    ┌──────────────────┐
                    │  COMBINED SYSTEM │
                    └──────────────────┘
                           │
        ┌──────────────────┴──────────────────┐
        ▼                                      ▼
    SOCKET CONNECTED?                   SOCKET DISCONNECTED?
        │                                      │
        ├─ Receive real-time events          ├─ Poll every 3 seconds
        │  (~40ms latency)                    │  (~500-1000ms latency)
        │                                      │
        └─ Fallback to polling if              └─ Still works reliably
           event arrives late
    
    Result: Best of both worlds - Fast AND Reliable
```

---

## 4. ROUTE CALCULATION PIPELINE

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                   ROUTE CALCULATION TRIGGER                                     │
│                                                                                  │
│  setDriverLocation([newLat, newLng]) OR setUserLocation([...])                 │
│           ▼                                                                      │
│  useEffect(() => {                                                              │
│    fetchRouteManaged(driverLocation, userLocation)                             │
│  }, [driverLocation, userLocation])                                            │
│           ▼                                                                      │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                     SMART OPTIMIZATION CHECKS                                   │
│                                                                                  │
│  ┌─ Check 1: CACHE ────────────────────────────────────────────────────────┐   │
│  │ coordKey = hash(from + to)                                              │   │
│  │ cache.get(coordKey) ?                                                   │   │
│  │ ├─ Yes: in cache < 60s? → USE CACHE (instant)                         │   │
│  │ └─ No: continue                                                         │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ┌─ Check 2: IN-FLIGHT REQUEST ─────────────────────────────────────────────┐   │
│  │ Is another route fetch happening?                                       │   │
│  │ ├─ Yes: Last request < 5s ago? → SKIP (debounce)                       │   │
│  │ └─ No: continue                                                         │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ┌─ Check 3: MOVEMENT THRESHOLD ────────────────────────────────────────────┐   │
│  │ Calculate haversine distance from last route calculation:                │   │
│  │   - Distance for 'from' (driver moved?)                                 │   │
│  │   - Distance for 'to' (user moved?)                                     │   │
│  │ Max distance > 50 meters?                                               │   │
│  │ ├─ Yes: Route is stale → RECALCULATE                                    │   │
│  │ └─ No: & Last request < 5s ago → SKIP                                   │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  If passes all checks: Continue to fetch ↓                                      │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                        OSRM REQUEST PIPELINE                                    │
│                                                                                  │
│  ┌─ SNAP POINTS TO ROAD ─────────────────────────────────────────────────────┐  │
│  │ GET https://router.project-osrm.org/nearest/v1/driving/lng,lat         │  │
│  │                                                                           │  │
│  │ Input: Raw GPS coordinates                                              │  │
│  │ Output: Snapped coordinates on actual road network                      │  │
│  │                                                                           │  │
│  │ Driver at: [-7.6234, 110.8234] (maybe off-road slightly)              │  │
│  │ Snaps to: [-7.6235, 110.8233] (nearest road point)                     │  │
│  │                                                                           │  │
│  │ User at: [-7.5234, 110.9234]                                           │  │
│  │ Snaps to: [-7.5233, 110.9235]                                          │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                              ▼                                                   │
│  ┌─ REQUEST ROUTE ───────────────────────────────────────────────────────────┐  │
│  │ GET https://router.project-osrm.org/route/v1/driving/                  │  │
│  │        110.8233,-7.6235;110.9235,-7.5233                                │  │
│  │        ?overview=full                                                    │  │
│  │        &geometries=geojson                                               │  │
│  │        &steps=true                                                       │  │
│  │        &alternatives=true  ← Get multiple options                       │  │
│  │                                                                           │  │
│  │ Response: {                                                              │  │
│  │   code: "Ok",                                                            │  │
│  │   routes: [                                                              │  │
│  │     {                                                                     │  │
│  │       distance: 5432,        // meters                                   │  │
│  │       duration: 523,         // seconds                                  │  │
│  │       geometry: {                                                        │  │
│  │         type: "LineString",                                             │  │
│  │         coordinates: [                                                   │  │
│  │           [110.8233, -7.6235],                                          │  │
│  │           [110.8240, -7.6240],                                          │  │
│  │           ...                                                            │  │
│  │           [110.9235, -7.5233]                                           │  │
│  │         ]                                                                │  │
│  │       },                                                                 │  │
│  │       legs: [{...}]                                                     │  │
│  │     },                                                                   │  │
│  │     {...},  // alternative routes                                       │  │
│  │     {...}                                                                │  │
│  │   ]                                                                      │  │
│  │ }                                                                        │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                              ▼                                                   │
│  ┌─ SELECT BEST ROUTE ───────────────────────────────────────────────────────┐  │
│  │ chooseBestRoute(routes):                                                │  │
│  │                                                                           │  │
│  │ For each route:                                                          │  │
│  │   score = duration + (numSteps * 2)                                      │  │
│  │                                                                           │  │
│  │ Route 1: score = 523 + (45 * 2) = 613                                   │  │
│  │ Route 2: score = 580 + (38 * 2) = 656                                   │  │
│  │ Route 3: score = 450 + (62 * 2) = 574  ← BEST                          │  │
│  │                                                                           │  │
│  │ Return: Route 3 geometry                                                │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                              ▼                                                   │
│  ┌─ CACHE & DISPLAY ─────────────────────────────────────────────────────────┐  │
│  │ routeCacheRef.set(key, {geo: route.geometry, ts: Date.now()})           │  │
│  │ setRouteGeoJson(route.geometry)                                          │  │
│  │                                                                           │  │
│  │ Leaflet GeoJSON renders polyline on map                                 │  │
│  │ - Color: Green (#22c55e)                                                │  │
│  │ - Width: 3px                                                             │  │
│  │ - Style: Dashed animation optional                                       │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  FALLBACK if OSRM unavailable:                                                  │
│  setRouteGeoJson({                                                              │
│    type: "LineString",                                                          │
│    coordinates: [[110.8233, -7.6235], [110.9235, -7.5233]]  // Straight line  │
│  })                                                                              │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. SOCKET EVENT SEQUENCE DIAGRAM

```
Time    User Browser           Backend                  Driver Browser
│       (TrackingPetugas)      (Socket Server)          (TrackingUser)
│
│  T0   Connect + Auth         ────auth:success────────→
│       emit('join:            
│        order_room')          
│       ────────────────→ Joins order_123 room
│                        (broadcast current state)
│       ←─────order:state─
│       Render map        
│
│  T1                                                   GPS updates >15m
│                                                       emit('driver:update
│                                                        _location')
│                        ─────driver:update_─────→
│                         location
│                        (Save to DB)
│                        emit to order_123 room:
│                        'driver:location_updated'
│       ←──────driver:location_updated─
│       setDriverLocation()
│       Map renders marker
│       Smooth 800ms animation
│
│  T2                                                   Mark: "I've arrived"
│                                                       emit('order:arrived')
│
│                        ─────order:arrived──────→
│                        broadcast to order_123
│       ←──────order:arrived─
│       setOrderStatus('arrived')
│       Show notification banner
│       Status stepper: 3/4 steps
│
│  T3   Poll every 3s:                                
│       GET /tracking/123   
│       ←─────tracking data──
│       (refreshes all data)
│
│  T4                                                   GPS updates >15m
│                        ─────driver:location
│       ←───────_updated──
│       Update marker
│
│  T5                                                   Submit waste data
│                                                       emit('order:
│                                                        completed',
│                                                        {sampah_data})
│                        ─────order:completed─────→
│                        broadcast to order_123
│       ←──────order:completed─
│       setOrderStatus('completed')
│       Show success notification
│       setTimeout 2.5s → redirect to dashboard
│
│  T6   Cleanup:                                        Cleanup:
│       emit('leave:     
│        order_room')    
│       ────────────────→ Remove from room
│                                                       Navigation away
│                                                       Disconnects
```

---

## 6. DATA FLOW THROUGH MAP RENDERING

```
┌─────────────────────────────────────────────────────────────────┐
│             React Component State                               │
│                                                                 │
│  driverLocation: [-7.6234, 110.8234]                           │
│  userLocation: [-7.5234, 110.9234]                             │
│  routeGeoJson: {type: 'LineString', coordinates: [...]}        │
│  orderStatus: 'on_the_way'                                     │
│  orderData: {id, name, phone, address, ...}                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                  ┌─────────────┼─────────────┐
                  ▼             ▼             ▼
            ┌──────────┐  ┌──────────┐  ┌──────────┐
            │ Smooth   │  │ Leaflet  │  │ Map      │
            │Position  │  │ GeoJSON  │  │ Overlay  │
            │ Interp.  │  │ Polyline │  │ Chips    │
            └────┬─────┘  └────┬─────┘  └────┬─────┘
                 │             │             │
                 ▼             ▼             ▼
              ┌────────────────────────────────────┐
              │  MapContainer (Leaflet)            │
              │  Center: userLocation              │
              │  Zoom: 15                          │
              │                                    │
              │  ┌─ TileLayer ─────────────────┐  │
              │  │ CARTO Voyager Basemap       │  │
              │  └─────────────────────────────┘  │
              │                                    │
              │  ┌─ GeoJSON Polyline ──────────┐  │
              │  │ (Green route)                │  │
              │  │ From driver to user         │  │
              │  └─────────────────────────────┘  │
              │                                    │
              │  ┌─ Marker (Driver) ───────────┐  │
              │  │ Position: driverSmoothPos   │  │
              │  │ Icon: Red marker            │  │
              │  │ Popup: Driver name          │  │
              │  └─────────────────────────────┘  │
              │                                    │
              │  ┌─ Marker (User) ──────────────┐ │
              │  │ Position: userSmoothPos      │ │
              │  │ Icon: Blue marker            │ │
              │  │ Popup: "Your Location"       │ │
              │  └──────────────────────────────┘ │
              │                                    │
              │  ┌─ FitRouteBounds ───────────┐  │
              │  │ Auto-fit both markers      │  │
              │  │ & route with padding      │  │
              │  └─────────────────────────────┘  │
              │                                    │
              │  ┌─ ChangeView ────────────────┐  │
              │  │ Follow driver (if not moved)│  │
              │  │ Zoom to 16                 │  │
              │  └─────────────────────────────┘  │
              │                                    │
              │  ┌─ Floating Overlays ─────────┐ │
              │  │ • Status badge               │ │
              │  │ • Live tracking indicator   │ │
              │  │ • User address              │ │
              │  │ • GPS coordinates           │ │
              │  └──────────────────────────────┘ │
              │                                    │
              └────────────────────────────────────┘
                                │
                                ▼
                         Browser Rendering
                         (requestAnimationFrame)
                                │
                                ▼
                         60 FPS Map Display
                         (if performance good)
```

---

## 7. ERROR & RECOVERY SCENARIOS

```
┌──────────────────────────────────────────────────────────┐
│              Socket Connection Lost                       │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  socket.on('disconnect')                                │
│         ↓                                                │
│  Auto-reconnect configured:                             │
│  ├─ Attempt 1: Wait 1s, try connect                     │
│  ├─ Attempt 2: Wait 2s, try connect                     │
│  ├─ Attempt 3: Wait 3s, try connect                     │
│  ├─ Attempt 4: Wait 4s, try connect                     │
│  ├─ Attempt 5: Wait 5s, try connect                     │
│  └─ Failed: Give up                                      │
│         ↓                                                │
│  Meanwhile: HTTP polling still active                   │
│  ├─ Every 3 seconds: GET /tracking/123                  │
│  ├─ Receives: Latest driver location                    │
│  ├─ Updates: setDriverLocation()                        │
│  └─ Display: Continues to work (slightly delayed)       │
│         ↓                                                │
│  When reconnected:                                      │
│  ├─ Rejoin order room                                   │
│  ├─ Receive latest order:state                          │
│  ├─ Resume real-time socket events                      │
│  └─ Combine with polling for best experience            │
│                                                           │
│  ✅ User sees no interruption (seamless)                 │
│                                                           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│            Geolocation Permission Denied                  │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  navigator.geolocation.watchPosition()                  │
│         ↓                                                │
│  Error callback fired                                   │
│  error.code = 1 (PERMISSION_DENIED)                     │
│         ↓                                                │
│  Driver still sees map with user location               │
│  But no driver location updates                         │
│         ↓                                                │
│  User can still track via polling                       │
│  (Gets last known driver position)                      │
│         ↓                                                │
│  Alert shown to driver: "GPS disabled"                  │
│                                                           │
│  ⚠️ Limited functionality but not broken                 │
│                                                           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│           OSRM Route Service Unavailable                  │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  fetch(osrm_url)                                        │
│         ↓                                                │
│  Network timeout OR 500 error                           │
│         ↓                                                │
│  Catch block executes                                   │
│         ↓                                                │
│  Fallback: Straight line route                          │
│  setRouteGeoJson({                                      │
│    type: "LineString",                                  │
│    coordinates: [[driver_lng, driver_lat],              │
│                  [user_lng, user_lat]]                  │
│  })                                                     │
│         ↓                                                │
│  Map displays direct path                              │
│  Not ideal, but functional                             │
│         ↓                                                │
│  Next location update retries OSRM                      │
│  (if moved > 50m)                                       │
│                                                           │
│  ✅ Map always shows something                           │
│                                                           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│            Database Query Slow/Timeout                    │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  GET /tracking/123 → 5 second response time             │
│         ↓                                                │
│  User still sees previously fetched data                │
│  (No blank screen)                                      │
│         ↓                                                │
│  Next poll in 3 seconds might succeed                   │
│  Or timeout too                                         │
│         ↓                                                │
│  Socket real-time updates unaffected                    │
│  (independent path)                                     │
│         ↓                                                │
│  System degrades gracefully                             │
│                                                           │
│  ✅ Robust to DB issues                                  │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## 8. PERFORMANCE CHARACTERISTICS

```
┌─────────────────────────────────────────────────────────────────┐
│                  LATENCY ANALYSIS                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Real-time (Socket.io):                                        │
│  ├─ Driver: GPS update detected          < 1ms                 │
│  ├─        → Socket emit                  ~5ms                 │
│  ├─        → Network round-trip           ~10-20ms             │
│  ├─        → Backend broadcast            ~5ms                 │
│  ├─        → User receives event          ~5ms                 │
│  ├─        → Map re-render               ~15-30ms             │
│  └─ TOTAL:                               ~40-80ms ✅ Fast    │
│                                                                 │
│  Polling (HTTP):                                               │
│  ├─ Poll trigger (3s interval)           ~3000ms              │
│  ├─ Backend query DB                     ~10-50ms             │
│  ├─ Network transmission                 ~50-100ms            │
│  ├─ Frontend processing                  ~5-10ms              │
│  ├─ Map re-render                        ~15-30ms             │
│  └─ TOTAL:                               ~3065-3190ms ⚠️ OK  │
│                                                                 │
│  Database Inserts:                                             │
│  ├─ driver_locations table                ~1-5ms              │
│  │ (Simple INSERT with 4 columns)                             │
│  └─ TOTAL:                               ~1-5ms ✅ Fast      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 BANDWIDTH ANALYSIS                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Per Location Update:                                          │
│  ├─ Socket event size:        ~150 bytes                       │
│  │  {orderId, driverId, lat, lng, timestamp}                   │
│  ├─ HTTP POST /driver/location:  ~200 bytes                    │
│  │  Request body + headers                                     │
│  └─ Total per update:           ~350 bytes                     │
│                                                                 │
│  With 15m movement threshold:                                  │
│  ├─ At 60 km/h (16.7 m/s):                                     │
│  │   15m / 16.7 m/s = ~0.9s between updates                   │
│  │   or ~1 update per second                                   │
│  ├─ Bandwidth: 350 bytes × 1 update/s = 350 b/s               │
│  │ (negligible; typical connection: 1-10 Mbps)                │
│  └─ Over 8 hour shift:                                         │
│     350 bytes × 3600s × 8 = ~10 MB traffic                    │
│                                                                 │
│  Polling every 3 seconds:                                      │
│  ├─ Per poll request: ~300 bytes GET                          │
│  ├─ Per poll response: ~1-2 KB (full order data)              │
│  ├─ Total per poll: ~1.3-2.3 KB                               │
│  ├─ Per 8 hour shift:                                         │
│     (1.8 KB × 3600s/8h) ÷ 3s × 8h = ~17 MB                    │
│  └─ Still reasonable                                           │
│                                                                 │
│  Total: ~27 MB per 8-hour shift                                │
│  ✅ Well within typical mobile data plan                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│              MAP RENDERING PERFORMANCE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Leaflet Map + Markers:                                        │
│  ├─ Initial render:            ~100-300ms                      │
│  ├─ Marker position update:    ~5-15ms                        │
│  ├─ Route GeoJSON draw:        ~20-50ms                       │
│  ├─ Smooth animation:          ~15-30ms per frame (800ms)     │
│  └─ Typical FPS:              ~30-60 fps ✅ Smooth            │
│                                                                 │
│  Memory Usage:                                                 │
│  ├─ Map container:             ~5-10 MB                       │
│  ├─ Tile cache:                ~10-20 MB (200 tiles)          │
│  ├─ Component state:           ~100 KB                        │
│  ├─ Route polyline:            ~50-200 KB                     │
│  └─ TOTAL:                     ~15-30 MB                      │
│     (acceptable for modern browsers)                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## KEY TAKEAWAYS

1. **Hybrid System**: Real-time Socket events + HTTP polling provides both speed AND reliability
2. **GPS Efficiency**: 15m movement threshold reduces unnecessary updates
3. **Route Caching**: 60-second TTL + 50m movement threshold prevents excessive OSRM calls
4. **Graceful Degradation**: Works without GPS, works without Socket, works without OSRM
5. **Performance**: ~40-80ms real-time latency, ~3s fallback latency
6. **Scalability**: ~350 bytes per update, ~27 MB per 8-hour shift per user

