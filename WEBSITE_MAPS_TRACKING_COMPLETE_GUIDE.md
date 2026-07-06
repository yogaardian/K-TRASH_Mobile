# K-TRASH Website Maps Tracking System - Complete Technical Documentation

**Created**: July 6, 2026  
**Version**: 1.0  
**Scope**: Website codebase (pundesari folder) - Real-time tracking implementation

---

## 📋 Executive Summary

The K-TRASH platform uses a **hybrid real-time tracking system** combining:
- **GPS Geolocation API** for driver location capture
- **Socket.io WebSocket** for real-time event broadcasting
- **HTTP REST API** for persistence and fallback
- **Leaflet Maps** for visualization
- **OSRM Routing Engine** for route calculation

The system provides **bi-directional tracking**:
1. **User Tracking Driver** (TrackingPetugas) - User sees where driver is heading
2. **Driver Tracking User** (TrackingUser) - Driver sees user location and gets directions

---

## 🗺️ 1. MAP COMPONENTS & DISPLAY SYSTEM

### 1.1 Map Components Located

| Component | File | Purpose |
|-----------|------|---------|
| **TrackingPetugas** | `src/views/user/TrackingPetugas.js` | User tracks driver's real-time location to pickup point |
| **TrackingUser** | `src/views/driver/TrackingUser.js` | Driver tracks user location and submits waste data |
| **PickupPage** | `src/views/user/PickupPage.js` | User selects pickup location on map |
| **OrderDetail** | `src/views/driver/OrderDetail.js` | Driver previews order location before accepting |

### 1.2 Map Configuration

**File**: `src/config/mapConfig.js`

```javascript
// Basemap: CARTO Voyager (Google Maps-like modern style)
BASEMAP_URL = "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"

// Leaflet Configuration
MAP_OPTIONS = {
  maxZoom: 20,
  minZoom: 3,
  zoomControl: false,
  preferCanvas: false,  // Use SVG renderer (better for context)
}

// Default Center: Madiun, Jawa Timur
DEFAULT_CENTER = [-7.8, 110.3]
DEFAULT_ZOOM = 15
```

### 1.3 Marker Icons

Both user and driver locations use colored Leaflet icons:

```javascript
// Blue icon: User location
const blueIcon = L.Icon({
  iconUrl: "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34]
})

// Red icon: Driver location
const redIcon = L.Icon({
  iconUrl: "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34]
})
```

---

## 🔌 2. SOCKET.IO IMPLEMENTATION

### 2.1 Socket Context Structure

**File**: `src/context/SocketContext.js`

```typescript
// Core Socket Connection
const SocketContext = createContext()

// Socket Provider initializes when auth is complete
const SocketProvider = ({ children }) => {
  const { auth } = useAuth()
  const [socket, setSocket] = useState(null)
  const [isConnected, setIsConnected] = useState(false)
  const joinedOrderRoomsRef = useRef(new Set()) // Track joined rooms
}
```

#### Socket Connection Parameters

```javascript
const newSocket = io(socketUrl, {
  auth: {
    token: auth.token,  // JWT authentication
  },
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 5000,
  reconnectionAttempts: 5,
  transports: ['websocket'],  // Only WebSocket (from env: REACT_APP_SOCKET_TRANSPORTS)
  path: '/socket.io',
})
```

#### Connection Events Handled

```javascript
// Success
socket.on('connect', () => {
  // Rejoin rooms after reconnection
  const rooms = Array.from(joinedOrderRoomsRef.current)
  rooms.forEach(orderId => socket.emit('join:order_room', { orderId }))
})

// Failures
socket.on('connect_error', (error) => console.error(error))
socket.on('reconnect_error', (error) => console.error(error))
socket.on('reconnect_failed', () => console.error('Socket reconnect failed'))
socket.on('error', (error) => console.error(error))
```

### 2.2 Socket Methods Provided to Components

**Via useSocket() hook**:

```javascript
{
  socket,                          // Raw socket instance
  isConnected,                     // Boolean: connection status
  subscribe,                       // (event, callback) => unsubscribe
  emit,                           // (event, data) => void
  joinOrderRoom,                  // (orderId) => void
  leaveOrderRoom,                 // (orderId) => void
  updateDriverLocation,           // (orderId, lat, lng) => void
}
```

### 2.3 Socket Events - Complete Reference

**File**: `backend/src/constants/socketEvents.js`

