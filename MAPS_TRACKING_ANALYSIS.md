# Flutter Mobile App - Maps & Tracking Investigation Report

## Executive Summary

The Flutter mobile app (`userendpetugas`) has **critical differences** from the web version in how it handles maps and real-time tracking:

- ❌ **No Socket.io integration** - uses polling only (3-second intervals)
- ⚠️ **Silent error handling** - failures are caught and ignored
- ⚠️ **Defensive but incomplete API parsing** - handles multiple response formats but doesn't validate data
- ⚠️ **No real-time push updates** - only polling for tracking data

---

## 1. FILES EXAMINED

### Mobile (Flutter) Files
| File | Purpose | Maps Features |
|------|---------|---------------|
| `lib/features/dashboard/pages/driver_dashboard_page.dart` | Driver dashboard showing active order | ✅ FlutterMap, markers, real-time GPS stream |
| `lib/features/tracking/pages/driver_tracking_page.dart` | User tracking driver | ✅ OSRM routing, map bounds fitting |
| `lib/features/tracking/pages/tracking_page.dart` | User tracking driver (alt) | ✅ OSRM routing, route caching, status tracking |
| `lib/features/orders/pages/pickup_page.dart` | User selecting pickup location | ✅ Map tap to select, geocoding |
| `lib/services/tracking_service.dart` | Service layer for tracking API calls | API wrapper with Dio |
| `lib/constants/api_constants.dart` | API endpoint definitions | Defines all endpoints and base URLs |

### Web (React) Files (for comparison)
| File | Key Difference |
|------|----------------|
| `pundesari/src/views/user/TrackingPetugas.js` | Uses Socket.io + polling, extensive logging |
| `pundesari/src/views/driver/TrackingUser.js` | Route caching, error handling |

### Backend Files
| File | API Implementation |
|------|-------------------|
| `backend/index.js` (lines 1264+) | GET /tracking/:order_id, POST /driver/location |

---

## 2. MAPS DEPENDENCIES & STACK

### Mobile Stack
```dart
// Maps rendering
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Location tracking
import 'package:geolocator/geolocator.dart';

// HTTP for routing (OSRM)
import 'package:http/http.dart' as http;

// API calls
import 'package:dio/dio.dart';

// State management
import 'package:provider/provider.dart';
```

### Web Stack (for reference)
```javascript
import { MapContainer, TileLayer, Marker, Polyline, GeoJSON } from "react-leaflet";
import L from "leaflet";
// Uses browser's native Geolocation API
// Uses Socket.io for real-time updates
```

---

## 3. REAL-TIME TRACKING IMPLEMENTATION

### ❌ CRITICAL FINDING: No Socket.io in Mobile

**Mobile Implementation (driver_tracking_page.dart):**

```dart
// POLLING ONLY - NO SOCKET.IO
Timer.periodic(const Duration(seconds: 3), (_) {
  _fetchTracking();  // Network call every 3 seconds
});

// Location streaming works, but data polling is separate
_positionSubscription = Geolocator.getPositionStream(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 20,  // Only report if moved 20m+
  ),
).listen((position) {
  // Update local state
  _driverPosition = LatLng(position.latitude, position.longitude);
  
  // Send to backend
  _sendDriverLocation(currentPoint);
  
  // Recalculate route
  _updateRoute(currentPoint, _userPosition!);
});
```

**Issues:**
1. Location stream updates device → backend
2. But tracking data comes from polling only (3-second delay)
3. User's driver location is 3+ seconds old
4. No push notification when driver location updates

**Web Implementation (TrackingPetugas.js):**

```javascript
// BOTH POLLING AND SOCKET.IO
useEffect(() => {
  fetchTracking();
  const interval = setInterval(fetchTracking, 3000);
  return () => clearInterval(interval);
}, [currentOrderId]);

// Socket subscription for real-time updates
subscribe('driver:location_updated', (data) => {
  if (String(data.orderId) === String(currentOrderId)) {
    setCurrentDriverLocation([data.lat, data.lng]);
  }
});
```

