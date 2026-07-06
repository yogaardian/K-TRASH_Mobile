import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../../../petugas/models/order.dart';
import '../../../utils/secure_storage_helper.dart';
import '../providers/driver_provider.dart';
import 'tracking_user_custom_page.dart';

final String _backendBaseUrl = ApiConstants.baseUrl;

// ── Design tokens (ported from React T{}) ─────────────────────────────────────
class _T {
  static const green900 = Color(0xFF052e16);
  static const green800 = Color(0xFF14532d);
  static const green700 = Color(0xFF15803d);
  static const green600 = Color(0xFF16a34a);
  static const green500 = Color(0xFF22c55e);
  static const green400 = Color(0xFF4ade80);
  static const greenGlow = Color(0x2E22C55E);
  static const greenGlow2 = Color(0x1422C55E);
  static const surface = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF5F7F5);
  static const panel = Color(0xFFFAFFFE);
  static const border = Color(0x2622C55E);
  static const borderStrong = Color(0x4D22C55E);
  static const textPrimary = Color(0xFF0F172A);
  static const textMid = Color(0xFF334155);
  static const textSoft = Color(0xFF64748B);
  static const textXsoft = Color(0xFF94A3B8);
  static const amber = Color(0xFFF59E0B);
  static const amberGlow = Color(0x1FF59E0B);
  static const shadow = BoxShadow(
    color: Color(0x1022C55E),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  static const shadowMd = BoxShadow(
    color: Color(0x1F22C55E),
    blurRadius: 24,
    offset: Offset(0, 4),
  );
  static const radius = 20.0;
  static const radiusSm = 12.0;
}

class OrderDetailCustomPage extends StatefulWidget {
  final Order order;
  final int driverId;

  const OrderDetailCustomPage({
    Key? key,
    required this.order,
    required this.driverId,
  }) : super(key: key);

  @override
  State<OrderDetailCustomPage> createState() => _OrderDetailCustomPageState();
}

class _OrderDetailCustomPageState extends State<OrderDetailCustomPage> {
  final MapController _mapController = MapController();
  bool _submitting = false;