#### Server Events (Backend → Frontend)

| Event | Payload | Used In | Purpose |
|-------|---------|---------|---------|
| `auth:success` | `{userId, userRole, userEmail, timestamp}` | SocketContext | Auth confirmation |
| `auth:error` | `{error}` | SocketContext | Auth failure |
| `order:state` | `{order: Order}` | TrackingPetugas, JOIN_ORDER_ROOM | Initial order state |
| `order:status_changed` | `{order: Order, status}` | TrackingPetugas | Order status updates |
| `order:accepted` | `{order: Order}` | TrackingPetugas | Driver accepted |
| `order:on_the_way` | `{order: Order}` | TrackingPetugas | Driver heading to user |
| `order:arrived` | `{order: Order}` | TrackingPetugas | Driver arrived |
| `order:completed` | `{order: Order, sampah_data}` | TrackingPetugas | Pickup completed |
| **`driver:location_updated`** | `{orderId, driverId, lat, lng, timestamp}` | **TrackingPetugas** | **Real-time driver GPS** |
| `notification:new` | `{id, title, message, type, timestamp, ...data}` | Various | Notifications |

#### Client Events (Frontend → Backend)

| Event | Payload | Sender | Purpose |
|-------|---------|--------|---------|
| `join:order_room` | `{orderId}` | User/Driver on TrackingPetugas/TrackingUser | Subscribe to order room |
| `leave:order_room` | `{orderId}` | User/Driver on page exit | Unsubscribe from room |
| `driver:update_location` | `{orderId, lat, lng}` | Driver via updateDriverLocation() | Send GPS to backend |

---

## 📡 3. DRIVER LOCATION TRACKING FLOW (Real-Time)

### 3.1 Where Driver Location Updates Come From

**File**: `src/views/driver/TrackingUser.js` - Lines 600-650

```javascript
// Geolocation watchPosition setup
useEffect(() => {
  if (!navigator.geolocation || !order?.id) return
  
  const watchId = navigator.geolocation.watchPosition(
    (pos) => {
      const lat = Number(pos.coords.latitude)
      const lng = Number(pos.coords.longitude)
      const nextLocation = [lat, lng]
      const prev = driverLocationRef.current
      
      // Only update if moved > 15 meters
      const shouldUpdate = !prev || haversine(prev, nextLocation) > 15
      
      if (shouldUpdate) {
        console.log("[DRIVER LOCATION UPDATE]", nextLocation)
        
        // 1. Update local state
        setDriverLocation(nextLocation)
        driverLocationRef.current = nextLocation
        
        // 2. Send to backend API (persistence)
        if (orderStatus !== "completed") {
          sendDriverLocation(lat, lng)  // HTTP POST
        }
        
        // 3. Emit via Socket.io to users in room
        updateDriverLocation(orderId, lat, lng)
      }
    },
    (err) => console.error("Geolocation error:", err),
    {
      enableHighAccuracy: true,
      maximumAge: 0,
      timeout: 15000
    }
  )
  
  return () => navigator.geolocation.clearWatch(watchId)
}, [order?.id, orderStatus, sendDriverLocation, updateDriverLocation])
```

**Key Details:**
- Uses browser Geolocation API with **high accuracy**
- Minimum movement threshold: **15 meters** (haversine distance)
- Updates trigger: GPS change, NOT time-based
- Sends to BOTH API and Socket simultaneously

### 3.2 Driver Location → Backend Flow

#### 3.2.1 HTTP API Endpoint

**Function**: `sendDriverLocation()` in TrackingUser.js

```javascript
const sendDriverLocation = useCallback(async (lat, lng) => {
  if (!orderId || !driverId) return
  try {
    await locationAPI.sendDriverLocation({
      driver_id: parseInt(driverId),
      order_id: orderId,
      lat,
      lng,
    })
  } catch (err) {
    console.error("Error sending driver location:", err)
  }
}, [driverId, orderId])
```

**API Endpoint**: `POST /driver/location`

**Request Format**:
```json
{
  "driver_id": 5,
  "order_id": 123,
  "lat": -7.6234,
  "lng": 110.8234
}
```

**Authentication**: Bearer Token (JWT in header)

#### 3.2.2 Socket Event Emission

**Function**: `updateDriverLocation()` in SocketContext.js

