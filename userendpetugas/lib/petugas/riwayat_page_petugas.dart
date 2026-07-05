import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:user/features/auth/providers/auth_provider.dart';
import '../services/order_service.dart';
import '../shared/models/order_model.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  final OrderService _orderService = OrderService();
  bool _isLoading = true;
  String? _errorMessage;
  List<OrderModel> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      setState(() {
        _errorMessage = 'Data pengguna tidak tersedia. S  ilakan login ulang.';
        _isLoading = false;
      });
      return;
    }

    try {
      final orders = await _orderService.getUserOrders(user.id);
      final filteredOrders = orders
          .where(
            (order) => order.userId == user.id || order.driverId == user.id,
          )
          .toList();

      filteredOrders.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.now();
        final bDate = b.createdAt ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      setState(() {
        _orders = filteredOrders.isNotEmpty ? filteredOrders : orders;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F1F1),
      appBar: AppBar(
        title: const Text('Riwayat Order Petugas'),
        backgroundColor: const Color(0xFF4CAF50),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorState()
            : _buildHistoryList(),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 72,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 18),
                Text(
                  'Gagal memuat riwayat',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Terjadi kesalahan saat memuat data.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loadHistory,
                  child: const Text('Muat ulang'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        children: [
          const Icon(Icons.history_rounded, size: 72, color: Colors.grey),
          const SizedBox(height: 18),
          Text(
            'Belum ada riwayat order',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Riwayat order akan muncul setelah Anda menangani atau membuat pesanan.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final order = _orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final createdAt = order.createdAt != null
        ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.createdAt!)
        : '-';
    final total = order.totalHarga != null
        ? 'Rp ${order.totalHarga!.toStringAsFixed(0).replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (match) => '.')}'
        : '-';
    final statusLabel = order.status.isNotEmpty ? order.status : 'pending';
    final driverLabel = order.driverId != null
        ? 'Petugas: ${order.driverId}'
        : 'Belum ditugaskan';

    return GestureDetector(
      onTap: () => _showOrderDetails(order),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order #${order.id}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildInfoColumn('Tanggal', createdAt),
                _buildInfoColumn('Total', total, alignEnd: true),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              driverLabel,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool alignEnd = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    final items = order.sampahData?.trim().isNotEmpty == true
        ? order.sampahData!
        : order.jenisSampah;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Order #${order.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${order.status}'),
              const SizedBox(height: 10),
              Text(
                'Tanggal: ${order.createdAt != null ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.createdAt!) : '-'}',
              ),
              const SizedBox(height: 10),
              Text('Alamat: ${order.address}'),
              const SizedBox(height: 10),
              Text('Jenis Sampah: $items'),
              if (order.totalBerat != null) ...[
                const SizedBox(height: 10),
                Text('Berat: ${order.totalBerat} Kg'),
              ],
              if (order.totalHarga != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Total Harga: Rp ${order.totalHarga!.toStringAsFixed(0).replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (match) => '.')}',
                ),
              ],
              if (order.catatan != null && order.catatan!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Catatan: ${order.catatan}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
