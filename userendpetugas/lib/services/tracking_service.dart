import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../core/network/api_client.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  final ApiClient _apiClient = ApiClient();

  TrackingService._internal();

  factory TrackingService() {
    return _instance;
  }

  Future<Map<String, dynamic>> getTracking(int orderId) async {
    try {
      debugPrint('TrackingService.getTracking: fetching ${ApiConstants.getTrackingEndpoint}/$orderId');
      final response = await _apiClient.get('${ApiConstants.getTrackingEndpoint}/$orderId');
      debugPrint('TrackingService.getTracking: status=${response.statusCode}');
      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          return raw;
        }
        throw Exception('Unexpected tracking response format');
      }
      throw Exception('Failed to fetch tracking data');
    } on DioException catch (e) {
      throw Exception('Error fetching tracking data: ${_getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<bool> sendDriverLocation({
    required int driverId,
    required int orderId,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.sendDriverLocationEndpoint,
        data: {
          'driver_id': driverId,
          'order_id': orderId,
          'lat': lat,
          'lng': lng,
        },
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw Exception('Error sending driver location: ${_getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  String _getErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Server error: ${e.response?.statusCode}';
    } else if (e.type == DioExceptionType.unknown) {
      return 'Network error: ${e.message}';
    }
    return 'Unknown error';
  }
}