```javascript
const updateDriverLocation = useCallback(
  (orderId, lat, lng) => {
    emit('driver:update_location', { orderId, lat, lng })
  },
  [emit]
)
```

**Event Emitted**: `driver:update_location`

**Payload**:
```json
{
  "orderId": 123,
  "lat": -7.6234,
  "lng": 110.8234
}
```

### 3.3 Backend Reception & Broadcast

**File**: `backend/src/socket/handlers.js` - Lines 112-131

```javascript
socket.on(socketEvents.CLIENT.UPDATE_LOCATION, async (data) => {
  const { orderId, lat, lng } = data
  if (!orderId || lat == null || lng == null) return

  try {
    // 1. Persist to database
    await db.query(
      'INSERT INTO driver_locations (driver_id, order_id, lat, lng) VALUES (?, ?, ?, ?)',
      [socket.userId, orderId, lat, lng]
    )

    // 2. Broadcast to all users in order room
    socketService.emitToOrder(orderId, socketEvents.SERVER.DRIVER_LOCATION_UPDATED, {
      orderId,
      driverId: socket.userId,
      lat,
      lng,
      timestamp: new Date().toISOString(),
    })
  } catch (err) {
    console.error('Error saving driver location:', err)
  }
})
```

**What happens**:
1. Received event: `driver:update_location`
2. **Saves to DB**: `driver_locations` table with driver_id, order_id, lat, lng
3. **Broadcasts**: Emits `driver:location_updated` to all in room `order_${orderId}`

### 3.4 User-Side Reception

**File**: `src/views/user/TrackingPetugas.js` - Lines 563-572

```javascript
useEffect(() => {
  if (!subscribe || !currentOrderId) return
  
  const unsubscribe = subscribe('driver:location_updated', (data) => {
    // Receive from backend
    if (!data?.orderId || String(data.orderId) !== String(currentOrderId)) return
    
    if (data.lat != null && data.lng != null) {
      // Update state with new driver location
      setDriverLocation([Number(data.lat), Number(data.lng)])
    }
  })
  
  return () => unsubscribe && unsubscribe()
}, [subscribe, currentOrderId])
```

**Flow**:
1. User is on TrackingPetugas component
2. Subscribed to `driver:location_updated` event
3. **Immediately updates** driver marker on map
4. Triggers route recalculation if needed

---

## 🔄 4. HTTP API TRACKING FALLBACK

### 4.1 Polling-Based Tracking

Even without real-time Socket events, tracking continues via **3-second HTTP polling**:

**File**: `src/views/user/TrackingPetugas.js` - Lines 530-548

```javascript
const fetchTracking = useCallback(async () => {
  if (!currentOrderId) return
  try {
    const response = await locationAPI.getTracking(currentOrderId)
    const data = response.data

    // Support two API response formats:
    // Format 1: Modern API with explicit fields
    if (data.driver_lat != null && data.driver_lng != null) {
      latestDriver = [Number(data.driver_lat), Number(data.driver_lng)]
    }
    // Format 2: Legacy - locations array
    else if (Array.isArray(data.locations) && data.locations.length > 0) {
      const lastLocation = data.locations[data.locations.length - 1]
      if (lastLocation?.lat != null && lastLocation?.lng != null) {
        latestDriver = [Number(lastLocation.lat), Number(lastLocation.lng)]
      }
    }
    // Format 3: Direct row from driver_locations table
    else if (data.lat != null && data.lng != null) {
      latestDriver = [Number(data.lat), Number(data.lng)]
    }

    if (latestDriver) setDriverLocation(latestDriver)

    // Also update user location, address, driver info, order status
    if (data.user_lat) setUserLocation([...])
    if (data.address) setUserAddress(data.address)
    if (data.driver_name) setDriverInfo({name: data.driver_name, ...})
    if (data.order_status) setOrderStatus(data.order_status)
  } catch (err) {
    console.error("Error fetching tracking:", err)
  } finally {
    setLoading(false)
  }
}, [currentOrderId])

// Polling every 3 seconds
useEffect(() => {
  if (!currentOrderId) {
    history.push("/user/dashboard")
    return
  }
  fetchTracking()
  const interval = setInterval(fetchTracking, 3000)  // 3 second poll
  return () => clearInterval(interval)
}, [currentOrderId, history, fetchTracking])
```

### 4.2 API Endpoint: `/tracking/{orderId}`

**Method**: GET  
**Authentication**: Bearer Token  
**Path Parameter**: `orderId` (number)

