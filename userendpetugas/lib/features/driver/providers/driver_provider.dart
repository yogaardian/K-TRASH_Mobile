import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class DriverProvider extends ChangeNotifier {
  bool _isOnline = false;
  Position? _driverLocation;
  int? _activeOrderId;
  Map<String, dynamic>? _activeOrder;
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  bool get isOnline => _isOnline;
  Position? get driverLocation => _driverLocation;
  int? get activeOrderId => _activeOrderId;
  Map<String, dynamic>? get activeOrder => _activeOrder;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  // Set online status
  void setOnlineStatus(bool status) {
    _isOnline = status;
    notifyListeners();
  }

  // Set driver location
  void setDriverLocation(Position position) {
    _driverLocation = position;
    notifyListeners();
  }

  // Set active order
  void setActiveOrder(int orderId, Map<String, dynamic> orderData) {
    _activeOrderId = orderId;
    _activeOrder = orderData;
    _errorMessage = null;
    notifyListeners();
  }

  // Clear active order
  void clearActiveOrder() {
    _activeOrderId = null;
    _activeOrder = null;
    notifyListeners();
  }

  // Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Reset provider
  void reset() {
    _isOnline = false;
    _driverLocation = null;
    _activeOrderId = null;
    _activeOrder = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
