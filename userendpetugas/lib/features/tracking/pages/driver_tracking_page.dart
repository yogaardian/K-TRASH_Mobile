import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:user/services/tracking_service.dart';

class DriverTrackingPage extends StatefulWidget {
  final int? orderId;

  const DriverTrackingPage({Key? key, this.orderId}) : super(key: key);

  @override
  State<DriverTrackingPage> createState() => _DriverTrackingPageState();
}

class _DriverTrackingPageState extends State<DriverTrackingPage> {
  final TrackingService _trackingService = TrackingService();
  final MapController _mapController = MapController();
  final LatLng _defaultCenter = const LatLng(-6.8915, 111.4944);

  bool _loading = true;
  bool _refreshing = false;
  String? _errorMessage;
  String? _permissionMessage;

  LatLng? _driverPosition;
  LatLng? _userPosition;
  String _driverLabel = 'Petugas';
  String _orderStatus = '';
  List<LatLng> _routePoints = [];
  int? _driverId;

  Timer? _pollingTimer;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    if (widget.orderId == null) {
      setState(() {
        _errorMessage = 'Order ID tidak tersedia';
        _loading = false;
      });
      return;
    }

    await _fetchTracking();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchTracking();
    });
    await _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _permissionMessage = 'Layanan lokasi belum aktif';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() {
        _permissionMessage = 'Izin lokasi ditolak';
      });
      return;
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((position) {
      final currentPoint = LatLng(position.latitude, position.longitude);
      setState(() {
        _driverPosition = currentPoint;
        _permissionMessage = null;
      });
      if (_driverId != null && _orderStatus != 'completed') {
        _sendDriverLocation(currentPoint);
      }
      if (_userPosition != null) {
        _updateRoute(currentPoint, _userPosition!);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds();
      });
    }, onError: (error) {
      setState(() {
        _permissionMessage = 'Tidak dapat mengakses lokasi: $error';
      });
    });
  }

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
      // Ignore errors for location updates while driving.
    }
  }

  Future<void> _fetchTracking() async {
    if (widget.orderId == null) return;

    if (!_loading) {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final result = await _trackingService.getTracking(widget.orderId!);
      final data = _normalizeResponse(result);

      final driverLat = _toDouble(data['driver_lat']);
      final driverLng = _toDouble(data['driver_lng']);
      final userLat = _toDouble(data['user_lat']);
      final userLng = _toDouble(data['user_lng']);
      final driverName = data['driver_name']?.toString() ?? data['driver_name']?.toString() ?? 'Petugas';
      final status = data['order_status']?.toString() ?? data['status']?.toString() ?? '';
      final driverId = data['driver_id'] is num ? (data['driver_id'] as num).toInt() : int.tryParse(data['driver_id']?.toString() ?? '');

      setState(() {
        _driverPosition = driverLat != null && driverLng != null ? LatLng(driverLat, driverLng) : _driverPosition;
        _userPosition = userLat != null && userLng != null ? LatLng(userLat, userLng) : _userPosition;
        _driverLabel = driverName;
        _orderStatus = status;
        _driverId = driverId ?? _driverId;
        _errorMessage = null;
      });

      if (_driverPosition != null && _userPosition != null) {
        await _updateRoute(_driverPosition!, _userPosition!);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat tracking: $e';
      });
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Map<String, dynamic> _normalizeResponse(Map<String, dynamic> raw) {
    if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw['data'] as Map<String, dynamic>);
    }
    return Map<String, dynamic>.from(raw);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

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
        if (routes != null && routes.isNotEmpty) {
          final bestRoute = routes.first as Map<String, dynamic>;
          final geometry = bestRoute['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.isNotEmpty) {
            _routePoints = coordinates.map((item) {
              final pair = item as List<dynamic>;
              return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
            }).toList();
            setState(() {});
            return;
          }
        }
      }
    } catch (_) {
      // fallback to straight line
    }

    setState(() {
      _routePoints = [from, to];
    });
  }

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
            return LatLng((location[1] as num).toDouble(), (location[0] as num).toDouble());
          }
        }
      }
    } catch (_) {}
    return point;
  }

  void _fitBounds() {
    final points = <LatLng>[];
    if (_driverPosition != null) points.add(_driverPosition!);
    if (_userPosition != null) points.add(_userPosition!);
    if (points.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(padding: EdgeInsets.all(24)),
    );
  }

  void _onRefresh() {
    _fetchTracking();
  }

  @override
  Widget build(BuildContext context) {
    final center = _driverPosition ?? _userPosition ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Driver'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_permissionMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(_permissionMessage!, style: const TextStyle(color: Colors.orange)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 14,
                          minZoom: 5,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          ),
                          if (_routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: Colors.green.withOpacity(0.92),
                                  strokeWidth: 5,
                                ),
                              ],
                            ),
                          if (_userPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: _userPosition!,
                                  child: const Icon(
                                    Icons.person_pin_circle,
                                    color: Colors.red,
                                    size: 34,
                                  ),
                                ),
                              ],
                            ),
                          if (_driverPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: _driverPosition!,
                                  child: const Icon(
                                    Icons.local_shipping,
                                    color: Colors.blue,
                                    size: 34,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order #${widget.orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Chip(
                              label: Text(
                                _orderStatus.isNotEmpty ? _orderStatus.toUpperCase() : 'UNKNOWN',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              backgroundColor: Colors.green[700],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Driver', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(_driverLabel),
                        if (_driverPosition != null) ...[
                          const SizedBox(height: 12),
                          Text('Posisi Anda', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text('Lat: ${_driverPosition!.latitude.toStringAsFixed(5)}, Lng: ${_driverPosition!.longitude.toStringAsFixed(5)}'),
                        ],
                        if (_userPosition != null) ...[
                          const SizedBox(height: 12),
                          Text('Alamat Tujuan', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text('Lat: ${_userPosition!.latitude.toStringAsFixed(5)}, Lng: ${_userPosition!.longitude.toStringAsFixed(5)}'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
