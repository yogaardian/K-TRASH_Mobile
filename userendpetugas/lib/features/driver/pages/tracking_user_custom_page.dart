import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../../../petugas/models/order.dart';
import '../../../utils/secure_storage_helper.dart';

// ─── Design Tokens (mirrored from website) ────────────────────────────────────
const _green900 = Color(0xFF052E16);
const _green800 = Color(0xFF14532D);
const _green700 = Color(0xFF15803D);
const _green600 = Color(0xFF16A34A);
const _green500 = Color(0xFF22C55E);
const _green400 = Color(0xFF4ADE80);
const _greenGlow = Color(0x2E22C55E);
const _surface = Color(0xFFFFFFFF);
const _bg = Color(0xFFF0FDF4);
const _panel = Color(0xFFFAFFFE);
const _borderColor = Color(0x2622C55E);
const _borderStrong = Color(0x4D22C55E);
const _text = Color(0xFF0F172A);
const _textSoft = Color(0xFF64748B);
const _textXsoft = Color(0xFF94A3B8);
const _amber = Color(0xFFF59E0B);
const _blue = Color(0xFF3B82F6);
const _red = Color(0xFFEF4444);

const _radiusSm = 12.0;
const _radius = 20.0;

final String _backendBaseUrl = ApiConstants.baseUrl;

// ─── Status config ─────────────────────────────────────────────────────────────
const _statusConfig = {
  'assigned': {'label': 'Ditugaskan', 'color': _blue, 'step': 0},
  'on_the_way': {'label': 'Menuju Lokasi', 'color': _green500, 'step': 1},
  'arrived': {'label': 'Tiba di Lokasi', 'color': _amber, 'step': 2},
  'completed': {'label': 'Selesai', 'color': _green600, 'step': 3},
};
const _steps = ['Ditugaskan', 'Menuju Lokasi', 'Tiba', 'Selesai'];

// ─── Data models ──────────────────────────────────────────────────────────────
class _HargaItem {
  final int id;
  final String subJenis;
  final double harga;
  _HargaItem({required this.id, required this.subJenis, required this.harga});
  factory _HargaItem.fromJson(Map<String, dynamic> j) => _HargaItem(
    id: j['id'] as int,
    subJenis: j['sub_jenis']?.toString() ?? '',
    harga: (j['harga'] as num?)?.toDouble() ?? 0.0,
  );
}

class _SampahEntry {
  double berat;
  double harga;
  _SampahEntry({this.berat = 0, this.harga = 0});
}

// ─── Widget ───────────────────────────────────────────────────────────────────
class TrackingUserCustomPage extends StatefulWidget {
  final Order order;
  final int driverId;

  const TrackingUserCustomPage({
    Key? key,
    required this.order,
    required this.driverId,
  }) : super(key: key);

  @override
  State<TrackingUserCustomPage> createState() => _TrackingUserCustomPageState();
}

class _TrackingUserCustomPageState extends State<TrackingUserCustomPage> {
  // ── Original logic state (PRESERVED) ──────────────────────────────────────
  Position? _position;
  Timer? _timer;
  String _status = 'on_the_way';
  bool _sending = false;

  // ── New: form state (ported from website) ─────────────────────────────────
  bool _showForm = false;
  bool _loadingPrice = true;
  bool _submitting = false;
  Map<String, List<_HargaItem>> _hargaList = {
    'organik': [],
    'anorganik': [],
    'lainnya': [],
  };
  // sampahData[kategori][itemId] = _SampahEntry
  Map<String, Map<int, _SampahEntry>> _sampahData = {
    'organik': {},
    'anorganik': {},
    'lainnya': {},
  };
  double _totalBerat = 0;
  double _totalHarga = 0;

  // ── Category collapse state ────────────────────────────────────────────────
  final Map<String, bool> _categoryOpen = {
    'organik': true,
    'anorganik': true,
    'lainnya': true,
  };

  @override
  void initState() {
    super.initState();
    _startWorkflow();
    _fetchPrices();
    // If order already arrived, show form immediately
    final orderStatus = widget.order.status ?? '';
    if (orderStatus == 'arrived' || orderStatus == 'completed') {
      _status = orderStatus.isNotEmpty ? orderStatus : 'arrived';
      _showForm = true;
    }
  }

