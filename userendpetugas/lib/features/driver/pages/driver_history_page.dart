import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/api_service.dart';
import '../../../utils/secure_storage_helper.dart';

class DriverHistoryPage extends StatefulWidget {
  const DriverHistoryPage({super.key});

  @override
  State<DriverHistoryPage> createState() => _DriverHistoryPageState();
}

class _DriverHistoryPageState extends State<DriverHistoryPage> {
  bool _loading = true;
  String? _errorMessage;
  List<_DriverOrderHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadDriverHistory();
  }

  Future<void> _loadDriverHistory() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final token = await SecureStorageHelper.getToken();
      final userJson = await SecureStorageHelper.getUserData();

      if (token == null ||
          token.isEmpty ||
          userJson == null ||
          userJson.isEmpty) {
        throw Exception(
          'Token atau data pengguna tidak tersedia. Silakan login ulang.',
        );
      }

      final userData = _parseStoredUserData(userJson);
      if (userData == null) {
        throw Exception('Data pengguna tidak valid. Silakan login ulang.');
      }

      final driverId = _parseUserId(userData);

      if (driverId == null) {
        throw Exception('Driver ID tidak valid.');
      }

      final response = await ApiService.getDriverOrders(driverId, token);
      final driverOrders = response.whereType<Map<String, dynamic>>().where((
        item,
      ) {
        final rawDriverId = item['driver_id'] ?? item['driverId'];
        if (rawDriverId is int) return rawDriverId == driverId;
        if (rawDriverId is String) return int.tryParse(rawDriverId) == driverId;
        return true;
      }).toList();

      setState(() {
        _history = driverOrders
            .map((item) => _DriverOrderHistoryItem.fromJson(item))
            .toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
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
      backgroundColor: const Color(0xffF7F1F1),
      appBar: AppBar(
        title: const Text('Riwayat Order Petugas'),
        backgroundColor: const Color(0xFF4CAF50),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDriverHistory,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 250),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _errorMessage != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [_buildErrorState()],
              )
            : _history.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [_buildEmptyState()],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return _buildHistoryCard(item);
                },
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat memuat data.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadDriverHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history_rounded, size: 72, color: Colors.grey),
            SizedBox(height: 18),
            const Text(
              'Belum ada riwayat order.\nSilakan terima order dan mulai perjalanan untuk melihat aktivitas di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(_DriverOrderHistoryItem item) {
    return GestureDetector(
      onTap: () => _showOrderDetails(item),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: item.statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: item.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.address,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.jenisSampah,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    'Rp ${_formatRupiah(item.totalHarga)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.formattedDate,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(_DriverOrderHistoryItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Order #${item.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pelanggan: ${item.userName}'),
            const SizedBox(height: 6),
            Text('Alamat: ${item.address}'),
            const SizedBox(height: 6),
            Text('Jenis Sampah: ${item.jenisSampah}'),
            const SizedBox(height: 6),
            Text('Total Estimasi: Rp ${_formatRupiah(item.totalHarga)}'),
            const SizedBox(height: 6),
            Text('Status: ${item.statusLabel}'),
            const SizedBox(height: 6),
            Text('Waktu: ${item.formattedDate}'),
          ],
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

  String _formatRupiah(double value) {
    final str = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join('');
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

  int? _parseUserId(Map<String, dynamic> data) {
    final raw = data['id'] ?? data['user_id'] ?? data['userId'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}

class _DriverOrderHistoryItem {
  final int id;
  final String userName;
  final String address;
  final String status;
  final String jenisSampah;
  final double totalHarga;
  final DateTime createdAt;

  _DriverOrderHistoryItem({
    required this.id,
    required this.userName,
    required this.address,
    required this.status,
    required this.jenisSampah,
    required this.totalHarga,
    required this.createdAt,
  });

  factory _DriverOrderHistoryItem.fromJson(Map<String, dynamic> json) {
    double parseNumber(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String)
        return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
      return 0.0;
    }

    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return _DriverOrderHistoryItem(
      id: json['id'] as int? ?? 0,
      userName: json['user_name']?.toString() ?? 'Pelanggan',
      address: json['address']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'pending',
      jenisSampah: json['jenis_sampah']?.toString() ?? '-',
      totalHarga: parseNumber(json['total_harga']),
      createdAt: parseDate(json['created_at']),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'assigned':
        return 'Ditugaskan';
      case 'on_the_way':
        return 'Menuju Lokasi';
      case 'arrived':
        return 'Tiba';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Batal';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFF9CA3AF);
      case 'assigned':
        return const Color(0xFF3B82F6);
      case 'on_the_way':
        return const Color(0xFF2563EB);
      case 'arrived':
        return const Color(0xFFF59E0B);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF4B5563);
    }
  }

  String get formattedDate => DateFormat('dd MMM yyyy HH:mm').format(createdAt);
}
