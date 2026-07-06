# Flutter Maps & Tracking - Specific Issues to Debug

## QUICK REFERENCE: Lines to Investigate

### File 1: `lib/features/tracking/pages/driver_tracking_page.dart`

#### Issue #1: Silent Location Send Failures (Line 117)
```dart
// CURRENT CODE - ❌ PROBLEM
Future<void> _sendDriverLocation(LatLng position) async {
  if (widget.orderId == null || _driverId == null) return;
  try {
    await _trackingService.sendDriverLocation(
      driverId: _driverId!,
      orderId: widget.orderId!,
      lat: position.latitude,
      lng: position.longitude,
    );
  } catch (_) {
    // Ignore errors for location updates while driving. ⚠️ SILENT FAILURE
  }
}

// FIX: Add logging
catch (e) {
  // Log but don't rethrow - fire and forget is OK for location updates
  print('[DRIVER_TRACKING] Warning: Failed to send location: $e');
}
```

**Impact:** If backend is unreachable, driver's location never updates to users.

---

#### Issue #2: Missing _driverId Extraction (Line 42-44)
```dart
// In initState:
await _fetchTracking();
_pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
  _fetchTracking();
});
```

**Problem:** Where is `_driverId` set? Look at _fetchTracking():

```dart
// Line 126-140 in _fetchTracking()
final driverId = data['driver_id'] is num 
  ? (data['driver_id'] as num).toInt() 
  : int.tryParse(data['driver_id']?.toString() ?? '');

setState(() {
  // ... BUT _driverId is never stored from fetchTracking result!
  // This is OK because it comes from the active order
  // But if _driverId is null, _sendDriverLocation() returns early (line 115)
});
```

**Check:** Is _driverId being set when order is accepted? Look in `driver_dashboard_page.dart` Line ~240.

---

#### Issue #3: OSRM Route Calculation Silent Failure (Line 192-226)
```dart
// CURRENT CODE - ❌ PROBLEM
Future<void> _updateRoute(LatLng from, LatLng to) async {
  try {
    final snappedFrom = await _snapPoint(from);
    final snappedTo = await _snapPoint(to);
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${snappedFrom.longitude},${snappedFrom.latitude};${snappedTo.longitude},${snappedTo.latitude}?overview=full&geometries=geojson&steps=true&alternatives=true',
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = payload['routes'] as List<dynamic>?;
      // ... parse routes ...
    }
  } catch (_) {
    // ⚠️ SILENT - user never knows routing failed
  }

  setState(() {
    _routePoints = [from, to];  // Fallback to straight line
  });
}

// FIX: Add logging
catch (e) {
  print('[OSRM_ERROR] Route calculation failed: $e');
  print('[OSRM_ERROR] Falling back to straight line route');
}
```

**Impact:** If OSRM is down or coordinates are invalid, user sees straight line with no error message.

---

#### Issue #4: OSRM Snapping Silent Failure (Line 227-244)
```dart
// CURRENT CODE - ❌ PROBLEM
Future<LatLng> _snapPoint(LatLng point) async {
  try {
    final uri = Uri.parse('https://router.project-osrm.org/nearest/v1/driving/${point.longitude},${point.latitude}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final waypoints = payload['waypoints'] as List<dynamic>?;
      if (waypoints != null && waypoints.isNotEmpty) {
        final location = waypoints.first['location'] as List<dynamic>?;
        if (location != null && location.length >= 2) {
          return LatLng(
            (location[1] as num).toDouble(),
            (location[0] as num).toDouble(),
          );
        }
      }
    }
  } catch (_) {} // ⚠️ SILENT - returns unsnapped point
  return point;
}

// FIX: Add logging
catch (e) {
  print('[OSRM_SNAP] Warning: Could not snap point, using original: $e');
}
```

**Impact:** If snapping fails, original points might be off-road, making route calculation fail next.

---

### File 2: `lib/features/tracking/pages/tracking_page.dart`

#### Issue #5: Response Normalization Assumes Data Shape (Line 175-180)
```dart
// CURRENT CODE - DEFENSIVE but incomplete validation
Map<String, dynamic> _normalizeResponse(Map<String, dynamic> raw) {
  if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw['data'] as Map<String, dynamic>);
  }
  return Map<String, dynamic>.from(raw);
}

// IMPROVE: Add logging to debug response format
Map<String, dynamic> _normalizeResponse(Map<String, dynamic> raw) {
  if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
    print('[TRACKING] Response wrapped in data: ${raw['data'].keys}');
    return Map<String, dynamic>.from(raw['data'] as Map<String, dynamic>);
  }
  print('[TRACKING] Flat response: ${raw.keys}');
  return Map<String, dynamic>.from(raw);
}
```

