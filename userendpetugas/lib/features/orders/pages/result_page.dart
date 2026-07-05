import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user/constants/route_constants.dart';
import 'package:user/features/tracking/pages/tracking_page.dart';
import 'package:user/features/orders/providers/order_provider.dart';

// ============================================================
// DESIGN TOKENS — tema lingkungan hidup modern
// ============================================================
class _AppColors {
  static const primary = Color(0xFF16A34A);
  static const secondary = Color(0xFF22C55E);
  static const accent = Color(0xFF4ADE80);
  static const background = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const errorBg = Color(0xFFFEF2F2);
  static const errorText = Color(0xFFDC2626);
}

class ResultPage extends StatefulWidget {
  final int? orderId;

  const ResultPage({super.key, this.orderId});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  // ------------------------------------------------------------
  // BUSINESS LOGIC — TIDAK DIUBAH
  // ------------------------------------------------------------
  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (widget.orderId == null) {
        throw Exception('Order ID tidak tersedia');
      }

      final orderProvider = context.read<OrderProvider>();
      await orderProvider.fetchOrderDetail(widget.orderId!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat detail pesanan';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: _buildAppBar(),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          final order = orderProvider.currentOrder;

          if (_loading) {
            return _buildLoadingState();
          }

          if (_errorMessage != null || order == null) {
            return _buildErrorState(_errorMessage);
          }

          return RefreshIndicator(
            color: _AppColors.primary,
            onRefresh: _loadOrder,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSuccessHero(context, order),
                  const SizedBox(height: 20),
                  _buildInfoCard(
                    context,
                    title: 'Detail Pesanan',
                    icon: Icons.receipt_long_rounded,
                    children: [
                      _buildDetailRow(
                        icon: Icons.flag_rounded,
                        label: 'Status',
                        value: order.status,
                        isBadge: true,
                      ),
                      _buildDivider(),
                      _buildDetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'Alamat',
                        value: order.address.isNotEmpty
                            ? order.address
                            : 'Tidak diketahui',
                      ),
                      _buildDivider(),
                      _buildDetailRow(
                        icon: Icons.delete_outline_rounded,
                        label: 'Sampah',
                        value: order.jenisSampah.isNotEmpty
                            ? order.jenisSampah
                            : 'Belum dipilih',
                      ),
                      _buildDivider(),
                      _buildDetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Tanggal',
                        value: order.createdAt != null
                            ? order.createdAt!.toLocal().toString()
                            : '-',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildActionButtons(context, order),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Hasil Pesanan',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: _AppColors.text,
        ),
      ),
      centerTitle: false,
      backgroundColor: _AppColors.background,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: _AppColors.text),
    );
  }

  // ============================================================
  // LOADING STATE
  // ============================================================
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: const AlwaysStoppedAnimation<Color>(
                _AppColors.primary,
              ),
              backgroundColor: _AppColors.primary.withOpacity(0.12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat detail pesanan...',
            style: TextStyle(
              color: _AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================
  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _AppColors.errorBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: _AppColors.errorText,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message ?? 'Pesanan tidak ditemukan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Silakan coba lagi dalam beberapa saat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _AppColors.muted,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loadOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Coba Lagi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUCCESS HERO CARD
  // ============================================================
  Widget _buildSuccessHero(BuildContext context, dynamic order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_AppColors.primary, _AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _AppColors.primary.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pesanan Berhasil Dibuat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Order #${order.id} sedang menunggu proses penjemputan',
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO CARD CONTAINER
  // ============================================================
  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _AppColors.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: _AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: _AppColors.border),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isBadge = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _AppColors.muted),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _AppColors.muted,
            ),
          ),
        ),
        Expanded(
          child: isBadge
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _AppColors.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _AppColors.primary,
                      ),
                    ),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _AppColors.text,
                  ),
                ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================
  Widget _buildActionButtons(BuildContext context, dynamic order) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrackingPage(orderId: order.id),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Lihat Tracking',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (order.status == 'completed' && (order.sampahData != null || order.totalBerat != null)) ...[
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteConstants.userDashboard,
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _AppColors.text,
                side: const BorderSide(color: _AppColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_outlined, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Kembali ke Dashboard',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}