  // ── Original business logic (PRESERVED, UNCHANGED) ────────────────────────
  Future<void> _startWorkflow() async {
    await _requestLocationPermission();
    await _updateOrderStatus('on_the_way');
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _sendLocation());
  }

  Future<void> _requestLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied)
      p = await Geolocator.requestPermission();
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _position = pos);
      final token = await SecureStorageHelper.getToken();
      if (token == null || token.isEmpty) return;
      await http.post(
        Uri.parse('$_backendBaseUrl/driver/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'driver_id': widget.driverId,
          'order_id': widget.order.id,
          'lat': pos.latitude,
          'lng': pos.longitude,
        }),
      );
    } catch (e) {}
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      final token = await SecureStorageHelper.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi login telah berakhir. Silakan login ulang.'),
            ),
          );
        }
        return;
      }
      final resp = await http.patch(
        Uri.parse('$_backendBaseUrl/orders/status/${widget.order.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'driver_id': widget.driverId, 'status': newStatus}),
      );
      final data = jsonDecode(resp.body);
      final msg = data['message']?.toString().toLowerCase() ?? '';
      if (resp.statusCode == 200 &&
          (data['status'] == 'success' || msg.contains('berhasil'))) {
        if (mounted) setState(() => _status = newStatus);
      } else if (resp.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Token tidak valid. Silakan login ulang.'),
            ),
          );
          await SecureStorageHelper.deleteToken();
        }
      }
    } catch (e) {}
  }

  // ── New: fetch price list (ported from website hargaAPI) ──────────────────
  Future<void> _fetchPrices() async {
    final kategoris = ['organik', 'anorganik', 'lainnya'];
    try {
      final token = await SecureStorageHelper.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _loadingPrice = false);
        return;
      }
      final Map<String, List<_HargaItem>> prices = {};
      for (final kat in kategoris) {
        try {
          final resp = await http.get(
            Uri.parse('$_backendBaseUrl/harga/$kat'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
          if (resp.statusCode == 200) {
            final List<dynamic> raw = jsonDecode(resp.body) is List
                ? jsonDecode(resp.body)
                : (jsonDecode(resp.body)['data'] ?? []);
            prices[kat] = raw.map((e) => _HargaItem.fromJson(e)).toList();
          } else {
            prices[kat] = [];
          }
        } catch (_) {
          prices[kat] = [];
        }
      }
      // Initialize sampahData entries
      final Map<String, Map<int, _SampahEntry>> initialized = {};
      for (final kat in kategoris) {
        initialized[kat] = {};
        for (final item in prices[kat]!) {
          initialized[kat]![item.id] = _SampahEntry(harga: item.harga);
        }
      }
      if (mounted) {
        setState(() {
          _hargaList = prices;
          _sampahData = initialized;
          _loadingPrice = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPrice = false);
    }
  }

  // ── New: mark arrived inline (ported from website handlePetugasSampai) ─────
  Future<void> _markArrived() async {
    try {
      final token = await SecureStorageHelper.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi login telah berakhir.')),
          );
        }
        return;
      }
      final resp = await http.patch(
        Uri.parse('$_backendBaseUrl/orders/status/${widget.order.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'driver_id': widget.driverId, 'status': 'arrived'}),
      );
      final data = jsonDecode(resp.body);
      final msg = data['message']?.toString().toLowerCase() ?? '';
      if (resp.statusCode == 200 &&
          (data['status'] == 'success' || msg.contains('berhasil'))) {
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _status = 'arrived';
            _showForm = true;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Tiba di lokasi')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Gagal update status')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal update status: $e')));
      }
    }
  }

  // ── New: input change handler ──────────────────────────────────────────────
  void _handleInputChange(String kategori, int itemId, String value) {
    final num = double.tryParse(value) ?? 0.0;
    setState(() {
      _sampahData[kategori]![itemId]!.berat = num;
      _recalcTotals();
    });
  }

  void _recalcTotals() {
    double totalB = 0, totalH = 0;
    _sampahData.forEach((kat, items) {
      items.forEach((id, entry) {
        totalB += entry.berat;
        totalH += entry.berat * entry.harga;
      });
    });
    _totalBerat = totalB;
    _totalHarga = totalH;
  }

  // ── New: submit sampah (ported from website handleSubmitSampah) ────────────
  Future<void> _submitSampah() async {
    setState(() => _submitting = true);
    try {
      final token = await SecureStorageHelper.getToken();
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi login telah berakhir.')),
        );
        setState(() => _submitting = false);
        return;
      }

      // Build sampah_data payload matching website structure
      final Map<String, dynamic> sampahPayload = {};
      _sampahData.forEach((kat, items) {
        final Map<String, dynamic> katMap = {};
        items.forEach((id, entry) {
          katMap[id.toString()] = {'berat': entry.berat, 'harga': entry.harga};
        });
        sampahPayload[kat] = katMap;
      });

      final resp = await http.patch(
        Uri.parse('$_backendBaseUrl/orders/status/${widget.order.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'driver_id': widget.driverId,
          'status': 'completed',
          'sampah_data': sampahPayload,
          'total_berat': _totalBerat,
          'total_harga': _totalHarga,
        }),
      );
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Data sampah berhasil dikirim ke admin untuk konfirmasi!',
              ),
            ),
          );
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Gagal mengirim data')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim data: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final center =
        (widget.order.userLat != null && widget.order.userLng != null)
        ? LatLng(widget.order.userLat!, widget.order.userLng!)
        : const LatLng(-7.8, 110.3);

    final isSmall = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: isSmall
            ? _buildMobileLayout(center)
            : _buildDesktopLayout(center),
      ),
    );
  }

  // ─── Mobile Layout: map on top, panel scrolls below ───────────────────────
  Widget _buildMobileLayout(LatLng center) {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.42,
          child: _buildMapSection(center),
        ),
        Expanded(child: _buildOrderPanel()),
      ],
    );
  }

  // ─── Desktop Layout: map left, panel right ────────────────────────────────
  Widget _buildDesktopLayout(LatLng center) {
    return Row(
      children: [
        Expanded(child: _buildMapSection(center)),
        SizedBox(width: 380, child: _buildOrderPanel()),
      ],
    );
  }

  // ─── Map Section ──────────────────────────────────────────────────────────
  Widget _buildMapSection(LatLng center) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(center: center, zoom: 14),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: [
                // User location (red pin)
                Marker(
                  point: center,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
                // Driver location (blue circle)
                if (_position != null)
                  Marker(
                    point: LatLng(_position!.latitude, _position!.longitude),
                    width: 40,
                    height: 40,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _blue.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Floating header (gradient top overlay)
        Positioned(top: 0, left: 0, right: 0, child: _buildMapHeader()),

        // Status badge — bottom center
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(child: _buildStatusBadge()),
        ),

        // Order chip — top right (below header)
        Positioned(top: 68, right: 14, child: _buildOrderChip()),

        // GPS debug chip — bottom left
        if (_position != null)
          Positioned(bottom: 62, left: 14, child: _buildGpsChip()),
      ],
    );
  }

  // ── Floating map header ────────────────────────────────────────────────────
  Widget _buildMapHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_green900.withOpacity(0.75), _green900.withOpacity(0.0)],
        ),
      ),
      child: Row(
        children: [
          _mapHeaderButton(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: _green800,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'K-TRASH Tracking',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Order #${widget.order.id} · Real-time',
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
              ],
            ),
          ),
          _mapHeaderButton(
            onTap: () => setState(() {}),
            child: const Icon(
              Icons.refresh_rounded,
              color: _green600,
              size: 17,
            ),
          ),
          const SizedBox(width: 8),
          _mapHeaderButton(
            onTap: () {},
            child: const Icon(
              Icons.person_outline_rounded,
              color: _green600,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapHeaderButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  // ── Map overlay chips ──────────────────────────────────────────────────────
  Widget _buildStatusBadge() {
    final cfg = _statusConfig[_status] ?? _statusConfig['assigned']!;
    final color = cfg['color'] as Color;
    final label = cfg['label'] as String;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: _green500.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _green500.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monitor_rounded, size: 11, color: _green600),
          const SizedBox(width: 4),
          Text(
            '#${widget.order.id}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _green700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _green900.withOpacity(0.7),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _green500.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'GPS ',
            style: TextStyle(
              color: _blue,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          Text(
            '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
            style: const TextStyle(
              color: _textXsoft,
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ─── Order Panel ──────────────────────────────────────────────────────────
  Widget _buildOrderPanel() {
    return Container(
      color: _panel,
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildCustomerCard(),
            ),

            // Stepper
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Progres Order'),
                  const SizedBox(height: 8),
                  _buildStepper(),
                ],
              ),
            ),

            // CTA: Arrived button (only when not yet arrived)
            if (!_showForm &&
                (_status == 'assigned' || _status == 'on_the_way'))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _buildArrivedButton(),
              ),

            // Completed banner (if completed but form not shown for some reason)
            if (_status == 'completed' && !_showForm)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _buildCompletedBanner(),
              ),

            // Sampah form (shows inline after arrived, matching website)
            if (_showForm) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Input Data Sampah'),
                    const SizedBox(height: 10),
                    _loadingPrice
                        ? _buildLoadingPrice()
                        : Column(
                            children: _hargaList.keys
                                .map(
                                  (kat) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildCategoryBlock(kat),
                                  ),
                                )
                                .toList(),
                          ),
                  ],
                ),
              ),

              // Summary + Submit
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: _buildSummaryCard(),
              ),
            ],

            if (!_showForm) const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Customer Card ────────────────────────────────────────────────────────
  Widget _buildCustomerCard() {
    final cfg = _statusConfig[_status] ?? _statusConfig['assigned']!;
    final statusColor = cfg['color'] as Color;
    final statusLabel = cfg['label'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: _green500.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_green500, _green700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _green500.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PELANGGAN',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _textXsoft,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.order.nama,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.order.alamat,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSoft,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: statusColor.withOpacity(0.26)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.35),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 1, color: _borderColor),
          ),

          // Driver row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_green400, _green600],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Center(
                  child: Icon(
                    Icons.engineering_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Petugas Sampah',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    Text(
                      'ID: ${widget.driverId}',
                      style: const TextStyle(fontSize: 10, color: _textSoft),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _greenGlow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderColor),
                ),
                child: Text(
                  'Order #${widget.order.id}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _green700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Stepper ──────────────────────────────────────────────────────────────
  Widget _buildStepper() {
    final cfg = _statusConfig[_status] ?? _statusConfig['assigned']!;
    final active = cfg['step'] as int;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: _green500.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final lineIndex = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: lineIndex < active
                      ? _green500
                      : Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }
          final idx = i ~/ 2;
          final done = idx < active;
          final isActive = idx == active;
          return Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_green500, _green700],
                          )
                        : null,
                    color: done
                        ? _green600
                        : isActive
                        ? null
                        : Colors.black.withOpacity(0.06),
                    border: Border.all(
                      color: done
                          ? _green600
                          : isActive
                          ? Colors.transparent
                          : Colors.black.withOpacity(0.1),
                      width: 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: _green500.withOpacity(0.18),
                              blurRadius: 8,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: _green400.withOpacity(0.35),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? Colors.white
                                  : Colors.black.withOpacity(0.2),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[idx],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive
                        ? FontWeight.w700
                        : done
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isActive
                        ? _green700
                        : done
                        ? _green600
                        : _textXsoft,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── Arrived Button ───────────────────────────────────────────────────────
  Widget _buildArrivedButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_green500, _green700],
          ),
          borderRadius: BorderRadius.circular(_radiusSm),
          boxShadow: [
            BoxShadow(
              color: _green500.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _markArrived,
          icon: const Icon(
            Icons.location_on_rounded,
            color: Colors.white,
            size: 18,
          ),
          label: const Text(
            'Petugas Sampai',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radiusSm),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Completed Banner ─────────────────────────────────────────────────────
  Widget _buildCompletedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _green500.withOpacity(0.08),
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: _borderColor),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: _green600, size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Order selesai — menunggu konfirmasi admin',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _green700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loading Price ────────────────────────────────────────────────────────
  Widget _buildLoadingPrice() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _green500,
              backgroundColor: _green500.withOpacity(0.15),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Memuat data harga...',
            style: TextStyle(color: _textSoft, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Category Block (matches website SampahCategoryBlock) ─────────────────
  Widget _buildCategoryBlock(String kategori) {
    final items = _hargaList[kategori] ?? [];
    final catColors = {
      'organik': _green500,
      'anorganik': _blue,
      'lainnya': _amber,
    };
    final color = catColors[kategori] ?? _green500;
    final isOpen = _categoryOpen[kategori] ?? true;

    double catTotal = 0;
    for (final item in items) {
      final entry = _sampahData[kategori]?[item.id];
      catTotal += (entry?.berat ?? 0) * item.harga;
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: color.withOpacity(0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _categoryOpen[kategori] = !isOpen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(_radiusSm),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    kategori[0].toUpperCase() + kategori.substring(1),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${items.length} jenis',
                    style: const TextStyle(
                      fontSize: 10,
                      color: _textSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (catTotal > 0)
                    Text(
                      'Rp ${_formatRupiah(catTotal)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _textSoft,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items
          if (isOpen)
            items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'Tidak ada jenis sampah',
                        style: const TextStyle(color: _textXsoft, fontSize: 12),
                      ),
                    ),
                  )
                : Column(
                    children: List.generate(items.length, (idx) {
                      final item = items[idx];
                      final entry = _sampahData[kategori]?[item.id];
                      final berat = entry?.berat ?? 0;
                      final sub = berat * item.harga;
                      return Container(
                        decoration: BoxDecoration(
                          border: idx > 0
                              ? const Border(
                                  top: BorderSide(color: Color(0x0A000000)),
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.subJenis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _text,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rp ${_formatRupiah(item.harga)}/kg',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _textSoft,
                                    ),
                                  ),
                                  if (sub > 0)
                                    Text(
                                      '=  Rp ${_formatRupiah(sub)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: color,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Weight input
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 72,
                                  height: 38,
                                  child: TextFormField(
                                    initialValue: berat > 0
                                        ? berat.toString()
                                        : '',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _text,
                                      fontFamily: 'monospace',
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: const TextStyle(
                                        color: _textXsoft,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                      isDense: true,
                                      filled: true,
                                      fillColor: _bg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(9),
                                        borderSide: BorderSide(
                                          color: berat > 0
                                              ? color.withOpacity(0.35)
                                              : Colors.black.withOpacity(0.1),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(9),
                                        borderSide: BorderSide(
                                          color: berat > 0
                                              ? color.withOpacity(0.35)
                                              : Colors.black.withOpacity(0.1),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(9),
                                        borderSide: BorderSide(
                                          color: color,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    onChanged: (v) => _handleInputChange(
                                      kategori,
                                      item.id,
                                      v,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'kg',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _textSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
        ],
      ),
    );
  }

  // ─── Summary Card (matches website SummaryCard) ────────────────────────────
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _borderStrong),
        boxShadow: [
          BoxShadow(
            color: _green500.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Totals row
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL BERAT',
                        style: TextStyle(
                          fontSize: 10,
                          color: _textSoft,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _totalBerat.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _green700,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const TextSpan(
                              text: ' kg',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _green500,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, color: _borderColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'TOTAL ESTIMASI',
                          style: TextStyle(
                            fontSize: 10,
                            color: _textSoft,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          textAlign: TextAlign.right,
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Rp ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _green700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              TextSpan(
                                text: _formatRupiah(_totalHarga),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _green700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _submitting || _loadingPrice
                      ? [_green500.withOpacity(0.5), _green700.withOpacity(0.5)]
                      : [_green500, _green700],
                ),
                borderRadius: BorderRadius.circular(_radiusSm),
                boxShadow: (_submitting || _loadingPrice)
                    ? []
                    : [
                        BoxShadow(
                          color: _green500.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: (_submitting || _loadingPrice)
                    ? null
                    : _submitSampah,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radiusSm),
                  ),
                ),
                child: _submitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Mengirim...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Kirim ke Admin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
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

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _textSoft,
        letterSpacing: 1.0,
      ),
    );
  }

  String _formatRupiah(double value) {
    // Format as Indonesian number: 1.234.567
    final str = value.toStringAsFixed(0);
    final buf = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(str[i]);
      count++;
    }
    return buf.toString().split('').reversed.join('');
  }
}
