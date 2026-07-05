import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:user/services/tracking_service.dart';

// ─── Design tokens (mirrors `T` object on the website) ─────────────────────
class _T {
  static const green800 = Color(0xFF14532D);
  static const green700 = Color(0xFF15803D);
  static const green600 = Color(0xFF16A34A);
  static const green500 = Color(0xFF22C55E);
  static const greenGlow = Color(0x2E22C55E);
  static const greenGlow2 = Color(0x1422C55E);
  static const surface = Colors.white;
  static const bg = Colors.white;
  static const border = Color(0x2622C55E);
  static const borderStrong = Color(0x4D22C55E);
  static const text = Color(0xFF0F172A);
  static const textMid = Color(0xFF334155);
  static const textSoft = Color(0xFF64748B);
  static const textXsoft = Color(0xFF94A3B8);
  static const amber = Color(0xFFF59E0B);
  static const amberGlow = Color(0x1FF59E0B);
  static const blue = Color(0xFF3B82F6);
  static const red = Color(0xFFEF4444);
  static const radius = 20.0;
  static const radiusSm = 12.0;
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final int step;
  const _StatusInfo(this.label, this.icon, this.color, this.bg, this.step);
}

final Map<String, _StatusInfo> kStatusConfig = {
  'assigned': const _StatusInfo('Petugas Ditugaskan', Icons.assignment_outlined, _T.blue, Color(0x1A3B82F6), 0),
  'on_the_way': const _StatusInfo('Menuju Lokasi Anda', Icons.local_shipping_outlined, _T.green500, _T.greenGlow, 1),
  'arrived': const _StatusInfo('Petugas Sudah Tiba', Icons.location_on_outlined, _T.amber, _T.amberGlow, 2),
  'completed': const _StatusInfo('Penjemputan Selesai', Icons.check_circle_outline, _T.green600, _T.greenGlow2, 3),
  'approved': const _StatusInfo('Disetujui Admin', Icons.celebration_outlined, _T.green700, _T.greenGlow2, 3),
};

const List<String> kStepLabels = ['Ditugaskan', 'Menuju Lokasi', 'Tiba', 'Selesai'];

class TrackingPage extends StatefulWidget {
  final int? orderId;
  const TrackingPage({Key? key, this.orderId}) : super(key: key);

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  // ── ORIGINAL SERVICE / MAP STATE (tidak diubah) ──
  final TrackingService _trackingService = TrackingService();
  final MapController _mapController = MapController();
  final LatLng _defaultCenter = const LatLng(-6.8915, 111.4944);

  bool _loading = true;
  bool _refreshing = false;
  String? _errorMessage;

  LatLng? _driverPosition;
  LatLng? _userPosition;
  String _userAddress = '';
  String _orderStatus = '';
  List<LatLng> _routePoints = [];

  Timer? _pollingTimer;

  // ── STATE BARU UNTUK UI (opsional, defensive) ──
  String? _driverName;
  String? _driverId;
  String? _driverPhone;
  Map<String, dynamic>? _sampahData;
  double _totalBerat = 0;
  double _totalHarga = 0;