**Benefits of web approach:**
- Real-time driver location via Socket.io
- Polling as fallback (tolerance for socket failures)
- Fewer network requests
- Instant UI updates

---

## 4. API ENDPOINTS & DATA CONTRACTS

### GET /tracking/:orderId

**Mobile expected fields** (tracking_page.dart:123-138):
```dart
final driverLat = _toDouble(data['driver_lat']);
final driverLng = _toDouble(data['driver_lng']);
final userLat = _toDouble(data['user_lat']);
final userLng = _toDouble(data['user_lng']);
final status = data['order_status']?.toString() ?? data['status']?.toString();
final address = data['address']?.toString();

// Optional fields (defensive)
final driverName = data['driver_name']?.toString();
final driverId = data['driver_id']?.toString() ?? data['driver']?.toString();
final driverPhone = data['driver_phone']?.toString() ?? data['phone']?.toString();
final sampahData = data['sampah_data'];
final totalBerat = _toDouble(data['total_berat']);
final totalHarga = _toDouble(data['total_harga']);
```

**Response handling** (tracking_service.dart:10-22):
```dart
Future<Map<String, dynamic>> getTracking(int orderId) async {
  try {
    final response = await _apiClient.get('${ApiConstants.getTrackingEndpoint}/$orderId');
    if (response.statusCode == 200) {
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return raw;  // Assumes flat structure
      }
      throw Exception('Unexpected tracking response format');
    }
    throw Exception('Failed to fetch tracking data');
  } on DioException catch (e) {
    throw Exception('Error fetching tracking data: ${_getErrorMessage(e)}');
  }
}
```

**Response normalization** (tracking_page.dart:175-180):
```dart
Map<String, dynamic> _normalizeResponse(Map<String, dynamic> raw) {
  if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw['data'] as Map<String, dynamic>);
  }
  return Map<String, dynamic>.from(raw);
}
```

**Handles two response formats:**
```json
// Format 1: Flat response
{
  "driver_lat": -7.8,
  "driver_lng": 110.3,
  "user_lat": -6.9,
  "user_lng": 111.4,
  "order_status": "on_the_way"
}

// Format 2: Nested in 'data'
{
  "data": {
    "driver_lat": -7.8,
    "driver_lng": 110.3,
    ...
  }
}
```

### POST /driver/location

**Mobile implementation** (tracking_service.dart:25-50):
```dart
Future<bool> sendDriverLocation({
  required int driverId,
  required int orderId,
  required double lat,
  required double lng,
}) async {
  try {
    final response = await _apiClient.post(
      ApiConstants.sendDriverLocationEndpoint,
      data: {
        'driver_id': driverId,
        'order_id': orderId,
        'lat': lat,
        'lng': lng,
      },
    );
    return response.statusCode == 200 || response.statusCode == 201;
  } on DioException catch (e) {
    throw Exception('Error sending driver location: ${_getErrorMessage(e)}');
  }
}
```

**Backend endpoint** (backend/index.js:1260-1280):
```javascript
app.post('/driver/location', authenticateToken, async (req, res) => {
  const { driver_id, order_id, lat, lng } = req.body;
  // Validates and saves driver location
  // Emits Socket.io event to users
});
```

---

## 5. ROUTING IMPLEMENTATION - OSRM Integration

### Route Calculation (Both mobile and web use OSRM)