**Response Format** (Modern):
```json
{
  "status": "success",
  "driver_lat": -7.6234,
  "driver_lng": 110.8234,
  "user_lat": -7.5234,
  "user_lng": 110.9234,
  "address": "Jl. Raya Madiun No.123",
  "driver_id": 5,
  "driver_name": "Budi Hartono",
  "driver_phone": "081234567890",
  "order_status": "on_the_way",
  "sampah_data": {
    "organik": {
      "1": { "berat": 2.5, "harga": 1500 }
    },
    "anorganik": { ... }
  },
  "total_berat": 5.0,
  "total_harga": 12500
}
```

---

## 🛣️ 5. ROUTE CALCULATION & DISPLAY

### 5.1 Routing Engine

**Service**: Open Source Routing Machine (OSRM)  
**URL**: `https://router.project-osrm.org`

### 5.2 Route Calculation Process

**File**: `src/views/user/TrackingPetugas.js` - Lines 376-461

```javascript
const fetchRouteManaged = useCallback(async (from, to) => {
  if (!from || !to) return

  // 1. Check cache (60 second TTL)
  const key = coordKey(from, to)
  const cache = routeCacheRef.current.get(key)
  if (cache && now - cache.ts < 60000) {
    setRouteGeoJson(cache.geo)
    return
  }

  // 2. Check if already fetching + min interval check (5s)
  if (inFlightRef.current && now - lastRouteTimeRef.current < 5000) return

  // 3. Check if significant movement occurred (>50m threshold)
  const distMoved = lastFetchedPositionsRef.current
    ? Math.max(
        haversine(lastFetchedPositionsRef.current.from, from),
        haversine(lastFetchedPositionsRef.current.to, to)
      )
    : Infinity
  if (distMoved < 50 && now - lastRouteTimeRef.current < 5000) return

  try {
    // 4. Snap points to road network (avoid off-road coordinates)
    const [sFromLat, sFromLng] = await snapPoint(from[0], from[1], signal)
    const [sToLat, sToLng] = await snapPoint(to[0], to[1], signal)

    // 5. Request route from OSRM
    const url = `https://router.project-osrm.org/route/v1/driving/${sFromLng},${sFromLat};${sToLng},${sToLat}?overview=full&geometries=geojson&steps=true&alternatives=true`
    const resp = await fetch(url, { signal })
    const data = await resp.json()

    // 6. Select best route from alternatives
    if (data?.routes?.length > 0) {
      const best = chooseBestRoute(data.routes)  // By duration + steps
      if (best?.geometry) {
        setRouteGeoJson(best.geometry)
        routeCacheRef.current.set(key, { geo: best.geometry, ts: Date.now() })
      }
    } else {
      // Fallback: straight line
      setRouteGeoJson({
        type: "LineString",
        coordinates: [[from[1], from[0]], [to[1], to[0]]]
      })
    }
    lastFetchedPositionsRef.current = { from, to }
  } catch (err) {
    if (err.name === "AbortError") return
    // Fallback: straight line
    setRouteGeoJson({
      type: "LineString",
      coordinates: [[from[1], from[0]], [to[1], to[0]]]
    })
  } finally {
    inFlightRef.current = false
  }
}, [])
```

### 5.3 Route Optimization

**Smart Features**:
1. **Snap to Roads**: Prevents off-road coordinates
2. **Haversine Distance Check**: Only recalculates if moved > 50m
3. **Interval Throttling**: Min 5 seconds between requests
4. **Route Caching**: 60-second TTL to avoid duplicate requests
5. **Alternative Routes**: Requests alternatives, selects best by duration + step count
6. **Fallback**: Straight line if OSRM unavailable

### 5.4 Map Display

**File**: `src/views/user/TrackingPetugas.js` - Uses Leaflet GeoJSON

```javascript
<MapContainer>
  <TileLayer {...getTileLayerProps()} />
  
  {/* Route polyline */}
  {routeGeoJson && (
    <GeoJSON data={routeGeoJson} style={{ color: '#22c55e', weight: 3 }} />
  )}
  
  {/* Driver marker */}
  {driverSmoothPos && (
    <Marker position={driverSmoothPos} icon={redIcon}>
      <Popup>Driver: {petugasProfile?.name}</Popup>
    </Marker>
  )}
  
  {/* User marker */}
  {userSmoothPos && (
    <Marker position={userSmoothPos} icon={blueIcon}>
      <Popup>Your Location</Popup>
    </Marker>
  )}
  
  {/* Fit bounds on route */}
  <FitRouteBounds
    userLocation={userSmoothPos}
    driverLocation={driverSmoothPos}
    routeGeoJson={routeGeoJson}
  />
