import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../shared/models/user_model.dart';
import '../utils/secure_storage_helper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  final ApiClient _apiClient = ApiClient();

  AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  // Login with email/username and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.loginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String?;
        final userJson = data['user'] as Map<String, dynamic>?;

        if (token != null && token.isNotEmpty && userJson != null) {
          // Save token to secure storage
          await SecureStorageHelper.saveToken(token);

          // Save user data
          await SecureStorageHelper.saveUserData(jsonEncode(userJson));

          return {
            'success': true,
            'token': token,
            'user': UserModel.fromJson(userJson),
            'message': data['message'] ?? 'Login successful',
          };
        }
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Login failed',
      };
    } on DioException catch (e) {
      // Check if error response contains pending_verification status
      if (e.response?.statusCode == 401 && e.response?.data != null) {
        final data = e.response!.data as Map<String, dynamic>?;
        if (data?['status'] == 'pending_verification') {
          return {
            'success': false,
            'status': 'pending_verification',
            'message': data?['message'] ?? 'Email belum diverifikasi',
            'email': data?['email'],
          };
        }
      }
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  // Register with user details
  Future<Map<String, dynamic>> register({
    required String nama,
    required String email,
    required String password,
    required String role,
    required String nomorHp,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.registerEndpoint,
        data: {
          'nama': nama,
          'email': email,
          'password': password,
          'role': role,
          'nomor_hp': nomorHp,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': true,
          'status': data['status'],
          'message': data['message'],
          'debugOtp': data['debugOtp'],
          'email': email,
        };
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Registration failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  // Verify registration with OTP
  Future<Map<String, dynamic>> verifyRegister({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.registerVerifyEndpoint,
        data: {
          'email': email,
          'otp': otp,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String?;
        final userJson = data['user'] as Map<String, dynamic>?;

        if (token != null && token.isNotEmpty && userJson != null) {
          await SecureStorageHelper.saveToken(token);
          await SecureStorageHelper.saveUserData(jsonEncode(userJson));

          return {
            'success': true,
            'token': token,
            'user': UserModel.fromJson(userJson),
            'message': data['message'] ?? 'Registration verified',
          };
        }
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Verification failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  // Resend OTP for registration
  Future<Map<String, dynamic>> resendRegisterOtp({
    required String email,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.registerResendOtpEndpoint,
        data: {
          'email': email,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': true,
          'message': data['message'],
          'debugOtp': data['debugOtp'],
        };
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Failed to resend OTP',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  // Validate token (check if still valid)
  Future<Map<String, dynamic>> validateToken() async {
    try {
      final response = await _apiClient.post(
        ApiConstants.validateTokenEndpoint,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['valid'] == true) {
          final userJson = data['user'] as Map<String, dynamic>?;
          if (userJson != null) {
            return {
              'valid': true,
              'user': UserModel.fromJson(userJson),
              'message': data['message'],
            };
          }
        }
      }

      return {
        'valid': false,
        'message': response.data['message'] ?? 'Token validation failed',
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await SecureStorageHelper.clearAll();
      }
      return {
        'valid': false,
        'message': _getErrorMessage(e),
      };
    } catch (e) {
      return {
        'valid': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await SecureStorageHelper.clearAll();
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // Google login using credential (idToken)
  Future<Map<String, dynamic>> googleLogin({
    required String credential,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.googleLoginEndpoint,
        data: {
          'credential': credential,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String?;
        final userJson = data['user'] as Map<String, dynamic>?;

        if (token != null && token.isNotEmpty && userJson != null) {
          await SecureStorageHelper.saveToken(token);
          await SecureStorageHelper.saveUserData(jsonEncode(userJson));

          return {
            'success': true,
            'token': token,
            'user': UserModel.fromJson(userJson),
            'message': data['message'] ?? 'Google login successful',
          };
        }
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Google login failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await SecureStorageHelper.hasToken();
  }

  // Get stored user data
  Future<UserModel?> getStoredUser() async {
    try {
      final userJson = await SecureStorageHelper.getUserData();
      if (userJson != null) {
        final json = jsonDecode(userJson) as Map<String, dynamic>;
        return UserModel.fromJson(json);
      }
    } catch (e) {
      print('Error getting stored user: $e');
    }
    return null;
  }

  // Helper method to get error message from DioException
  String _getErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Server response timeout. Please try again.';
    } else if (e.response != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] ?? 'An error occurred';
      }
      return 'An error occurred: ${e.response?.statusCode}';
    } else if (e.message != null) {
      return e.message!;
    }
    return 'An unexpected error occurred';
  }
}