**Mobile** (driver_tracking_page.dart:192-240):
```dart
Future<void> _updateRoute(LatLng from, LatLng to) async {
  try {
    final snappedFrom = await _snapPoint(from);
    final snappedTo = await _snapPoint(to);
    
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${snappedFrom.longitude},${snappedFrom.latitude};'
      '${snappedTo.longitude},${snappedTo.latitude}'
      '?overview=full&geometries=geojson&steps=true&alternatives=true',
    );
    
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = payload['routes'] as List<dynamic>?;
      if (routes != null && routes.isNotEmpty) {
        final bestRoute = routes.first;
        final geometry = bestRoute['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List<dynamic>?;
        
        if (coordinates != null && coordinates.isNotEmpty) {
          _routePoints = coordinates.map((item) {
            final pair = item as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          }).toList();
          setState(() {});
          return;
        }
      }
    }
  } catch (_) {
    // ⚠️ SILENT FAILURE - FALLBACK TO STRAIGHT LINE
  }
  
  setState(() {
    _routePoints = [from, to];  // Fallback
  });
}
```

**Issues identified:**
1. ❌ **No error logging** - `catch (_)` swallows all errors
2. ❌ **Silent failure** - User has no idea routing failed
3. ⚠️ **Always falls back to straight line** - No retry logic
4. ⚠️ **No route caching** - Each route recalculated every time

**Web version (TrackingUser.js) - BETTER:**
```javascript
// Has route caching
if (routeCacheRef.current.has(key)) {
  const cached = routeCacheRef.current.get(key);
  if (Date.now() - cached.ts < 120000) {
    setRouteGeoJson(cached.geo);
    return;
  }
}

// Has error logging
} catch (err) {
  if (err.name === "AbortError") return;
  console.log("[ROUTE FETCH FAILED]", err);
  setRouteGeoJson({ type: "LineString", coordinates: [[from[1], from[0]], [to[1], to[0]]] });
}
```

---

## 6. ERROR HANDLING COMPARISON

### ⚠️ CRITICAL: Mobile has massive silent error catching

**Driver Tracking Page - Silent errors:**

```dart
// ❌ Error 1: Location send failures ignored
Future<void> _sendDriverLocation(LatLng position) async {
  if (widget.orderId == null || _driverId == null) return;
  try {
    await _trackingService.sendDriverLocation(...);
  } catch (_) {
    // Ignore errors for location updates while driving
  }
}

// ❌ Error 2: Route calculation failures ignored
catch (_) {
  // fallback to straight line
  _routePoints = [from, to];
}

// ❌ Error 3: OSRM snapping failures ignored
catch (_) {}
return point;  // Return unsnapped point
```

**Result:** User has no idea if the app is working correctly.

### ✅ Web version - Better error logging

```javascript
// Logs errors explicitly
} catch (err) {
  console.error("Error fetching tracking:", err);
  if (err.name === "AbortError") return;
  console.log("[ROUTE FETCH FAILED]", err);
}

// Provides user feedback
if (!driverLocation || !userLocation) {
  return <ErrorScreen message="Lokasi tidak tersedia" />;
}
```

---

## 7. POTENTIAL ISSUES & ROOT CAUSES

### Issue 1: Maps show incorrect driver location
**Causes:**
- API returns null for driver_lat/driver_lng
- Response field names don't match expectation
- Polling delay (3+ seconds)
- Location permissions denied

**Investigation steps:**
```dart
// Add logging in tracking_page.dart
setState(() {
  print('[TRACKING] Raw response: $result');
  print('[TRACKING] Driver lat: $driverLat, lng: $driverLng');
  print('[TRACKING] User lat: $userLat, lng: $userLng');
});
```

### Issue 2: Route not showing between driver and user
**Causes:**
- OSRM API timeout
- Invalid coordinates passed to OSRM
- Map rendering issue (Polyline not visible)
- OSRM snapping failure

### Issue 3: App lags / too many network requests
**Causes:**
- Location stream updates + 3-second polling = redundant requests
- OSRM called for every location update (no caching)
- No Socket.io = polling only for tracking data

### Issue 4: Missing driver data after accepting order
**Causes:**
- _driverId not extracted and stored
- API response doesn't include driver_id
- Type conversion error (int vs String)

---

## 8. COMPARISON TABLE: Mobile vs Web