</MapContainer>
```

---

## 🔄 6. ORDER STATUS EVENTS

### 6.1 Status Change Subscription

**File**: `src/views/user/TrackingPetugas.js` - Lines 573-638

```javascript
useEffect(() => {
  if (!subscribe || !currentOrderId) return

  const extractOrderStatus = (data) => {
    if (!data) return null
    if (data.order?.status) return data.order.status
    if (data.status) return data.status
    if (data.order_status) return data.order_status
    return null
  }

  const handleOrderEvent = async (data, eventName) => {
    if (!data) return
    const eventOrderId = data.order?.id || data.orderId
    if (eventOrderId && String(eventOrderId) !== String(currentOrderId)) return

    // Map event to status
    const nextStatus = extractOrderStatus(data) || {
      'order:accepted': 'on_the_way',
      'order:on_the_way': 'on_the_way',
      'order:arrived': 'arrived',
      'order:completed': 'completed',
    }[eventName]

    if (nextStatus) {
      if (nextStatus === 'arrived' && orderStatusRef.current !== 'arrived') {
        setArrivedNotification(true)  // Show notification
      }
      orderStatusRef.current = nextStatus
      setOrderStatus(nextStatus)
    }

    // Extract waste data if provided
    if (data.order?.sampah_data) {
      setSampahData(data.order.sampah_data)
      setTotalBerat(data.order.total_berat)
      setTotalHarga(data.order.total_harga)
    }
  }

  // Subscribe to all order events
  const events = [
    'order:state',
    'order:status_changed',
    'order:accepted',
    'order:on_the_way',
    'order:arrived',
    'order:completed',
  ]

  const unsubs = events.map((eventName) =>
    subscribe(eventName, (data) => handleOrderEvent(data, eventName))
  ).filter(Boolean)

  return () => unsubs.forEach((unsubscribe) => unsubscribe?.())
}, [subscribe, currentOrderId, fetchTracking])
```

### 6.2 Status Flow

```
pending 
  → searching_driver (SEARCHING)
  → assigned (DRIVER_ACCEPTED)
  → on_the_way (DRIVER_ARRIVING)
  → arrived (PICKUP)
  → completed (COMPLETED)
```

**Status config UI labels**:
- **assigned**: "Petugas Ditugaskan" 🎯
- **on_the_way**: "Menuju Lokasi Anda" 🚗
- **arrived**: "Petugas Sudah Tiba" 📍
- **completed**: "Penjemputan Selesai" ✅

---

## 📊 7. DATA STRUCTURES

### 7.1 Order Object

```typescript
interface Order {
  id: number
  user_id: number
  driver_id?: number
  status: 'pending' | 'assigned' | 'on_the_way' | 'arrived' | 'completed'
  user_lat: number
  user_lng: number
  driver_lat?: number
  driver_lng?: number
  address: string
  jenis_sampah?: string
  created_at: string
  updated_at: string
  sampah_data?: SampahData
  total_berat?: number
  total_harga?: number
}
```

### 7.2 Driver Location Data

```typescript
interface DriverLocation {
  orderId: number
  driverId: number
  lat: number
  lng: number
  timestamp: string  // ISO 8601
}
```

### 7.3 Sampah Data

```typescript
interface SampahData {
  organik: {
    [itemId: number]: {
      berat: number     // kg
      harga: number     // per kg
    }
  }
  anorganik: { ... }
  lainnya: { ... }
}
```

---

## ⚠️ 8. ERROR HANDLING & FALLBACKS

### 8.1 Geolocation Errors (Driver)

```javascript
(err) => {
  console.error("Geolocation error:", err)
  // Graceful degradation: continue with map view
  // User can manually refresh tracking
}

// Possible errors:
// - PERMISSION_DENIED: User blocked GPS
// - POSITION_UNAVAILABLE: GPS hardware issue
// - TIMEOUT: GPS took > 15 seconds
```

### 8.2 Socket Connection Loss

```javascript
// Auto-reconnect configured:
reconnection: true
reconnectionDelay: 1000        // Start with 1s
reconnectionDelayMax: 5000     // Max 5s backoff
reconnectionAttempts: 5        // Try 5 times

