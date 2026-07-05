import 'package:flutter/material.dart';
import 'package:user/services/tracking_service.dart';

class TrackingProvider extends ChangeNotifier {
  final TrackingService _trackingService = TrackingService();

  bool _isLoading = false;
  String? _errorMessage;

  bool _isDriverLoading = false;
  String? _driverErrorMessage;

  dynamic _driverPosition;
  dynamic _userPosition;
  String? _orderStatus;
  String? _driverName;
  String? _driverPhone;

  String _distanceText = '-';
  String _durationText = '-';
  String _driverDistanceText = '-';
  String _driverDurationText = '-';

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isDriverLoading => _isDriverLoading;
  String? get driverErrorMessage => _driverErrorMessage;
  dynamic get driverPosition => _driverPosition;
  dynamic get userPosition => _userPosition;
  String? get orderStatus => _orderStatus;
  String? get driverName => _driverName;
  String? get driverPhone => _driverPhone;
  String get distanceText => _distanceText;
  String get durationText => _durationText;
  String get driverDistanceText => _driverDistanceText;
  String get driverDurationText => _driverDurationText;

  void contactDriver() {
    // Placeholder for contact driver action.
  }

  Future<void> startTracking(int orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final raw = await _trackingService.getTracking(orderId);
      _orderStatus = raw['status']?.toString();
      _driverName = raw['driver_name']?.toString();
      _driverPhone = raw['driver_phone']?.toString();
      _distanceText = raw['distance_text']?.toString() ?? '-';
      _durationText = raw['duration_text']?.toString() ?? '-';
      _driverDistanceText = raw['driver_distance_text']?.toString() ?? _distanceText;
      _driverDurationText = raw['driver_duration_text']?.toString() ?? _durationText;

      _setLocationsFromRaw(raw);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startDriverTracking(int orderId) async {
    _isDriverLoading = true;
    _driverErrorMessage = null;
    notifyListeners();

    try {
      final raw = await _trackingService.getTracking(orderId);
      _orderStatus = raw['status']?.toString();
      _driverName = raw['driver_name']?.toString();
      _driverPhone = raw['driver_phone']?.toString();
      _driverDistanceText = raw['driver_distance_text']?.toString() ?? '-';
      _driverDurationText = raw['driver_duration_text']?.toString() ?? '-';

      _setLocationsFromRaw(raw);
    } catch (e) {
      _driverErrorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isDriverLoading = false;
      notifyListeners();
    }
  }

  void _setLocationsFromRaw(Map<String, dynamic> raw) {
    final driverLat = raw['driver_lat'] is num ? (raw['driver_lat'] as num).toDouble() : null;
    final driverLng = raw['driver_lng'] is num ? (raw['driver_lng'] as num).toDouble() : null;
    final userLat = raw['user_lat'] is num ? (raw['user_lat'] as num).toDouble() : null;
    final userLng = raw['user_lng'] is num ? (raw['user_lng'] as num).toDouble() : null;

    if (driverLat != null && driverLng != null) {
      _driverPosition = {'latitude': driverLat, 'longitude': driverLng};
    }

    if (userLat != null && userLng != null) {
      _userPosition = {'latitude': userLat, 'longitude': userLng};
    }
  }
}