| Aspect | Mobile (Flutter) | Web (React) | Better Choice |
|--------|------------------|-----------|---------------|
| **Real-time tracking** | Polling 3s | Socket.io + Polling | Web ✅ |
| **Network efficiency** | ❌ Redundant requests | ✅ Optimized | Web ✅ |
| **Error logging** | ❌ Silent | ✅ Console logs | Web ✅ |
| **Route caching** | ❌ No | ✅ Yes (120s) | Web ✅ |
| **GPS tracking** | ✅ Stream-based | ⚠️ Polling-based | Mobile ✅ |
| **Fallback handling** | ⚠️ Silent | ✅ Explicit | Web ✅ |
| **Performance** | ❌ More requests | ✅ Fewer requests | Web ✅ |

---

## 9. RECOMMENDED FIXES

### Priority 1: Add Socket.io support to mobile
```dart
// In tracking_service.dart
void subscribeToDriverLocation(int orderId, Function callback) {
  socket.on('driver:location_updated', (data) {
    if (data['orderId'] == orderId) {
      callback(data);
    }
  });
}
```

### Priority 2: Add error logging
```dart
// Replace silent catches
catch (e) {
  print('[ERROR] Failed to send driver location: $e');
  // Still ignore in production, but log for debugging
}
```

### Priority 3: Implement route caching
```dart
// Add to tracking_page.dart
final _routeCache = <String, MapEntry<DateTime, List<LatLng>>>{};

Future<void> _updateRoute(LatLng from, LatLng to) async {
  final key = '${from.latitude},${from.longitude}-${to.latitude},${to.longitude}';
  
  // Check cache
  if (_routeCache.containsKey(key)) {
    final cached = _routeCache[key]!;
    if (DateTime.now().difference(cached.key).inSeconds < 120) {
      _routePoints = cached.value;
      setState(() {});
      return;
    }
  }
  
  // Fetch and cache
  // ...
}
```

### Priority 4: Reduce polling frequency
```dart
// Change from 3s to 10s (when Socket.io unavailable)
Timer.periodic(const Duration(seconds: 10), (_) {
  _fetchTracking();
});
```

---

## 10. API RESPONSE VALIDATION CHECKLIST

When debugging API issues, verify:

- [ ] Driver coordinates are not null: `driver_lat != null && driver_lng != null`
- [ ] User coordinates are not null: `user_lat != null && user_lng != null`
- [ ] Status field exists and is valid
- [ ] Response is not wrapped in unexpected `data` object
- [ ] Numbers are actual numbers, not strings
- [ ] Order ID matches what was sent

**Test endpoint directly:**
```bash
curl -H "Authorization: Bearer TOKEN" \
  https://api-ktrashuns.tifpsdku.com/tracking/12345
```

---

## 11. DEBUGGING TIPS

### Enable verbose logging in Flutter
```dart
// Add to main.dart
void main() {
  // Enable all logging
  DioLogger.enableDebugLogging();
}
```

### Check network requests
- Use Dart DevTools Network tab
- Monitor HTTP calls to /tracking endpoint
- Check response payloads

### Check location permissions
```dart
// In driver_tracking_page.dart
var permission = await Geolocator.checkPermission();
print('Location permission: $permission');
```

### Verify OSRM responses
```dart
// Add logging in _updateRoute
print('[OSRM] Request: $uri');
print('[OSRM] Response: ${response.body}');
```

---

## SUMMARY

The Flutter mobile app's tracking implementation is **fundamentally sound** but has these gaps:

1. ✅ **Correct:** Polls API every 3 seconds
2. ✅ **Correct:** Streams GPS from device
3. ❌ **Missing:** Socket.io real-time subscriptions
4. ❌ **Missing:** Route caching
5. ❌ **Bad:** Silent error handling
6. ⚠️ **Risky:** Defensive response parsing without validation

**Most likely cause of issues:** API response field name mismatches or null values not being handled visibly to user.