**Investigation:** Add this logging to see what the API actually returns.

---

#### Issue #6: Silent Fetch Error Handling (Line 125)
```dart
// CURRENT CODE - ❌ PROBLEM
try {
  final result = await _trackingService.getTracking(widget.orderId!);
  // ... process result ...
} catch (e) {
  setState(() {
    _errorMessage = 'Gagal memuat tracking: $e';  // ✅ Good - shows error
  });
} finally {
  setState(() {
    _loading = false;
    _refreshing = false;
  });
}

// ✅ This one is GOOD - error is shown to user
// But verify the UI actually displays _errorMessage
```

**Check:** Does the UI show `_errorMessage`? Search the build() method for error display.

---

#### Issue #7: Missing Validation Before Map Operations (Line 150-165)
```dart
// CURRENT CODE - at line 164-165
if (_driverPosition != null && _userPosition != null) {
  await _updateRoute(_userPosition!, _driverPosition!); // ✅ Good check
}

WidgetsBinding.instance.addPostFrameCallback((_) {
  _fitBounds();  // ✅ Safe because fitBounds checks for empty points
});

// But watch out: _routePoints could be empty or invalid
```

**Check:** If _routePoints is empty, does Polyline still render safely?

---

### File 3: `lib/features/orders/pages/pickup_page.dart`

#### Issue #8: Location Permission Failure (Line 160-180)
```dart
// CURRENT CODE - GOOD error handling
Future<void> _determinePosition() async {
  setState(() {
    _isLocating = true;
    _locationMessage = null;
  });

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = 'Layanan lokasi belum aktif';  // ✅ User sees this
        _isLocating = false;
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage = 'Izin lokasi ditolak';  // ✅ User sees this
        _isLocating = false;
      });
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await _setLocation(position.latitude, position.longitude);
  } catch (e) {
    setState(() {
      _locationMessage = 'Gagal mendapatkan lokasi: $e';  // ✅ Good
    });
  } finally {
    setState(() {
      _isLocating = false;
    });
  }
}

// ✅ This is GOOD - all errors shown to user
```

---

### File 4: `lib/services/tracking_service.dart`

#### Issue #9: API Client Error Handling (Line 12-23)
```dart
// CURRENT CODE - GOOD but could be better
Future<Map<String, dynamic>> getTracking(int orderId) async {
  try {
    final response = await _apiClient.get('${ApiConstants.getTrackingEndpoint}/$orderId');
    if (response.statusCode == 200) {
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      throw Exception('Unexpected tracking response format');
    }
    throw Exception('Failed to fetch tracking data');
  } on DioException catch (e) {
    throw Exception('Error fetching tracking data: ${_getErrorMessage(e)}');
  } catch (e) {
    throw Exception('Unexpected error: $e');
  }
}

// IMPROVE: Log what we got
if (raw is Map<String, dynamic>) {
  print('[TRACKING_SERVICE] Got response with keys: ${raw.keys.join(", ")}');
  return raw;
}
throw Exception('Unexpected tracking response format: got ${raw.runtimeType}');
```

**Check:** Look at response format before and after normalization.

---

#### Issue #10: Location Send Error Handling (Line 36-53)
```dart
// CURRENT CODE - Could be improved
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
  } catch (e) {
    throw Exception('Unexpected error: $e');
  }
}

// IMPROVE: Log what we're sending
print('[DRIVER_LOCATION_SEND] driverId=$driverId, orderId=$orderId, lat=$lat, lng=$lng');

// IMPROVE: Check response payload
if (response.statusCode == 200 || response.statusCode == 201) {
  print('[DRIVER_LOCATION_SEND] Success: ${response.data}');
  return true;
}
print('[DRIVER_LOCATION_SEND] Failed with status ${response.statusCode}: ${response.data}');
```

---

### File 5: `lib/features/dashboard/pages/driver_dashboard_page.dart`

