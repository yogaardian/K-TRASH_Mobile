import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../petugas/models/order.dart';
import '../../driver/providers/driver_provider.dart';
import '../../driver/pages/driver_profile_page.dart';
import '../../driver/pages/order_detail_custom_page.dart';
import '../../../utils/secure_storage_helper.dart';
import '../../../utils/profile_photo_utils.dart';
import '../../../services/api_service.dart';

// ─── Design Tokens (mirrored from React CSS) ──────────────────────────────────
const _kPrimary = Color(0xFF22C55E);
const _kPrimaryDark = Color(0xFF15803D);
const _kPrimaryDeep = Color(0xFF14532D);
const _kPanelBg = Color(0xFFF5F7F5);
const _kMapBg = Color(0xFF0A0F1A);
const _kCardBg = Colors.white;
const _kTextPrimary = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kTextMuted = Color(0xFF94A3B8);
const _kBorderLight = Color(0x12000000);
const _kAmber = Color(0xFFF59E0B);
const _kBlue = Color(0xFF3B82F6);
const _kRed = Color(0xFFEF4444);

// Panel fixed width (matches React 360px)
const double _kPanelWidth = 360.0;

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({Key? key}) : super(key: key);

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  // ── Tab state ──────────────────────────────────────────────────────────────
  int _selectedIndex = 0;

  // ── Order / loading state (unchanged logic) ───────────────────────────────
  bool isLoading = true;
  bool _isFetching = false;
  String? errorMessage;

  List<Order> orders = [];
  Order? activeOrder;
  LatLng? activeOrderLocation;
  final Map<int, LatLng> _orderLocations = {};

  // ── Location (unchanged logic) ────────────────────────────────────────────
  LatLng driverLocation = const LatLng(-7.8, 110.3);
  StreamSubscription<Position>? _positionStream;
  final MapController _mapController = MapController();

  // ── Polling / driver info (unchanged logic) ───────────────────────────────
  Timer? _timer;
  int? _driverId;
  String? _driverName;
  String? _driverPhoto; // optional, extend SecureStorage if available

  // =========================================================================
  // LIFECYCLE (unchanged logic) ─────────────────────────────────────────────
  // =========================================================================

  @override
  void initState() {
    super.initState();
    _initializeDriver();
  }

  Future<void> _initializeDriver() async {
    _initializeLocationTracking();
    await _loadDriverInfo();
    _fetchOrders();
    _startPolling();
  }

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
            _driverPhoto = _extractProfilePhoto(parsed);
          });
        }
      }
    } catch (_) {
      // ignore invalid stored user data
    }
  }

  String? _extractProfilePhoto(Map<String, dynamic> data) {
    final candidates = [
      data['photo'],
      data['profile_photo'],
      data['profilePhoto'],
      data['avatar'],
      data['profile_image'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  Future<void> _initializeLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      if (await Geolocator.isLocationServiceEnabled()) {
        _startPositionStream();
      } else {
        setState(() => errorMessage = 'GPS tidak aktif');
      }
    } catch (e) {
      setState(() => errorMessage = 'Error lokasi: $e');
    }
  }

  void _startPositionStream() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              driverLocation = LatLng(position.latitude, position.longitude);
            });
            _mapController.move(driverLocation, _mapController.camera.zoom);
            if (activeOrder != null) _sendLocationToBackend();
          }
        });
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (context.read<DriverProvider>().isOnline) _fetchOrders();
    });
  }

  Future<void> _fetchOrders() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final token = await SecureStorageHelper.getToken();
      final decoded = await ApiService.getPendingOrders(token);

      final newOrders = <Order>[];
      final newLocations = <int, LatLng>{};

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

      if (!mounted) return;

      if (!_sameOrders(orders, newOrders)) {
        setState(() {
          orders = newOrders;
          _orderLocations
            ..clear()
            ..addAll(newLocations);
          errorMessage = null;
        });
      } else {
        _orderLocations
          ..clear()
          ..addAll(newLocations);
      }

      if (isLoading) setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = _friendlyError(e.toString());
        isLoading = false;
      });
    } finally {
      _isFetching = false;
    }
  }

  bool _sameOrders(List<Order> a, List<Order> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].nama != b[i].nama ||
          a[i].alamat != b[i].alamat ||
          a[i].code != b[i].code ||
          a[i].jenisSampah != b[i].jenisSampah ||
          a[i].catatan != b[i].catatan)
        return false;
    }
    return true;
  }

  Map<String, dynamic>? _parseStoredUserData(String userJson) {
    try {
      return jsonDecode(userJson) as Map<String, dynamic>;
    } on FormatException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  String _friendlyError(String msg) {
    final l = msg.toLowerCase();
    if (l.contains('failed to fetch') ||
        l.contains('socketexception') ||
        l.contains('connection refused') ||
        l.contains('timed out') ||
        l.contains('network')) {
      return 'Gagal terhubung ke backend. Periksa koneksi atau server.';
    }
    return msg;
  }

  Future<void> _acceptOrder(Order order) async {
    try {
      final token = await SecureStorageHelper.getToken();
      final data = await ApiService.acceptOrder(
        order.id!,
        _driverId ?? 1,
        token,
      );
      final msg = data['message']?.toString().toLowerCase() ?? '';
      final accepted =
          (data['status'] == 'success') || msg.contains('berhasil');
      if (accepted) {
        setState(() {
          activeOrder = order;
          activeOrderLocation =
              _orderLocations[order.id!] ?? const LatLng(-7.7, 110.35);
          orders.removeWhere((e) => e.id == order.id);
          errorMessage = null;
        });
        _sendLocationToBackend();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailCustomPage(
              order: activeOrder!,
              driverId: _driverId ?? 1,
            ),
          ),
        );
        return;
      }
      setState(
        () => errorMessage =
            data['message']?.toString() ?? 'Gagal menerima order',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = 'Gagal menerima order: $e');
    }
  }

  void _rejectOrder(Order order) {
    () async {
      try {
        final token = await SecureStorageHelper.getToken();
        await ApiService.rejectOrder(order.id!, _driverId ?? 1, token);
      } catch (_) {}
      if (!mounted) return;
      setState(() => orders.removeWhere((e) => e.id == order.id));
    }();
  }

  Future<void> _sendLocationToBackend() async {
    if (activeOrder == null) return;
    try {
      final token = await SecureStorageHelper.getToken();
      await ApiService.sendDriverLocation(
        _driverId ?? 1,
        activeOrder!.id!,
        driverLocation.latitude,
        driverLocation.longitude,
        token,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  // =========================================================================
  // BUILD ───────────────────────────────────────────────────────────────────
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kMapBg,
      body: IndexedStack(
        index: _selectedIndex,
        children: [_buildDashboardTab(), const DriverProfilePage()],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Bottom nav (unchanged behavior) ──────────────────────────────────────
  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        height:
            kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: SizedBox(
          height: kBottomNavigationBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Beranda'),
              _buildNavItem(1, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final active = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (index == 2) {
          _loadDriverInfo();
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? _kPrimary : _kTextSecondary, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: active ? _kPrimary : _kTextSecondary,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // DASHBOARD TAB ───────────────────────────────────────────────────────────
  // =========================================================================

  Widget _buildDashboardTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      // ── Mobile: map on top, panel scrollable below ──────────────────────
      return SafeArea(
        child: Column(
          children: [
            // Map: 52% of viewport height (mirrors React mobile breakpoint)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.52,
              child: _buildMapPanel(),
            ),
            // Order panel fills the rest
            Expanded(
              child: Container(
                color: _kPanelBg,
                child: Column(
                  children: [
                    // Sticky panel header
                    _buildPanelHeader(),
                    // Scrollable body
                    Expanded(child: _buildPanelBody()),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Desktop/Tablet: map left | panel right ───────────────────────────
    return SafeArea(
      child: Row(
        children: [
          // Map panel fills all remaining space
          Expanded(child: _buildMapPanel()),
          // Order panel fixed width
          SizedBox(
            width: screenWidth < 1024 ? 320 : _kPanelWidth,
            child: Container(
              decoration: const BoxDecoration(
                color: _kPanelBg,
                border: Border(
                  left: BorderSide(color: _kBorderLight, width: 1),
                ),
              ),
              child: Column(
                children: [
                  _buildPanelHeader(),
                  Expanded(child: _buildPanelBody()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MAP PANEL ───────────────────────────────────────────────────────────────
  // =========================================================================

  Widget _buildMapPanel() {
    final isOnline = context.watch<DriverProvider>().isOnline;

    return Stack(
      children: [
        // ── FlutterMap ────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: driverLocation,
            initialZoom: 14,
            minZoom: 5,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.banktrash.app',
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(markers: _buildMarkers()),
            if (activeOrder?.userLat != null && activeOrder?.userLng != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      driverLocation,
                      LatLng(activeOrder!.userLat!, activeOrder!.userLng!),
                    ],
                    color: _kPrimary.withOpacity(0.9),
                    strokeWidth: 4,
                    isDotted: true,
                  ),
                ],
              ),
          ],
        ),

        // ── Overlay: top-left "BankTrash Tracking" chip ───────────────────
        Positioned(
          top: 20,
          left: 20,
          child: _MapChip(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _PulseDot(color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'BankTrash Tracking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            backgroundColor: _kPrimary,
            borderColor: Colors.white24,
          ),
        ),

        // ── Overlay: top-right Online/Offline chip ─────────────────────────
        Positioned(
          top: 20,
          right: 20,
          child: _MapChip(
            backgroundColor: isOnline
                ? const Color(0x2E22C55E)
                : const Color(0x2E64748B),
            borderColor: isOnline
                ? const Color(0x4422C55E)
                : const Color(0x44475569),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(
                  color: isOnline ? _kPrimary : _kTextMuted,
                  pulseColor: isOnline
                      ? const Color(0x3322C55E)
                      : Colors.transparent,
                ),
                const SizedBox(width: 7),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isOnline ? _kPrimary : _kTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Overlay: bottom-center "Menuju lokasi pickup" chip ─────────────
        if (activeOrder?.userLat != null)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: _MapChip(
                backgroundColor: const Color(0xCC0A0F1A),
                borderColor: const Color(0x4DF59E0B),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.schedule_rounded, color: _kAmber, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'Menuju lokasi pickup',
                      style: TextStyle(
                        color: _kAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Overlay: bottom-left debug GPS panel (hidden on mobile ≤767) ──
        if (MediaQuery.of(context).size.width >= 768)
          Positioned(
            bottom: 24,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xBF0A0F1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                '${driverLocation.latitude.toStringAsFixed(5)}, '
                '${driverLocation.longitude.toStringAsFixed(5)}'
                '${activeOrder != null ? "  •  Order #${activeOrder!.id}" : ""}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: _kTextSecondary,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    return [
      // Driver (blue)
      Marker(
        width: 40,
        height: 40,
        point: driverLocation,
        child: const Icon(Icons.location_pin, color: _kBlue, size: 40),
      ),
      // Pending order locations (red)
      ...orders.map((order) {
        final loc = _orderLocations[order.id] ?? const LatLng(-7.7, 110.35);
        return Marker(
          width: 40,
          height: 40,
          point: loc,
          child: const Icon(Icons.location_pin, color: _kRed, size: 40),
        );
      }),
      // Active order pickup location (red)
      if (activeOrder?.userLat != null && activeOrder?.userLng != null)
        Marker(
          width: 40,
          height: 40,
          point: LatLng(activeOrder!.userLat!, activeOrder!.userLng!),
          child: const Icon(Icons.location_pin, color: _kRed, size: 40),
        ),
    ];
  }

  // =========================================================================
  // ORDER PANEL HEADER ──────────────────────────────────────────────────────
  // =========================================================================

  Widget _buildPanelHeader() {
    final isOnline = context.watch<DriverProvider>().isOnline;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: const BoxDecoration(
        color: _kPanelBg,
        border: Border(bottom: BorderSide(color: Color(0x0F000000), width: 2)),
      ),
      child: Column(
        children: [
          // ── Driver profile row ───────────────────────────────────────────
          _buildProfileRow(isOnline),
          const SizedBox(height: 10),
          // ── Status chips ─────────────────────────────────────────────────
          _buildStatusBar(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProfileRow(bool isOnline) {
    final name = _driverName ?? 'Driver';

    return Row(
      children: [
        // Avatar with online dot
        Stack(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x1A22C55E),
                border: Border.all(color: const Color(0x4D22C55E), width: 2),
              ),
              child: ClipOval(
                child: () {
                  final imageProvider = buildProfileImageProvider(_driverPhoto);
                  if (imageProvider != null) {
                    return Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person_rounded,
                          color: _kPrimary,
                          size: 22,
                        );
                      },
                    );
                  }
                  return const Icon(
                    Icons.person_rounded,
                    color: _kPrimary,
                    size: 22,
                  );
                }(),
              ),
            ),
            if (isOnline)
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kPrimary,
                    border: Border.all(color: _kPanelBg, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3322C55E),
                        blurRadius: 4,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),

        // Name + role
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                  letterSpacing: 0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const Text(
                'Petugas BankTrash',
                style: TextStyle(fontSize: 11, color: _kTextSecondary),
              ),
            ],
          ),
        ),

        // Online/Offline toggle pill (mirrors React toggleTrack)
        GestureDetector(
          onTap: () {
            final p = context.read<DriverProvider>();
            p.setOnlineStatus(!p.isOnline);
            setState(() {});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: isOnline
                  ? const LinearGradient(
                      colors: [_kPrimary, _kPrimaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isOnline ? null : const Color(0xFF334155),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isOnline ? Colors.white : const Color(0xFF94A3B8),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    final lat = driverLocation.latitude.toStringAsFixed(4);
    final lng = driverLocation.longitude.toStringAsFixed(4);

    return Row(
      children: [
        Expanded(
          child: _StatusChip(
            icon: '📍',
            label: 'GPS',
            value: '$lat, $lng',
            color: _kBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusChip(
            icon: '📦',
            label: 'Order',
            value: activeOrder != null ? '#${activeOrder!.id}' : '—',
            color: activeOrder != null ? _kAmber : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // ORDER PANEL BODY ────────────────────────────────────────────────────────
  // =========================================================================

  Widget _buildPanelBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: activeOrder != null
          ? _buildActiveOrderSection()
          : _buildPendingOrderSection(),
    );
  }

  // ── Active Order Section ──────────────────────────────────────────────────
  Widget _buildActiveOrderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        _SectionHeader(
          dot: _kPrimary,
          label: 'Active Order',
          trailing: _LiveBadge(),
        ),
        const SizedBox(height: 12),
        // Card
        _buildActiveOrderCard(),
      ],
    );
  }

  Widget _buildActiveOrderCard() {
    final order = activeOrder!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: bubble + info + id badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserBubble(label: order.nama),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.nama,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.alamat,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kTextSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _IdBadge(id: order.id?.toString() ?? ''),
            ],
          ),
          const SizedBox(height: 14),

          // Meta rows
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x14000000),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _MetaRow(
                  label: 'Jenis Sampah',
                  value: order.jenisSampah ?? '—',
                ),
                const SizedBox(height: 6),
                _MetaRow(label: 'Catatan', value: order.catatan ?? 'Tidak ada'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Complete button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailCustomPage(
                    order: order,
                    driverId: _driverId ?? 1,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF66B282), _kPrimaryDark, _kPrimaryDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5922C55E),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Selesaikan Order',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pending Orders Section ────────────────────────────────────────────────
  Widget _buildPendingOrderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          dot: _kBlue,
          label: 'Pending Orders',
          trailing: orders.isNotEmpty
              ? _CountBadge(count: orders.length)
              : null,
        ),
        const SizedBox(height: 12),
        _buildPendingBody(),
      ],
    );
  }

  Widget _buildPendingBody() {
    if (isLoading) {
      return const _LoadingState();
    }
    if (errorMessage != null) {
      return _buildErrorState();
    }
    if (orders.isEmpty) {
      return const _EmptyState();
    }
    return Column(
      children: orders
          .map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PendingOrderCard(
                order: order,
                isOnline: context.read<DriverProvider>().isOnline,
                onReject: () => _rejectOrder(order),
                onViewDetail: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailCustomPage(
                        order: order,
                        driverId: _driverId ?? 1,
                      ),
                    ),
                  );
                },
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildErrorState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            border: Border.all(color: const Color(0xFFFCA5A5)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _friendlyError(errorMessage!),
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _fetchOrders, child: const Text('Coba Lagi')),
      ],
    );
  }
}

// =============================================================================
// SUB-WIDGETS (stateless, mirrors React sub-components) ──────────────────────
// =============================================================================

/// Mirrors React <MapOverlay> chip container
class _MapChip extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  const _MapChip({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D8D8C8C),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Dot with optional pulse ring, mirrors React mapChipDot / sectionDot
class _PulseDot extends StatelessWidget {
  final Color color;
  final Color pulseColor;

  const _PulseDot({required this.color, this.pulseColor = Colors.transparent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: pulseColor != Colors.transparent
            ? [BoxShadow(color: pulseColor, blurRadius: 0, spreadRadius: 3)]
            : null,
      ),
    );
  }
}

/// Mirrors React <StatusChip>
class _StatusChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(0.07), Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: _kTextMuted,
                    letterSpacing: 0.8,
                    height: 1,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors React sectionHeader row
class _SectionHeader extends StatelessWidget {
  final Color dot;
  final String label;
  final Widget? trailing;

  const _SectionHeader({required this.dot, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dot,
            boxShadow: [
              BoxShadow(
                color: dot.withOpacity(0.2),
                blurRadius: 0,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kTextMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Mirrors React activeBadge "LIVE"
class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x1F22C55E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x4D22C55E)),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: _kPrimary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Mirrors React countBadge
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x1F3B82F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x4D3B82F6)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kBlue,
        ),
      ),
    );
  }
}

/// Mirrors React userBubble (green gradient circle with initial)
class _UserBubble extends StatelessWidget {
  final String label;
  const _UserBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    final initial = label.isNotEmpty ? label.trim()[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF66B282), _kPrimaryDark, _kPrimaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Mirrors React orderIdBadge
class _IdBadge extends StatelessWidget {
  final String id;
  const _IdBadge({required this.id});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorderLight),
      ),
      child: Text(
        '#$id',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kTextMuted,
        ),
      ),
    );
  }
}

/// Mirrors React <OrderMetaRow>
class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// Mirrors React <PendingOrderCard>
class _PendingOrderCard extends StatelessWidget {
  final Order order;
  final bool isOnline;
  final VoidCallback onReject;
  final VoidCallback onViewDetail;

  const _PendingOrderCard({
    required this.order,
    required this.isOnline,
    required this.onReject,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserBubble(label: order.nama),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.nama,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.alamat,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kTextSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (order.jenisSampah != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        order.jenisSampah!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _kBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons: Tolak | Lihat Detail
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Tolak',
                  onTap: onReject,
                  style: _ActionButtonStyle.outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Opacity(
                  opacity: isOnline ? 1.0 : 0.5,
                  child: _ActionButton(
                    label: 'Lihat Detail',
                    onTap: isOnline ? onViewDetail : null,
                    style: _ActionButtonStyle.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ActionButtonStyle { outline, primary }

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final _ActionButtonStyle style;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isOutline = style == _ActionButtonStyle.outline;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: isOutline
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF66B282), _kPrimaryDark, _kPrimaryDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isOutline ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(10),
          border: isOutline ? Border.all(color: const Color(0x2DFF0000)) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isOutline ? _kTextSecondary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mirrors React <EmptyState>
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x0FFFFFFF)),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF334155),
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tidak ada order pending',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Menunggu order masuk...',
            style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}

/// Mirrors React spinner loading state
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _kPrimary,
              backgroundColor: Color(0x2622C55E),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Memuat order...',
            style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}