// Fallback: Polling continues every 3s
// User still sees updated location via HTTP API
```

### 8.3 OSRM Route Unavailable

```javascript
// If OSRM request fails → straight line fallback
setRouteGeoJson({
  type: "LineString",
  coordinates: [[from[1], from[0]], [to[1], to[0]]]
})
```

### 8.4 API Call Failures

```javascript
// TrackingPetugas handles gracefully:
try {
  const response = await locationAPI.getTracking(currentOrderId)
  // ... process response
} catch (err) {
  console.error("Error fetching tracking:", err)
  // Continues: next poll in 3s
}
```

---

## 📌 9. MARKER ANIMATION

### 9.1 Smooth Position Interpolation

**File**: `src/views/user/TrackingPetugas.js` - Lines 656-672

```javascript
// 800ms smooth transition when location changes
useEffect(() => {
  let rafId = null
  let start = null
  const DURATION = 800  // milliseconds

  const from = driverSmoothPos || driverLocation || null
  const to = driverLocation

  if (!to) return
  if (!from) {
    setDriverSmoothPos(to)
    return
  }

  const step = (ts) => {
    if (!start) start = ts
    const t = Math.min(1, (ts - start) / DURATION)
    
    // Linear interpolation
    setDriverSmoothPos([
      from[0] + (to[0] - from[0]) * t,
      from[1] + (to[1] - from[1]) * t,
    ])
    
    if (t < 1) rafId = requestAnimationFrame(step)
  }

  rafId = requestAnimationFrame(step)
  return () => {
    if (rafId) cancelAnimationFrame(rafId)
  }
}, [driverLocation])
```

**Result**: Smooth marker movement instead of jumping

---

## 🎯 10. COMPLETE TRACKING FLOW - STEP BY STEP

### User Perspective: Tracking a Driver

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER TRACKING FLOW                           │
└─────────────────────────────────────────────────────────────────┘

1. USER OPENS TRACKING PAGE
   └─> TrackingPetugas component mounts
   └─> Session storage has current_order_id
   └─> Socket joins order room: emit('join:order_room', {orderId})

2. BACKEND RECEIVES JOIN
   └─> Stores user in room: order_${orderId}
   └─> Emits ORDER_STATE with current order data
   └─> User receives: last known driver location

3. REAL-TIME UPDATES (Socket.io)
   
   DRIVER SIDE:
   └─> GPS updates: navigator.geolocation.watchPosition()
   └─> If moved > 15m:
       └─> Updates local state
       └─> Emits: emit('driver:update_location', {orderId, lat, lng})
       └─> Sends: POST /driver/location (HTTP)

   BACKEND RECEIVES:
   └─> Stores: INSERT driver_locations table
   └─> Broadcasts: emitToOrder(orderId, 'driver:location_updated', {...})

   USER RECEIVES:
   └─> subscribe('driver:location_updated', (data) => {
         setDriverLocation([data.lat, data.lng])
       })
   └─> Map updates with new marker position
   └─> Route recalculated (if moved > 50m)
   └─> Smooth 800ms animation to new position

4. POLLING FALLBACK (every 3 seconds)
   └─> GET /tracking/${orderId}
   └─> Receives: driver_lat, driver_lng, user_lat, user_lng, etc
   └─> Updates all tracking data
   └─> Ensures continuity if Socket disconnects

5. STATUS UPDATES (Socket.io)
   └─> Driver marks "arrived"
   └─> Backend broadcasts: emit('order:arrived', {...})
   └─> User receives event → Shows notification
   └─> Status stepper updates (3 of 4 steps complete)

6. COMPLETION
   └─> Driver submits waste data
   └─> emit('order:completed', {sampah_data, total_berat, total_harga})
   └─> User receives → Shows notification → Redirects after 2.5s
```

### Driver Perspective: Tracking to User

