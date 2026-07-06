# Flutter API Endpoints Analysis

## Base URL Configuration
```
Production: https://api-ktrashuns.tifpsdku.com
Development: http://localhost:5000
Android Emulator: http://10.0.2.2:5000
Override: Can be set via --dart-define=BACKEND_URL=<url>
```

---

## 1. TRACKING_PAGE.DART
File: [lib/features/tracking/pages/tracking_page.dart](lib/features/tracking/pages/tracking_page.dart)

### API Calls Made:

#### 1.1 Get Tracking Data
- **HTTP Method:** GET
- **Endpoint:** `/tracking/{orderId}`
- **Full URL:** `$BACKEND_URL/tracking/{orderId}`
- **Service:** TrackingService.getTracking(int orderId)
- **Called From:** `_fetchTracking()` - Polling every 3 seconds
- **Request Headers:**
  - Authorization: Bearer $token (via ApiClient interceptor)
  - Content-Type: application/json
- **Request Parameters:**
  - orderId: int (from widget.orderId)
- **Expected Response Format:**
  ```json
  {
    "driver_lat": double,
    "driver_lng": double,
    "user_lat": double,
    "user_lng": double,
    "order_status": string,  // or "status"
    "status": string,
    "address": string,
    "driver_name": string (optional),
    "driver_id": int or string (optional),
    "driver_phone": string (optional),
    "sampah_data": object (optional),
    "total_berat": double or string (optional),
    "total_harga": double or string (optional),
    "data": object (response can be wrapped in "data" key)
  }
  ```
- **Response Handling:**
  - If response has "data" key, extracts data from it
  - Normalizes all numeric values (lat/lng/berat/harga)
  - Maps driver_id or driver field
  - Maps order_status or status field
- **Error Handling:**
  - DioException handling with timeout detection
  - Sets error message in UI state
  - Continues polling even on errors
- **Additional Calls:**
  - OSRM (external): `/nearest/v1/driving/{lng},{lat}` (road snapping)
  - OSRM (external): `/route/v1/driving/{...}` (route calculation)

---

## 2. DRIVER_TRACKING_PAGE.DART
File: [lib/features/tracking/pages/driver_tracking_page.dart](lib/features/tracking/pages/driver_tracking_page.dart)

### API Calls Made:

#### 2.1 Get Tracking Data (Same as tracking_page.dart)
- **HTTP Method:** GET
- **Endpoint:** `/tracking/{orderId}`
- **Service:** TrackingService.getTracking(int orderId)
- **Called From:** `_fetchTracking()` - Polling every 3 seconds
- **Same response format as 1.1**
- **Key Differences:**
  - Driver can update their own location continuously
  - Polling updates driver position from device GPS

#### 2.2 Send Driver Location (Real-time tracking)
- **HTTP Method:** POST
- **Endpoint:** `/driver/location`
- **Full URL:** `$BACKEND_URL/driver/location`
- **Service:** TrackingService.sendDriverLocation()
- **Called From:** `_sendDriverLocation()` - Called from GPS position stream
- **Called When:** Driver moves (distanceFilter: 20m) AND order not completed
- **Request Payload:**
  ```json
  {
    "driver_id": int (required),
    "order_id": int (required),
    "lat": double (required),
    "lng": double (required)
  }
  ```
- **Expected Response:** HTTP 200 or 201 (status code only checked)
- **Error Handling:**
  - Silently ignores errors (fire-and-forget pattern)
  - Exceptions caught but not logged
- **Frequency:** ~Every 20 meters of movement

---

## 3. DRIVER_DASHBOARD_PAGE.DART
File: [lib/features/dashboard/pages/driver_dashboard_page.dart](lib/features/dashboard/pages/driver_dashboard_page.dart)

### API Calls Made:

#### 3.1 Get Pending Orders
- **HTTP Method:** GET
- **Endpoint:** `/orders/pending`
- **Full URL:** `$BACKEND_URL/orders/pending`
- **Service:** ApiService.getPendingOrders(String? token)
- **Called From:** `_fetchOrders()` - Polling every 3 seconds (if driver is online)
- **Request Headers:**
  - Authorization: Bearer $token (optional)
  - Content-Type: application/json
- **Expected Response:**
  ```json
  [
    {
      "id": int,
      "user_id": int,
      "address": string,
      "user_lat": double,
      "user_lng": double,
      "jenis_sampah": string,
      "catatan": string
    },
    ...
  ]
  ```
- **Response Handling:**
  - Converts to Order objects
  - Extracts and stores user_lat/user_lng as LatLng
  - Skips orders without valid id
- **Error Handling:**
  - Throws exception with friendly error message
  - Sets errorMessage state
  - Stops loading indicator on error