  // ── ORIGINAL LOGIC — NOT CHANGED ─────────────────────────────────────────
  Future<void> _acceptOrder() async {
    setState(() => _submitting = true);
    try {
      final token = await SecureStorageHelper.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi login telah berakhir. Silakan login ulang.'),
            ),
          );
          setState(() => _submitting = false);
        }
        return;
      }
      final resp = await http.patch(
        Uri.parse('$_backendBaseUrl/orders/accept/${widget.order.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'driver_id': widget.driverId}),
      );

      final data = jsonDecode(resp.body);
      final msg = data['message']?.toString().toLowerCase() ?? '';
      final ok =
          resp.statusCode == 200 &&
          (data['status'] == 'success' || msg.contains('berhasil'));

      if (ok) {
        try {
          Provider.of<DriverProvider>(
            context,
            listen: false,
          ).setActiveOrder(widget.order.id!, {
            'id': widget.order.id!,
            'nama': widget.order.nama,
            'alamat': widget.order.alamat,
          });
        } catch (_) {}

        final acceptedOrder = widget.order;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TrackingUserCustomPage(
              order: acceptedOrder,
              driverId: widget.driverId,
            ),
          ),
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Gagal menerima order')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
  // ── END ORIGINAL LOGIC ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final center =
        (widget.order.userLat != null && widget.order.userLng != null)
        ? LatLng(widget.order.userLat!, widget.order.userLng!)
        : const LatLng(-7.8, 110.3);

    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── MAP SECTION (with overlays) ──────────────────────────────
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(
                children: [
                  // Base map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: center,
                      zoom: 15,
                      minZoom: 5,
                      maxZoom: 18,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.banktrash.app',
                        tileProvider: NetworkTileProvider(),
                      ),
                      MarkerLayer(
                        markers: [
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
                        ],
                      ),
                    ],
                  ),

                  // ── Glassmorphic top header ────────────────────────────
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xC8052E16), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.94),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.14),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chevron_left,
                                color: _T.green800,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Title
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Tracking',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Pickup Preview',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Order ID chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: _T.border),
                              boxShadow: const [_T.shadow],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.monitor_outlined,
                                  size: 11,
                                  color: _T.green600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '#${widget.order.id}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _T.green700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Floating overlay card (bottom of map) ──────────────
                  Positioned(
                    bottom: 50,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _T.border),
                        boxShadow: const [_T.shadowMd],
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [_T.green500, _T.green700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _T.green500.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Name + address
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.order.nama,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _T.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.order.alamat,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: _T.textSoft,
                                    height: 1.4,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Pending badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _T.amberGlow,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: _T.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _T.amber,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _T.amber.withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _T.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Jenis sampah chip (bottom center) ─────────────────
                  if (widget.order.jenisSampah != null)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: _T.borderStrong),
                            boxShadow: const [_T.shadowMd],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                size: 12,
                                color: _T.green600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.order.jenisSampah!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _T.green700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── DETAIL PANEL ─────────────────────────────────────────────
            Expanded(
              child: Container(
                color: _T.panel,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Customer card ──────────────────────────────────
                      _CustomerCard(order: widget.order),
                      const SizedBox(height: 12),

                      // ── Stats row ──────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _StatChip(
                              icon: const Icon(
                                Icons.monitor_outlined,
                                size: 13,
                                color: _T.green600,
                              ),
                              label: 'Order ID',
                              value: '#${widget.order.id}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatChip(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 13,
                                color: _T.amber,
                              ),
                              label: 'Jenis',
                              value: widget.order.jenisSampah ?? '—',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Detail Order card ──────────────────────────────
                      const _SectionLabel('Detail Order'),
                      const SizedBox(height: 8),
                      _DetailCard(order: widget.order),
                      const SizedBox(height: 12),

                      // ── Location card ──────────────────────────────────
                      const _SectionLabel('Lokasi Pickup'),
                      const SizedBox(height: 8),
                      _LocationCard(order: widget.order),
                      const SizedBox(height: 20),

                      // ── Accept button ──────────────────────────────────
                      _AcceptButton(
                        submitting: _submitting,
                        onPressed: _acceptOrder,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final Order order;
  const _CustomerCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(_T.radius),
        border: Border.all(color: _T.border),
        boxShadow: const [_T.shadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with amber dot
          Stack(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [_T.green500, _T.green800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _T.green500.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 22),
              ),
              // Amber online dot
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _T.amber,
                    shape: BoxShape.circle,
                    border: Border.all(color: _T.panel, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _T.amber.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Name + address
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.nama,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _T.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: _T.green600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.alamat,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _T.textSoft,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final Widget icon;
  final String label;
  final String value;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(_T.radiusSm),
        border: Border.all(color: _T.border),
        boxShadow: const [_T.shadow],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _T.greenGlow2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _T.border),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: _T.textXsoft,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _T.textPrimary,
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _T.textSoft,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Order order;
  const _DetailCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(_T.radius),
        border: Border.all(color: _T.border),
        boxShadow: const [_T.shadow],
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Kode Customer', value: '#${order.id}', accent: true),
          const Divider(
            height: 1,
            thickness: 1,
            color: _T.border,
            indent: 16,
            endIndent: 16,
          ),
          _InfoRow(label: 'Jenis Sampah', value: order.jenisSampah ?? '—'),
          const Divider(
            height: 1,
            thickness: 1,
            color: _T.border,
            indent: 16,
            endIndent: 16,
          ),
          _InfoRow(label: 'Status', value: 'Pending', statusChip: true),
          if (order.catatan != null && order.catatan!.isNotEmpty) ...[
            const Divider(
              height: 1,
              thickness: 1,
              color: _T.border,
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CATATAN',
                    style: TextStyle(
                      fontSize: 9,
                      color: _T.textXsoft,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    order.catatan!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _T.textMid,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  final bool statusChip;
  const _InfoRow({
    required this.label,
    required this.value,
    this.accent = false,
    this.statusChip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _T.textSoft)),
          if (statusChip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _T.amberGlow,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: _T.amber.withOpacity(0.3)),
              ),
              child: const Text(
                'Pending',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _T.amber,
                ),
              ),
            )
          else
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent ? _T.green700 : _T.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final Order order;
  const _LocationCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasCoords = order.userLat != null && order.userLng != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(_T.radius),
        border: Border.all(color: _T.border),
        boxShadow: const [_T.shadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _T.greenGlow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _T.borderStrong),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: _T.green600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.alamat,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _T.textPrimary,
                    height: 1.5,
                  ),
                ),
                if (hasCoords) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${order.userLat!.toStringAsFixed(5)}, '
                    '${order.userLng!.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: _T.textXsoft,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  final bool submitting;
  final VoidCallback onPressed;
  const _AcceptButton({required this.submitting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_T.radiusSm),
          gradient: submitting
              ? const LinearGradient(
                  colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF66B282),
                    Color(0xFF15803D),
                    Color(0xFF14532D),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
          boxShadow: submitting
              ? []
              : [
                  BoxShadow(
                    color: _T.green500.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: submitting ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_T.radiusSm),
            ),
          ),
          child: submitting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Memproses...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Ambil Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
