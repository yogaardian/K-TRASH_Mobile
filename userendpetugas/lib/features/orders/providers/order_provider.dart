import 'package:flutter/foundation.dart';
import 'package:user/services/order_service.dart';
import 'package:user/shared/models/order_model.dart';
import 'package:user/shared/models/waste_item_model.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _orderService = OrderService();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  OrderModel? _currentOrder;
  
  // Pickup state
  double? _pickupLat;
  double? _pickupLng;
  String _address = '';
  String _notes = '';
  
  // Waste selection state
  final List<WasteItemModel> _selectedWaste = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  OrderModel? get currentOrder => _currentOrder;
  
  double? get pickupLat => _pickupLat;
  double? get pickupLng => _pickupLng;
  String get address => _address;
  String get notes => _notes;
  
  List<WasteItemModel> get selectedWaste => List.unmodifiable(_selectedWaste);

  int get totalItems => _selectedWaste.length;

  // ===================== PICKUP METHODS =====================
  
  /// Set pickup location and address
  void setPickupLocation({
    required double latitude,
    required double longitude,
    required String address,
    String notes = '',
  }) {
    _pickupLat = latitude;
    _pickupLng = longitude;
    _address = address;
    _notes = notes;
    _errorMessage = null;
    notifyListeners();
  }

  /// Update address
  void updateAddress(String newAddress) {
    _address = newAddress;
    notifyListeners();
  }

  /// Update notes
  void updateNotes(String newNotes) {
    _notes = newNotes;
    notifyListeners();
  }

  /// Clear pickup data
  void clearPickup() {
    _pickupLat = null;
    _pickupLng = null;
    _address = '';
    _notes = '';
    notifyListeners();
  }

  // ===================== WASTE SELECTION METHODS =====================

  /// Add waste item to selection
  void addWasteItem(WasteItemModel item) {
    final existing = _selectedWaste.indexWhere((w) => w.id == item.id);
    if (existing < 0) {
      _selectedWaste.add(item);
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Remove waste item from selection
  void removeWasteItem(int wasteId) {
    _selectedWaste.removeWhere((w) => w.id == wasteId);
    notifyListeners();
  }

  /// Clear all waste items
  void clearWaste() {
    _selectedWaste.clear();
    notifyListeners();
  }

  // ===================== ORDER CREATION =====================

  /// Create order using collected data
  /// Calls: POST /orders with all pickup + waste data
  Future<bool> createOrder(int userId) async {
    // Validate data
    if (_pickupLat == null || _pickupLng == null) {
      _errorMessage = 'Lokasi pickup belum diatur';
      notifyListeners();
      return false;
    }
    
    if (_address.trim().isEmpty) {
      _errorMessage = 'Alamat tidak boleh kosong';
      notifyListeners();
      return false;
    }
    
    if (_selectedWaste.isEmpty) {
      _errorMessage = 'Pilih minimal satu jenis sampah';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Build payload
      final payload = {
        'user_id': userId,
        'address': _address,
        'user_lat': _pickupLat,
        'user_lng': _pickupLng,
        'jenis_sampah': _selectedWaste.map((w) => w.name).join(', '),
        'catatan': _notes.isNotEmpty ? _notes : null,
      };

      // DEBUG: Log request payload
      print('=== ORDER CREATION REQUEST ===');
      print('POST /orders');
      print('Payload: $payload');
      print('=============================');

      // Create order
      final order = await _orderService.createOrder(payload);
      
      // DEBUG: Log response
      print('=== ORDER CREATION RESPONSE ===');
      print('Status: Success');
      print('Order ID: ${order.id}');
      print('Order Status: ${order.status}');
      print('Created At: ${order.createdAt}');
      print('Full Response: $order');
      print('================================');
      
      _currentOrder = order;
      _errorMessage = null;
      return true;
    } catch (e) {
      // DEBUG: Log error
      print('=== ORDER CREATION ERROR ===');
      print('Error: $e');
      print('=============================');
      
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _currentOrder = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===================== DATA FORMATTING =====================

  /// Set current order (used when fetching order details)
  void setCurrentOrder(OrderModel order) {
    _currentOrder = order;
    notifyListeners();
  }

  /// Fetch a single order detail by ID
  Future<void> fetchOrderDetail(int orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _orderService.getOrderById(orderId);
      _currentOrder = order;
      _errorMessage = null;
    } catch (e) {
      _currentOrder = null;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get waste summary as text
  String getWasteSummary() {
    if (_selectedWaste.isEmpty) return 'Belum ada sampah';
    return _selectedWaste.map((w) => w.name).join(', ');
  }

  // ===================== RESET =====================

  /// Reset all data (for new order)
  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _currentOrder = null;
    _pickupLat = null;
    _pickupLng = null;
    _address = '';
    _notes = '';
    _selectedWaste.clear();
    notifyListeners();
  }
}