#### 3.2 Accept Order
- **HTTP Method:** PATCH
- **Endpoint:** `/orders/accept/{orderId}`
- **Full URL:** `$BACKEND_URL/orders/accept/{orderId}`
- **Service:** ApiService.acceptOrder(int orderId, int driverId, String? token)
- **Called From:** `_acceptOrder(Order order)` - User triggered action
- **Request Headers:**
  - Authorization: Bearer $token (optional)
  - Content-Type: application/json
- **Request Payload:**
  ```json
  {
    "driver_id": int (required)
  }
  ```
- **Expected Response:**
  ```json
  {
    "status": "success",
    "message": string
  }
  ```
- **Response Handling:**
  - Checks if status == 'success' OR message contains 'berhasil' (Indonesian: success)
  - Removes order from pending list
  - Sets as activeOrder
  - Navigates to OrderDetailCustomPage
- **Error Handling:**
  - Shows error message in UI
  - Throws exception with order-specific message

#### 3.3 Reject Order
- **HTTP Method:** POST
- **Endpoint:** `/orders/{orderId}/reject`
- **Full URL:** `$BACKEND_URL/orders/{orderId}/reject`
- **Service:** ApiService.rejectOrder(int orderId, int driverId, String? token)
- **Called From:** `_rejectOrder(Order order)` - User triggered action
- **Request Headers:**
  - Authorization: Bearer $token (optional)
  - Content-Type: application/json
- **Request Payload:**
  ```json
  {
    "driver_id": int (required)
  }
  ```
- **Error Handling:**
  - Silently ignores errors
  - Removes order from list in UI
  - Fire-and-forget pattern

#### 3.4 Send Driver Location (Real-time tracking)
- **HTTP Method:** POST
- **Endpoint:** `/driver/location`
- **Full URL:** `$BACKEND_URL/driver/location`
- **Service:** ApiService.sendDriverLocation()
- **Called From:** `_sendLocationToBackend()` - When activeOrder exists and driver moves
- **Request Headers:**
  - Authorization: Bearer $token (optional)
  - Content-Type: application/json
- **Request Payload:**
  ```json
  {
    "driver_id": int,
    "order_id": int,
    "lat": double,
    "lng": double
  }
  ```
- **Frequency:** On every GPS position update (distanceFilter: 5m)
- **Error Handling:** Silently ignores errors

---

## 4. PICKUP_PAGE.DART
File: [lib/features/orders/pages/pickup_page.dart](lib/features/orders/pages/pickup_page.dart)

### API Calls Made:

#### 4.1 Reverse Geocoding (External Service)
- **HTTP Method:** GET
- **Endpoint:** `https://nominatim.openstreetmap.org/reverse`
- **Query Parameters:**
  - format: jsonv2
  - lat: double
  - lon: double (note: 'lon' not 'lng')
- **Headers:**
  - User-Agent: K-TRASH/1.0 (example@example.com)
- **Called From:** `_reverseGeocode(double lat, double lng)` - After location is set
- **Expected Response:**
  ```json
  {
    "display_name": string,
    "address": {
      "house_number": string,
      "road": string,
      "path": string,
      "residential": string,
      "neighbourhood": string,
      "hamlet": string,
      "suburb": string,
      "village": string,
      "town": string,
      "city": string,
      "county": string,
      "state_district": string,
      "state": string,
      "postcode": string,
      "country": string
    }
  }
  ```
- **Response Handling:**
  - Builds street address from address components
  - Falls back to display_name if available
  - Default fallback: "Jalan sekitar lokasi" (Street nearby location)
- **Error Handling:**
  - Catches all exceptions
  - Falls back to default address
  - No error message shown to user

#### 4.2 Create Order
- **HTTP Method:** POST
- **Endpoint:** `/orders`
- **Full URL:** `$BACKEND_URL/orders`
- **Service:** OrderService.createOrder(Map<String, dynamic> payload)
- **Called From:** `OrderProvider.createOrder(int userId)` - Final order submission
- **Request Headers:**
  - Authorization: Bearer $token (via ApiClient interceptor)
  - Content-Type: application/json
- **Request Payload:**
  ```json
  {
    "user_id": int (required),
    "address": string (required, non-empty),
    "user_lat": double (required),
    "user_lng": double (required),
    "jenis_sampah": string (required, non-empty),
    "catatan": string (optional, null if empty)
  }
  ```
- **Validation Before Request:**
  - user_lat and user_lng must not be null
  - address must not be empty
  - jenis_sampah list must not be empty
- **Expected Response (201 Created or 200 OK):**
  ```json
  {
    "order_id": int,
    "order": {
      "id": int,
      "status": string,
      "created_at": datetime,
      ...
    },
    "id": int,
    "status": string,
    "created_at": datetime,
    ...
  }
  ```
