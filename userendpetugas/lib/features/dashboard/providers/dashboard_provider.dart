import 'package:flutter/foundation.dart';
import 'package:user/services/api_service.dart';
import 'package:user/services/order_service.dart';
import 'package:user/services/user_service.dart';
import 'package:user/shared/models/order_model.dart';

class DashboardProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  final OrderService _orderService = OrderService();

  // State
  bool _isLoading = false;
  double _balance = 0.0;
  double _availableBalance = 0.0;
  double _holdBalance = 0.0;
  List<OrderModel> _recentOrders = [];
  List<HargaItem> _hargaSampah = [];
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  double get balance => _balance;
  double get availableBalance => _availableBalance;
  double get holdBalance => _holdBalance;
  List<OrderModel> get recentOrders => _recentOrders;
  List<HargaItem> get hargaSampah => _hargaSampah;
  String? get errorMessage => _errorMessage;
  int get totalOrders => _recentOrders.length;

  /// Load dashboard data (balance and recent orders)
  /// Calls both GET /user/balance/:id and GET /orders/user/:id
  Future<void> loadDashboard(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('[DASHBOARD] Loading dashboard for user: $userId');
      
      final results = await Future.wait([
        _userService.getUserData(userId),
        _orderService.getRecentOrders(userId),
      ]);

      final userData = results[0] as Map<String, dynamic>;
      final recentOrders = results[1] as List<OrderModel>;

      final saldo = (userData['saldo'] ?? userData['balance'] ?? userData['total_balance'] ?? 0) as num;
      final holdBalance = (userData['saldo_hold'] ?? userData['hold_balance'] ?? userData['saldoHold'] ?? 0) as num;
      final availableBalance = (userData['available_balance'] ?? userData['availableBalance'] ?? saldo - holdBalance) as num;

      _balance = saldo.toDouble();
      _availableBalance = availableBalance.toDouble();
      _holdBalance = holdBalance.toDouble();
      _recentOrders = recentOrders;
      _hargaSampah = await _fetchHargaSampah();
      _errorMessage = null;
      
      print('[DASHBOARD] Loaded successfully');
      print('[BALANCE] Rp ${_balance.toStringAsFixed(0)}');
      print('[AVAILABLE] Rp ${_availableBalance.toStringAsFixed(0)}');
      print('[HOLD] Rp ${_holdBalance.toStringAsFixed(0)}');
      print('[ORDERS] Count: ${_recentOrders.length}');
      _recentOrders.forEach((order) {
        print('[ORDER] ID: ${order.id}, Status: ${order.status}, Created: ${order.createdAt}');
      });
    } catch (e) {
      print('[DASHBOARD_ERROR] $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _balance = 0.0;
      _availableBalance = 0.0;
      _holdBalance = 0.0;
      _recentOrders = [];
      _hargaSampah = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh dashboard data
  Future<void> refresh(int userId) async {
    print('[DASHBOARD_REFRESH] Refreshing for user: $userId');
    await loadDashboard(userId);
  }

  /// Format balance to Indonesian currency
  String getFormattedBalance() {
    return _formatCurrency(_balance);
  }

  String getFormattedAvailableBalance() {
    return _formatCurrency(_availableBalance);
  }

  String getFormattedHoldBalance() {
    return _formatCurrency(_holdBalance);
  }

  String _formatCurrency(double value) {
    return 'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')}';
  }

  /// Get order status label in Indonesian
  String getStatusLabel(String status) {
    const statusMap = {
      'pending': 'Menunggu',
      'searching_driver': 'Mencari Driver',
      'assigned': 'Driver Ditugaskan',
      'on_the_way': 'Dalam Perjalanan',
      'arrived': 'Tiba',
      'completed': 'Selesai',
      'cancelled': 'Dibatalkan',
    };
    return statusMap[status] ?? status;
  }

  /// Get order status color
  String getStatusColor(String status) {
    const colorMap = {
      'pending': '0xFFFFA500', // Orange
      'searching_driver': '0xFF1E90FF', // Blue
      'assigned': '0xFF32CD32', // Green
      'on_the_way': '0xFF9370DB', // Purple
      'arrived': '0xFF00CED1', // Cyan
      'completed': '0xFF228B22', // Dark Green
      'cancelled': '0xFFDC143C', // Crimson
    };
    return colorMap[status] ?? '0xFF808080'; // Default gray
  }

  Future<List<HargaItem>> _fetchHargaSampah() async {
    const jenisCandidates = ['anorganik', 'organik', 'plastik', 'kertas'];

    for (final jenis in jenisCandidates) {
      try {
        final result = await ApiService.getHarga(jenis);
        final items = result
            .whereType<Map<String, dynamic>>()
            .map((item) => HargaItem.fromMap(item, kategori: jenis))
            .toList();

        if (items.isNotEmpty) {
          return items;
        }
      } catch (e) {
        if (kDebugMode) {
          print('[DASHBOARD] Harga load failed for $jenis: $e');
        }
      }
    }

    return [];
  }
}

class HargaItem {
  final String subJenis;
  final double harga;
  final String? kategori;

  const HargaItem({required this.subJenis, required this.harga, this.kategori});

  factory HargaItem.fromMap(Map<String, dynamic> map, {String? kategori}) {
    final rawHarga = map['harga'] ?? map['price'] ?? 0;
    return HargaItem(
      subJenis: map['sub_jenis'] as String? ??
          map['subJenis'] as String? ??
          map['nama'] as String? ??
          'Unknown',
      harga: (rawHarga as num?)?.toDouble() ?? 0,
      kategori: kategori ?? map['jenis'] as String?,
    );
  }
}