  String? _previousStatus;
  bool _arrivedNotif = false;
  bool _completedNotif = false;
  bool _completedRedirected = false;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
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
  }

  // ── LOGIC POLLING (dipertahankan, hanya ditambah ekstraksi field baru) ──
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
      final status = data['order_status']?.toString() ?? data['status']?.toString() ?? '';
      final address = data['address']?.toString() ?? '';

      // Ekstraksi opsional (tidak mengubah kontrak API, hanya membaca jika ada)
      final driverName = data['driver_name']?.toString();
      final driverId = data['driver_id']?.toString() ?? data['driver']?.toString();
      final driverPhone = data['driver_phone']?.toString() ?? data['phone']?.toString();
      final sampahRaw = data['sampah_data'];
      final totalBerat = _toDouble(data['total_berat']) ?? 0;
      final totalHarga = _toDouble(data['total_harga']) ?? 0;

      final newStatus = status.trim();

      setState(() {
        _driverPosition = driverLat != null && driverLng != null ? LatLng(driverLat, driverLng) : null;
        _userPosition = userLat != null && userLng != null ? LatLng(userLat, userLng) : null;
        _orderStatus = newStatus;
        _userAddress = address;
        _errorMessage = null;

        _driverName = driverName ?? _driverName;
        _driverId = driverId ?? _driverId;
        _driverPhone = driverPhone ?? _driverPhone;
        if (sampahRaw is Map) {
          _sampahData = Map<String, dynamic>.from(sampahRaw);
          _totalBerat = totalBerat;
          _totalHarga = totalHarga;
        }

        // Notifikasi status berubah pertama kali (murni UI, tidak mempengaruhi polling)
        if (newStatus.isNotEmpty && newStatus != _previousStatus) {
          if (newStatus == 'arrived') _arrivedNotif = true;
          _previousStatus = newStatus;
        }
      });

      if (_driverPosition != null && _userPosition != null) {
        await _updateRoute(_userPosition!, _driverPosition!);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds();
      });

      _maybeHandleCompleted();
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

  void _maybeHandleCompleted() {
    if (_orderStatus == 'completed' && !_completedRedirected) {
      setState(() => _completedNotif = true);
      _completedRedirected = true;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          // Sesuaikan dengan route dashboard aplikasi Anda jika berbeda.
          Navigator.of(context).maybePop();
        }
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

  // ── OSRM ROUTING (tidak diubah) ──
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
      // ignore and fallback to direct line
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

  _StatusInfo get _cfg => kStatusConfig[_orderStatus] ?? kStatusConfig['assigned']!;

  // ─────────────────────────────── UI ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final center = _userPosition ?? _driverPosition ?? _defaultCenter;

    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 14),
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: 14),
                  ],
                  if (_arrivedNotif) ...[
                    _buildNotificationBanner(
                      icon: Icons.location_on,
                      title: 'Petugas Sudah Tiba!',
                      body: 'Petugas sedang menunggu dan memproses sampahmu.',
                      color: _T.amber,
                      bg: _T.amberGlow,
                      onClose: () => setState(() => _arrivedNotif = false),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_completedNotif) ...[
                    _buildNotificationBanner(
                      icon: Icons.check_circle,
                      title: 'Penjemputan Selesai!',
                      body: 'Data sudah dikirim, Anda akan diarahkan ke Dashboard.',
                      color: _T.green600,
                      bg: _T.greenGlow,
                      onClose: () => setState(() => _completedNotif = false),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_driverName != null) ...[
                    _buildDriverCard(),
                    const SizedBox(height: 14),
                  ],
                  _buildProgressCard(),
                  const SizedBox(height: 14),
                  _buildMapCard(center),
                  const SizedBox(height: 14),
                  _buildActions(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(19),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _T.surface,
              shape: BoxShape.circle,
              border: Border.all(color: _T.border),
              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: _T.green800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tracking Petugas',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _T.text)),
              const SizedBox(height: 1),
              Text('Pantau lokasi petugas secara realtime',
                  style: TextStyle(fontSize: 11, color: _T.textSoft)),
            ],
          ),
        ),
        IconButton(
          onPressed: _refreshing ? null : _onRefresh,
          icon: Icon(Icons.refresh, color: _T.green700),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildNotificationBanner({
    required IconData icon,
    required String title,
    required String body,
    required Color color,
    required Color bg,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(_T.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
              ],
            ),
          ),
          InkWell(onTap: onClose, child: Icon(Icons.close, size: 16, color: color)),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    final cfg = _cfg;
    final initials = (_driverName ?? 'P').substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.surface,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(_T.radius),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_T.green500, _T.green800]),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_driverName ?? 'Petugas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _T.text)),
                    const SizedBox(height: 2),
                    Text('ID: ${_driverId ?? '—'}', style: TextStyle(fontSize: 10, color: _T.textXsoft)),
                    if (_driverPhone != null && _driverPhone!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(_driverPhone!, style: TextStyle(fontSize: 11, color: _T.textSoft)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cfg.bg,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: cfg.color.withOpacity(0.27)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: cfg.color, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Aktif', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cfg.color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cfg.bg,
              border: Border.all(color: cfg.color.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(_T.radiusSm),
            ),
            child: Row(
              children: [
                Icon(cfg.icon, size: 18, color: cfg.color),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cfg.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cfg.color)),
                    Text('Status order saat ini', style: TextStyle(fontSize: 10, color: _T.textSoft)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final activeStep = _cfg.step;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _T.surface,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(_T.radius),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROGRES ORDER',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _T.textSoft, letterSpacing: 1.1)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(kStepLabels.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepIndex = i ~/ 2;
                final lineActive = stepIndex < activeStep;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: lineActive ? _T.green500 : Colors.black.withOpacity(0.08),
                  ),
                );
              }
              final stepIndex = i ~/ 2;
              final done = stepIndex < activeStep;
              final active = stepIndex == activeStep;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? _T.green600
                          : active
                              ? _T.green500
                              : Colors.black.withOpacity(0.06),
                      border: Border.all(
                        color: done ? _T.green600 : (active ? Colors.transparent : Colors.black.withOpacity(0.1)),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active ? Colors.white : Colors.black.withOpacity(0.2),
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 56,
                    child: Text(
                      kStepLabels[stepIndex],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: active ? FontWeight.w700 : (done ? FontWeight.w600 : FontWeight.w400),
                        color: active ? _T.green700 : (done ? _T.green600 : _T.textXsoft),
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(LatLng center) {
    return Container(
      height: 360,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_T.radius),
        border: Border.all(color: _T.border),
        boxShadow: [BoxShadow(color: _T.greenGlow, blurRadius: 24, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              minZoom: 5,
              maxZoom: 18,
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, color: _T.green500.withOpacity(0.92), strokeWidth: 5),
                  ],
                ),
              if (_driverPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: _driverPosition!,
                    child: const Icon(Icons.local_shipping, color: Colors.blue, size: 34),
                  ),
                ]),
              if (_userPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: _userPosition!,
                    child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 34),
                  ),
                ]),
            ],
          ),
          // ── overlay chips (mirrors MapOverlayChips di website) ──
          Positioned(
            top: 14,
            left: 14,
            child: _chip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: _T.green500, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Text('K-TRASH Live Tracking', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _T.green800)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: _chip(
              bg: _cfg.bg,
              borderColor: _cfg.color.withOpacity(0.27),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_cfg.icon, size: 14, color: _cfg.color),
                  const SizedBox(width: 5),
                  Text(_cfg.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _cfg.color)),
                ],
              ),
            ),
          ),
          if (_userAddress.isNotEmpty)
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Center(
                child: _chip(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: _T.green600),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _userAddress,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _T.green700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip({required Widget child, Color? bg, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: bg ?? Colors.white.withOpacity(0.92),
        border: Border.all(color: borderColor ?? _T.border),
        borderRadius: BorderRadius.circular(50),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _buildActions() {
    final showSampah = (_orderStatus == 'arrived' || _orderStatus == 'completed') && _sampahData != null;
    final showDone = (_orderStatus == 'approved' || _orderStatus == 'completed');

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _refreshing ? null : _onRefresh,
            icon: Icon(Icons.refresh, size: 16, color: _T.green700),
            label: Text(_refreshing ? 'Memuat...' : 'Muat Ulang Lokasi',
                style: TextStyle(color: _T.green700, fontWeight: FontWeight.w700, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: _T.borderStrong, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_T.radiusSm)),
            ),
          ),
        ),
        if (showSampah) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSampahDialog(context),
              icon: const Icon(Icons.receipt_long, size: 16, color: Colors.white),
              label: const Text('Rincian Sampah', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.green600,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_T.radiusSm)),
              ),
            ),
          ),
        ],
        if (showDone) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.check, size: 16, color: Colors.white),
              label: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.green700,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_T.radiusSm)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showSampahDialog(BuildContext context) {
    final categories = ['organik', 'anorganik', 'lainnya'];
    final catColors = {'organik': _T.green500, 'anorganik': _T.blue, 'lainnya': _T.amber};

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_T.radius)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Rincian Sampah',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _T.text)),
                    ),
                    InkWell(onTap: () => Navigator.of(ctx).pop(), child: const Icon(Icons.close, size: 20)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final kategori in categories)
                        if (_sampahData?[kategori] is Map && (_sampahData![kategori] as Map).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(kategori.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: catColors[kategori],
                                        letterSpacing: 1)),
                                const SizedBox(height: 8),
                                ...(_sampahData![kategori] as Map).entries.map((entry) {
                                  final item = Map<String, dynamic>.from(entry.value as Map);
                                  final berat = _toDouble(item['berat']) ?? 0;
                                  final harga = _toDouble(item['harga']) ?? 0;
                                  final sub = berat * harga;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _T.border),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Item #${entry.key}',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _T.text)),
                                              Text('$berat kg × Rp ${harga.toStringAsFixed(0)}',
                                                  style: TextStyle(fontSize: 11, color: _T.textSoft)),
                                            ],
                                          ),
                                        ),
                                        Text('Rp ${sub.toStringAsFixed(0)}',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: catColors[kategori])),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _T.greenGlow2,
                          border: Border.all(color: _T.borderStrong, width: 1.5),
                          borderRadius: BorderRadius.circular(_T.radiusSm),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TOTAL BERAT', style: TextStyle(fontSize: 10, color: _T.textSoft)),
                                  Text('${_totalBerat.toStringAsFixed(2)} kg',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _T.green700)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 34, color: _T.border),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('TOTAL HARGA', style: TextStyle(fontSize: 10, color: _T.textSoft)),
                                  Text('Rp ${_totalHarga.toStringAsFixed(0)}',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _T.green700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _T.greenGlow,
                      side: BorderSide(color: _T.borderStrong),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_T.radiusSm)),
                    ),
                    child: Text('Tutup', style: TextStyle(color: _T.green700, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}