# K-TRASH Tracking API & Socket.io Reference

**Quick Reference for API Endpoints & Socket Events**

---

## HTTP API ENDPOINTS

### 1. GET /tracking/{orderId}
Get current tracking state for an order (used by user tracking driver)

**URL**: `GET /api/tracking/{orderId}`  
**Authentication**: Bearer Token (JWT)  
**Path Parameters**:
- `orderId` (number): Order ID to track

**Request Example**:
```
GET /tracking/123
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (200 OK)**:
```json
{
  "status": "success",
  "driver_lat": -7.623456,
  "driver_lng": 110.823456,
  "user_lat": -7.523456,
  "user_lng": 110.923456,
  "address": "Jl. Raya Madiun No. 123",
  "driver_id": 5,
  "driver_name": "Budi Hartono",
  "driver_phone": "081234567890",
  "order_status": "on_the_way",
  "order_id": 123,
  "created_at": "2024-07-06T10:00:00Z",
  "updated_at": "2024-07-06T10:05:30Z",
  "sampah_data": {
    "organik": {
      "1": { "berat": 2.5, "harga": 1500 }
    },
    "anorganik": {
      "2": { "berat": 1.0, "harga": 3000 }
    }
  },
  "total_berat": 3.5,
  "total_harga": 6750
}
```

**Error Response (404)**:
```json
{
  "status": "error",
  "message": "Order not found"
}
```

**Frontend Usage** (TrackingPetugas.js):
```javascript
const response = await locationAPI.getTracking(currentOrderId)
const data = response.data
setDriverLocation([Number(data.driver_lat), Number(data.driver_lng)])
setUserLocation([Number(data.user_lat), Number(data.user_lng)])
setOrderStatus(data.order_status)
```

**Polling Interval**: Every 3 seconds

---

### 2. POST /driver/location
Send driver's current GPS location (called by driver while on TrackingUser page)

**URL**: `POST /driver/location`  
**Authentication**: Bearer Token  
**Content-Type**: application/json

**Request Body**:
```json
{
  "driver_id": 5,
  "order_id": 123,
  "lat": -7.623456,
  "lng": 110.823456
}
```

**Response (200 OK)**:
```json
{
  "status": "success",
  "message": "Location saved"
}
```

**Response (400 Bad Request)**:
```json
{
  "status": "error",
  "message": "Invalid request parameters"
}
```

**Frontend Usage** (TrackingUser.js):
```javascript
const sendDriverLocation = useCallback(async (lat, lng) => {
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

// Called from geolocation watcher:
navigator.geolocation.watchPosition(
  (pos) => {
    if (haversine(prev, current) > 15) {  // >15m threshold
      sendDriverLocation(lat, lng)  // Also via Socket
    }
  }
)
```

**Triggered By**: GPS watchPosition when moved >15 meters

---

### 3. GET /orders/{orderId}
Get full order details

**URL**: `GET /orders/{orderId}`  
**Authentication**: Bearer Token

**Response**:
```json
{
  "id": 123,
  "user_id": 10,
  "driver_id": 5,
  "status": "on_the_way",
  "user_lat": -7.523456,
  "user_lng": 110.923456,
  "driver_lat": -7.623456,
  "driver_lng": 110.823456,
  "address": "Jl. Raya Madiun No. 123",
  "jenis_sampah": "Organik, Anorganik",
  "created_at": "2024-07-06T10:00:00Z",
  "updated_at": "2024-07-06T10:05:30Z"
}
```

---

### 4. PATCH /orders/status/{orderId}
Update order status (driver changing status)

**URL**: `PATCH /orders/status/{orderId}`  
**Authentication**: Bearer Token

**Request Body**:
```json
{
  "driver_id": 5,
  "status": "arrived"
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Order status updated"
}
```

---

## SOCKET.IO EVENTS

### Client-to-Server Events

#### 1. `join:order_room`
Subscribe to real-time updates for a specific order

**Emitted By**: User or Driver on entering tracking page  
**Payload**:
```javascript
{ orderId: 123 }
```

**Usage** (TrackingPetugas.js):
```javascript
const { joinOrderRoom } = useSocket()

useEffect(() => {
  if (!currentOrderId || !isConnected) return
  joinOrderRoom(currentOrderId)
  return () => leaveOrderRoom(currentOrderId)
}, [currentOrderId, isConnected])
```

**Backend Effect**:
- Adds user to Socket.io room: `order_${orderId}`
- Immediately sends back current order state via `order:state` event

---

#### 2. `leave:order_room`
Unsubscribe from order room (cleanup)

**Emitted By**: User or Driver on page exit  
**Payload**:
```javascript
{ orderId: 123 }
```

**Usage**:
```javascript
useEffect(() => {
  return () => {
    leaveOrderRoom(currentOrderId)  // Cleanup on unmount
  }
}, [currentOrderId])
```

---

#### 3. `driver:update_location` ⭐ CRITICAL
Send GPS location to all users in order room

**Emitted By**: Driver (TrackingUser.js) via `updateDriverLocation()`  
**Frequency**: ~1 per second (when >15m movement detected)  
**Payload**:
```javascript
{
  orderId: 123,
  lat: -7.623456,
  lng: 110.823456
}
```

**Usage** (TrackingUser.js):
```javascript
navigator.geolocation.watchPosition((pos) => {
  const lat = pos.coords.latitude
  const lng = pos.coords.longitude
  
  // Only if moved >15 meters
  if (haversine(prev, [lat, lng]) > 15) {
    // Method 1: Socket event
    updateDriverLocation(orderId, lat, lng)
    
    // Method 2: HTTP API (for persistence)
    sendDriverLocation(lat, lng)
  }
})
```

**Backend Processing** (handlers.js):
```javascript
socket.on(socketEvents.CLIENT.UPDATE_LOCATION, async (data) => {
  // 1. Save to database
  await db.query(
    'INSERT INTO driver_locations (driver_id, order_id, lat, lng) VALUES (?, ?, ?, ?)',
    [socket.userId, data.orderId, data.lat, data.lng]
  )

  // 2. Broadcast to room
  socketService.emitToOrder(data.orderId, 'driver:location_updated', {
    orderId: data.orderId,
    driverId: socket.userId,
    lat: data.lat,
    lng: data.lng,
    timestamp: new Date().toISOString(),
  })
})
```

---

### Server-to-Client Events

#### 1. `auth:success`
Confirmation that socket authentication succeeded

**Sent By**: Backend on connection  
**Payload**:
```javascript
{
  userId: 10,
  userRole: "user",
  userEmail: "user@example.com",
  timestamp: "2024-07-06T10:00:00Z"
}
```

**Frontend Handling** (SocketContext.js):
```javascript
socket.on('auth:success', (data) => {
  console.log('✅ Socket authenticated:', data)
})
```

---

#### 2. `auth:error`
Authentication failed

**Sent By**: Backend on connection error  
**Payload**:
```javascript
{ error: "Invalid token" }
```

**Frontend Handling**:
```javascript
socket.on('auth:error', (error) => {
  console.error('🔴 Socket auth error:', error)
  socket.disconnect()
})
```

---

#### 3. `order:state` ⭐ CRITICAL
Current order state (sent on JOIN_ORDER_ROOM or on connection)

**Sent By**: Backend  
**Trigger**: User/Driver joins order room  
**Payload**:
```javascript
{
  order: {
    id: 123,
    user_id: 10,
    driver_id: 5,
    status: "on_the_way",
    user_lat: -7.523456,
    user_lng: 110.923456,
    driver_lat: -7.623456,
    driver_lng: 110.823456,
    address: "Jl. Raya Madiun No. 123",
    created_at: "2024-07-06T10:00:00Z"
  }
}
```

**Frontend Usage** (TrackingPetugas.js):
```javascript
const unsubscribe = subscribe('order:state', (data) => {
  if (!data?.order) return
  const order = data.order
  setDriverLocation([order.driver_lat, order.driver_lng])
  setUserLocation([order.user_lat, order.user_lng])
  setOrderStatus(order.status)
})
```

---

#### 4. `driver:location_updated` ⭐ REAL-TIME TRACKING
Driver location changed (broadcast to order room)

**Sent By**: Backend (in response to driver's `driver:update_location`)  
**Frequency**: ~1 per second (from driver)  
**Received By**: All users in `order_${orderId}` room  
**Payload**:
```javascript
{
  orderId: 123,
  driverId: 5,
  lat: -7.623456,
  lng: 110.823456,
  timestamp: "2024-07-06T10:05:45Z"
}
```

**Frontend Usage** (TrackingPetugas.js):
```javascript
useEffect(() => {
  if (!subscribe || !currentOrderId) return
  
  const unsubscribe = subscribe('driver:location_updated', (data) => {
    if (!data?.orderId || String(data.orderId) !== String(currentOrderId)) return
    
    if (data.lat != null && data.lng != null) {
      setDriverLocation([Number(data.lat), Number(data.lng)])
      // Triggers route recalculation via useEffect
    }
  })
  
  return () => unsubscribe?.()
}, [subscribe, currentOrderId])
```

**Latency**: ~40-80ms from driver GPS to user's map update

---

#### 5. `order:status_changed`
Order status changed (e.g., from "on_the_way" to "arrived")

**Sent By**: Backend (when driver updates status via API)  
**Broadcast To**: All in order room  
**Payload**:
```javascript
{
  order: {
    id: 123,
    status: "arrived",
    // ... rest of order object
  },
  status: "arrived"
}
```

**Frontend Usage** (TrackingPetugas.js):
```javascript
const unsubscribe = subscribe('order:status_changed', (data) => {
  const newStatus = data.order?.status || data.status
  if (newStatus === 'arrived') {
    setArrivedNotification(true)  // Show banner
  }
  setOrderStatus(newStatus)
})
```

---

#### 6. `order:accepted`, `order:on_the_way`, `order:arrived`, `order:completed`
Status-specific events (alternative to `order:status_changed`)

**All follow similar pattern**:

**`order:arrived`** payload:
```javascript
{
  order: { id: 123, status: "arrived", ... }
}
```

**Frontend subscribes to all**:
```javascript
const events = [
  'order:state',
  'order:status_changed',
  'order:accepted',
  'order:on_the_way',
  'order:arrived',
  'order:completed',
]

events.forEach(eventName => {
  subscribe(eventName, (data) => handleOrderEvent(data, eventName))
})
```

---

#### 7. `notification:new`
General notification (user feedback)

**Sent By**: Backend  
**Payload**:
```javascript
{
  id: 1234567890,
  title: "Petugas Sudah Tiba",
  message: "Petugas sedang menunggu dan memproses sampahmu",
  type: "info",  // or "success", "warning", "error"
  timestamp: "2024-07-06T10:05:45Z"
}
```

---

#### 8. `error:occurred`
Error event from backend

**Sent By**: Backend  
**Payload**:
```javascript
{
  error: "Internal server error",
  code: "500"
}
```

---

## TRACKING FLOW EXAMPLES

### Example 1: User Tracking Driver (Complete Flow)

```javascript
// === USER BROWSER ===
// File: TrackingPetugas.js

// 1. Component mounts
useEffect(() => {
  const orderId = sessionStorage.getItem('current_order_id')  // 123
  
  // 2. Join Socket room
  joinOrderRoom(orderId)
  
  // 3. Subscribe to location updates
  subscribe('driver:location_updated', (data) => {
    setDriverLocation([data.lat, data.lng])
  })
  
  // 4. Start polling fallback
  const interval = setInterval(() => {
    locationAPI.getTracking(orderId)
      .then(res => setDriverLocation([res.data.driver_lat, res.data.driver_lng]))
  }, 3000)
  
  return () => {
    clearInterval(interval)
    leaveOrderRoom(orderId)
  }
}, [])

// 5. Map displays driver marker
// 6. Renders route from driver to user
// 7. Shows "Driver is on the way" status
```

**What happens on driver end**:
```javascript
// === DRIVER BROWSER ===
// File: TrackingUser.js

navigator.geolocation.watchPosition((pos) => {
  const [lat, lng] = [pos.coords.latitude, pos.coords.longitude]
  
  if (haversine(lastPos, [lat, lng]) > 15) {
    // Send via Socket
    updateDriverLocation(orderId, lat, lng)
    
    // Send via HTTP
    locationAPI.sendDriverLocation({driver_id, order_id, lat, lng})
  }
})
```

**Backend processes**:
```javascript
// === BACKEND ===
socket.on('driver:update_location', async (data) => {
  // Save to DB
  db.query(
    'INSERT INTO driver_locations (driver_id, order_id, lat, lng)',
    [5, 123, -7.62, 110.82]
  )
  
  // Broadcast to room order_123
  emitToOrder(123, 'driver:location_updated', {
    orderId: 123,
    driverId: 5,
    lat: -7.62,
    lng: 110.82,
    timestamp: '2024-07-06T10:05:45Z'
  })
})
```

**User's map updates**:
```
[~40-80ms later]
subscribe('driver:location_updated') fires
→ setDriverLocation([−7.62, 110.82])
→ Re-render map with new marker
→ Smooth 800ms animation to position
→ Route recalculates if >50m moved
```

---

### Example 2: Driver Submits Waste Data

```javascript
// === DRIVER ===
// TrackingUser.js

const handleSubmit = async () => {
  setSubmitting(true)
  try {
    const response = await ordersAPI.updateOrderStatus(orderId, {
      driver_id: driverId,
      status: 'completed',
      sampah_data: {
        organik: { 1: {berat: 2.5, harga: 1500} },
        anorganik: { 2: {berat: 1.0, harga: 3000} }
      },
      total_berat: 3.5,
      total_harga: 6750
    })
    
    if (response.data.status === 'success') {
      setOrderStatus('completed')
      // Emit completion event
      emit('order:completed', {
        orderId,
        sampah_data: {...},
        total_berat: 3.5,
        total_harga: 6750
      })
    }
  } finally {
    setSubmitting(false)
  }
}
```

**Backend updates order**:
```javascript
router.patch('/orders/status/:orderId', async (req, res) => {
  const { status, sampah_data, total_berat, total_harga } = req.body
  
  // Update orders table
  db.query(
    'UPDATE orders SET status = ?, sampah_data = ? WHERE id = ?',
    [status, JSON.stringify(sampah_data), req.params.orderId]
  )
  
  // Broadcast to order room
  socketService.emitToOrder(req.params.orderId, 'order:completed', {
    order: { ...orderData, status: 'completed', sampah_data },
    sampah_data,
    total_berat,
    total_harga
  })
})
```

**User receives notification**:
```javascript
// TrackingPetugas.js
subscribe('order:completed', (data) => {
  setOrderStatus('completed')
  setCompletedNotification(true)
  
  // Show success banner
  // Auto-redirect after 2.5 seconds
  setTimeout(() => history.push('/user/dashboard'), 2500)
})
```

---

## ERROR RESPONSES

### Network Error Handling

**API Call Fails**:
```javascript
try {
  const response = await locationAPI.getTracking(orderId)
} catch (err) {
  console.error("Error fetching tracking:", err)
  // Continue: Will retry in 3 seconds
  // User sees last known position
}
```

**Socket Disconnects**:
```javascript
socket.on('disconnect', (reason) => {
  console.warn('Socket disconnected:', reason)
  setIsConnected(false)
  // Polling continues every 3 seconds
  // Auto-reconnect with exponential backoff
})
```

**GPS Permission Denied**:
```javascript
navigator.geolocation.watchPosition(
  (pos) => { /* ... */ },
  (err) => {
    if (err.code === 1) {  // PERMISSION_DENIED
      console.error("GPS permission denied")
      // Driver can still see user location
      // Just no GPS updates sent
    }
  }
)
```

---

## DEBUGGING CHECKLIST

- [ ] Check Socket connection: `useSocket().isConnected`
- [ ] Verify JWT token: `localStorage.getItem('token')`
- [ ] Check order ID: `sessionStorage.getItem('current_order_id')`
- [ ] Monitor network tab: Look for `/tracking/` calls every 3s
- [ ] Check console logs for `[Socket]` and `[TRACKING]` prefixes
- [ ] Verify GPS enabled in browser permissions
- [ ] Test OSRM route: `https://router.project-osrm.org/route/v1/driving/110.8,−7.6;110.9,−7.5`
- [ ] Check database: `SELECT * FROM driver_locations WHERE order_id = 123`

---

**End of Reference**