```
┌─────────────────────────────────────────────────────────────────┐
│                   DRIVER TRACKING FLOW                          │
└─────────────────────────────────────────────────────────────────┘

1. DRIVER ACCEPTS ORDER
   └─> OrderDetail → handleAcceptOrder()
   └─> Redirects to TrackingUser page
   └─> Joins order room via Socket

2. GPS TRACKING LOOP (continuous)
   └─> navigator.geolocation.watchPosition({
         enableHighAccuracy: true,
         maximumAge: 0,
         timeout: 15000
       })
   └─> Fires whenever position changes

3. FOR EACH GPS UPDATE
   └─> Calculate distance from last known position (haversine)
   └─> If distance > 15m:
       ├─> Update state: setDriverLocation([lat, lng])
       ├─> Send HTTP: POST /driver/location
       │   └─> Persists to driver_locations table
       └─> Emit Socket: updateDriverLocation(orderId, lat, lng)
           └─> Sends: driver:update_location event

4. ROUTE TO USER
   └─> Have: user_location (from order data)
   └─> Have: driver_location (from GPS)
   └─> If either moved > 50m in last 5 seconds:
       ├─> Fetch route from OSRM
       ├─> Snap points to road network
       ├─> Get multiple route options
       ├─> Select best by (duration + steps)
       └─> Display on map with green polyline

5. STATUS UPDATES
   └─> Driver marks: "I've arrived" → status=arrived
   └─> Backend broadcasts to user → Shows notification

6. WASTE SUBMISSION
   └─> Driver enters waste data (weight per type)
   └─> Calculates total: Rp 12,500
   └─> Submits to admin
   └─> emit('order:completed', {...})
   └─> User sees: "Pickup completed"
```

---

## 🔐 11. SECURITY & AUTHENTICATION

### 11.1 Socket Authentication

```javascript
// SocketContext.js - Every socket connects with JWT
const newSocket = io(socketUrl, {
  auth: {
    token: auth.token,  // JWT from localStorage
  },
  // ...
})

// Backend verifies token before allowing events
```

### 11.2 API Authentication

```javascript
// api.js - All endpoints require Bearer token
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})
```

### 11.3 Room Isolation

- Users can **only** subscribe to their own order rooms
- Backend validates `orderId` matches user's actual orders
- Driver location only broadcast to users in same order room

---

## 🐛 12. DEBUGGING TIPS

### Enable Verbose Logging

Look for console logs prefixed with:
- `[Socket]` - Socket.io events
- `[TRACKING PETUGAS]` - User tracking
- `[DRIVER LOCATION UPDATE]` - GPS events
- `[ROUTE FETCH]` - Route calculations
- `[SOCKET EMIT]` - Event emissions

### Check Socket Status

```javascript
// In browser console
useSocket().isConnected  // true/false
useSocket().socket.id    // socket identifier
```

### Monitor API Calls

```
GET /tracking/123
POST /driver/location
GET /harga/organik
```

### Performance Check

- Socket updates should be < 100ms latency
- Polling every 3 seconds provides fallback
- Map renders should be smooth (60fps)

---

## 📋 SUMMARY TABLE

| Aspect | Technology | Update Method | Frequency |
|--------|-----------|---------------|-----------|
| **Driver Location** | GPS Geolocation | Socket + HTTP | On GPS change (>15m) |
| **Route Display** | OSRM Routing | HTTP | On location update (>50m) |
| **Order Status** | Socket Events | WebSocket | Event-driven |
| **Fallback Tracking** | HTTP Polling | REST API | Every 3 seconds |
| **Map Rendering** | Leaflet + React | Browser Rendering | Real-time |
| **Marker Animation** | RequestAnimationFrame | Browser Animation | 800ms duration |

---

## 📚 KEY FILES REFERENCE

```
pundesari/src/
├── views/
│   ├── user/
│   │   └── TrackingPetugas.js          ← User tracking driver
│   └── driver/
│       ├── TrackingUser.js              ← Driver tracking to user
│       └── OrderDetail.js               ← Order preview before accepting
├── components/
│   └── SearchingDriverGuard.jsx
├── context/
│   ├── SocketContext.js                 ← Real-time Socket.io
│   ├── OrderContext.js                  ← Order state management
│   └── AuthContext.js                   ← Authentication
├── services/
│   └── api.js                           ← API endpoints including locationAPI
└── config/
    └── mapConfig.js                     ← Map settings & CSS

backend/src/
├── socket/
│   └── handlers.js                      ← Socket event listeners
├── constants/
│   └── socketEvents.js                  ← Event definitions
├── services/
│   └── socketService.js                 ← Event broadcasting
├── controllers/
│   └── orderController.js               ← Order operations
└── db.js                                ← Database initialization
```

---

**Document End**  
Last Updated: July 6, 2026