#### Issue #11: Driver Info Loading (Line 98-113)
```dart
// CURRENT CODE - GOOD but incomplete
Future<void> _loadDriverInfo() async {
  try {
    final userJson = await SecureStorageHelper.getUserData();
    if (userJson != null) {
      final parsed = _parseStoredUserData(userJson);
      if (parsed != null) {
        setState(() {
          _driverId = parsed['id'] is int
              ? parsed['id'] as int
              : int.tryParse('${parsed['id']}');
          _driverName = parsed['nama'] ?? parsed['name']?.toString();
          _driverPhoto = parsed['photo']?.toString() ??
              parsed['profile_photo']?.toString();
        });
      }
    }
  } catch (_) {
    // ignore invalid stored user data  ⚠️ Silent
  }
}

// IMPROVE: Log what we got
} catch (e) {
  print('[DRIVER_INFO] Failed to load from storage: $e');
}
```

**Check:** If _driverId is null here, it won't be set when accepting orders.

---

#### Issue #12: Order Location Extraction (Line 165-195)
```dart
// CURRENT CODE - GOOD but check coordinates
for (final item in decoded) {
  if (item is! Map) continue;
  final orderId = item['id'];
  if (orderId is! int) continue;

  final lat = item['user_lat'];
  final lng = item['user_lng'];
  if (lat is num && lng is num) {
    newLocations[orderId] = LatLng(lat.toDouble(), lng.toDouble());
  }

  newOrders.add(
    Order(
      id: orderId,
      nama: 'User ${item['user_id'] ?? ''}',
      alamat: item['address']?.toString() ?? 'Alamat tidak tersedia',
      code: orderId.toString(),
      jenisSampah: item['jenis_sampah']?.toString(),
      catatan: item['catatan']?.toString(),
      userLat: lat is num ? lat.toDouble() : null,
      userLng: lng is num ? lng.toDouble() : null,
    ),
  );
}

// IMPROVE: Add logging
print('[ORDER_LOCATION] Order $orderId: lat=$lat, lng=$lng (is num: ${lat is num})');
```

**Check:** Are lat/lng coming as strings instead of numbers?

---

## DEBUGGING CHECKLIST

### 1. Verify API Response Format
```bash
# Get tracking data directly
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api-ktrashuns.tifpsdku.com/tracking/12345 | jq .
```

Expected response:
```json
{
  "driver_lat": -7.8,
  "driver_lng": 110.3,
  "user_lat": -6.9,
  "user_lng": 111.4,
  "order_status": "on_the_way",
  "driver_name": "Petugas Name"
}
```

OR nested:
```json
{
  "data": {
    "driver_lat": -7.8,
    ...
  }
}
```

### 2. Check Location Permissions
```dart
// Add to tracking page
var permission = await Geolocator.checkPermission();
print('Location permission: $permission');
print('Location service enabled: ${await Geolocator.isLocationServiceEnabled()}');
```

### 3. Monitor Network Requests
- Open DevTools Network tab
- Filter for `/tracking` requests
- Check response payload
- Check response headers
- Verify Authorization header

### 4. Test OSRM Directly
```bash
# Test routing
curl "https://router.project-osrm.org/route/v1/driving/110.3,-7.8;111.4,-6.9?overview=full&geometries=geojson" | jq .

# Test snapping
curl "https://router.project-osrm.org/nearest/v1/driving/110.3,-7.8" | jq .
```

### 5. Add Temporary Logging
Replace key sections with:
```dart
print('[DEBUG_TRACKING_START] ========================================');
print('[DEBUG] orderId: ${widget.orderId}');
print('[DEBUG] result: $result');
print('[DEBUG] normalized: $data');
print('[DEBUG] driverLat: $driverLat, driverLng: $driverLng');
print('[DEBUG] userLat: $userLat, userLng: $userLng');
print('[DEBUG_TRACKING_END] ========================================');
```

---

## NEXT STEPS

1. **Run the app** with the logging added above
2. **Accept an order** and watch the tracking page
3. **Check console output** for the debug messages
4. **Compare with web version** - does web show the same data?
5. **Test API directly** - does /tracking/:id return expected data?
6. **Check network** - are requests being sent? Are responses received?

---

## FILES TO MODIFY FOR DEBUGGING

1. **Add logging to:** `lib/services/tracking_service.dart` (getTracking method)
2. **Add logging to:** `lib/features/tracking/pages/tracking_page.dart` (_fetchTracking method)
3. **Add logging to:** `lib/features/tracking/pages/driver_tracking_page.dart` (_updateRoute method)
4. **Add UI error display** to show errors instead of silently failing
