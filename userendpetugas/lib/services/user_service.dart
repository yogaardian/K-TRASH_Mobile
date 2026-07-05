import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../shared/models/user_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();

  final ApiClient _apiClient = ApiClient();

  UserService._internal();

  factory UserService() {
    return _instance;
  }

  /// Get user balance from backend
  /// Endpoint: GET /user/balance/:id
  Future<double> getUserBalance(int userId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.getUserBalanceEndpoint}/$userId',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final balance = data['saldo'] as num?;
        return (balance ?? 0).toDouble();
      }

      throw Exception('Failed to fetch user balance');
    } on DioException catch (e) {
      throw Exception('Error fetching balance: ${_getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Update user profile
  /// Endpoint: PATCH /users/:id
  Future<UserModel> updateProfile({
    required int userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _apiClient.patch(
        '${ApiConstants.updateUserEndpoint}/$userId',
        data: data,
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'] as Map<String, dynamic>;
        return UserModel.fromJson(userData);
      }

      throw Exception('Failed to update profile');
    } on DioException catch (e) {
      throw Exception('Error updating profile: ${_getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Get full user data including balance and hold
  /// Endpoint: GET /user/balance/:id
  Future<Map<String, dynamic>> getUserData(int userId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.getUserBalanceEndpoint}/$userId',
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }

      throw Exception('Failed to fetch user data');
    } on DioException catch (e) {
      throw Exception('Error fetching user data: ${_getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  String _getErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Receive timeout';
    } else if (e.type == DioExceptionType.badResponse) {
      return 'Server error: ${e.response?.statusCode}';
    } else if (e.type == DioExceptionType.unknown) {
      return 'Network error: ${e.message}';
    }
    return 'Unknown error';
  }
}