- **Response Handling:**
  - If response contains "order_id", fetches full order details via GET /orders/{id}
  - Otherwise extracts order from "order" key or uses direct response
  - Returns OrderModel object
- **Error Handling:**
  - Catches DioException and logs details
  - Sets errorMessage state
  - Rethrows exception
  - Returns false on failure

#### 4.3 Get Order Details (If needed after creation)
- **HTTP Method:** GET
- **Endpoint:** `/orders/{orderId}`
- **Full URL:** `$BACKEND_URL/orders/{orderId}`
- **Service:** OrderService.getOrderById(int orderId)
- **Called From:** OrderService.createOrder() (if response contains only order_id)
- **Expected Response:**
  ```json
  {
    "id": int,
    "user_id": int,
    "address": string,
    "user_lat": double,
    "user_lng": double,
    "jenis_sampah": string,
    "status": string,
    "catatan": string,
    "created_at": datetime,
    ...
  }
  ```
- **Error Handling:**
  - Throws exception if status != 200
  - DioException handling

---

## Summary Table of All Endpoints

| File | HTTP Method | Endpoint | Purpose | Frequency |
|------|-------------|----------|---------|-----------|
| tracking_page.dart | GET | /tracking/{orderId} | Get order tracking status & driver location | Every 3 seconds |
| driver_tracking_page.dart | GET | /tracking/{orderId} | Get order tracking status & user location | Every 3 seconds |
| driver_tracking_page.dart | POST | /driver/location | Send driver's real-time location | Every 20m movement |
| driver_dashboard_page.dart | GET | /orders/pending | Get list of pending orders | Every 3 seconds (if online) |
| driver_dashboard_page.dart | PATCH | /orders/accept/{orderId} | Accept an order | On user action |
| driver_dashboard_page.dart | POST | /orders/{orderId}/reject | Reject an order | On user action |
| driver_dashboard_page.dart | POST | /driver/location | Send driver location | Every 5m movement |
| pickup_page.dart | GET | /orders | Create order | On user submission |
| pickup_page.dart | GET | /orders/{orderId} | Get order details after creation | If needed |
| pickup_page.dart | GET | https://nominatim.openstreetmap.org/reverse | Reverse geocoding (external) | After location picked |

---

## Error Handling Patterns

### Pattern 1: Exception + Error Message (tracking_page.dart, driver_tracking_page.dart)
```dart
try {
  final result = await _trackingService.getTracking(widget.orderId!);
  // Process result
} catch (e) {
  setState(() {
    _errorMessage = 'Gagal memuat tracking: $e';
  });
}
```

### Pattern 2: Fire-and-Forget (Location Updates)
```dart
try {
  await _sendDriverLocation(position);
} catch (_) {
  // Ignore errors - continue polling
}
```

### Pattern 3: Response Normalization
```dart
Map<String, dynamic> _normalizeResponse(Map<String, dynamic> raw) {
  if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw['data'] as Map<String, dynamic>);
  }
  return Map<String, dynamic>.from(raw);
}
```

### Pattern 4: Status Validation
```dart
final accepted = (data['status'] == 'success') || 
                 msg.contains('berhasil');  // Indonesian success check
```

---

## Important Notes

1. **Polling Intervals:**
   - Tracking pages: 3 seconds (real-time order tracking)
   - Dashboard: 3 seconds but only if driver is online
   - Location updates: triggered by GPS movement (5-20m threshold)

2. **Authentication:**
   - All endpoints except /orders/pending can require Bearer token
   - Token is automatically added by ApiClient interceptor
   - Some endpoints work without token (backward compatibility)

3. **Response Format Variations:**
   - `/tracking` can return wrapped in "data" key or direct object
   - `/orders` can return with "order" key or direct object
   - `/orders/pending` always returns array

4. **External Dependencies:**
   - OSRM (Open Source Routing Machine) for route calculation
   - Nominatim OpenStreetMap for reverse geocoding

5. **Error Handling Strategies:**
   - Critical operations (tracking, orders): Show error message + set state
   - Non-critical (location updates): Silently fail, continue polling
   - Network operations: Use Dio with timeout/retry logic

6. **Real-time Tracking:**
   - Driver continuously sends location every 5-20m movement
   - User receives updates via polling every 3 seconds
   - Route calculated using free OSRM service
   - All coordinates are latitude/longitude pairs (not mercator)

7. **Order Creation Flow:**
   - User sets pickup location via GPS
   - Address reverse-geocoded from coordinates
   - Order created with all location/waste data
   - Response may contain only order_id → requires fetch to get full details
