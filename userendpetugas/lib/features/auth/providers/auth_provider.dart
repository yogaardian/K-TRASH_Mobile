import 'package:flutter/foundation.dart';
import '../../../services/auth_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../utils/secure_storage_helper.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  String? _token;
  String? _pendingVerificationEmail;

  // Getters
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get token => _token;
  String? get pendingVerificationEmail => _pendingVerificationEmail;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  // Initialize auth state on app launch
  Future<void> initializeAuth() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await SecureStorageHelper.getToken();
      if (token == null || token.isEmpty) {
        _status = AuthStatus.unauthenticated;
        _user = null;
        _token = null;
      } else {
        final result = await _authService.validateToken();
        if (result['valid'] == true && result['user'] is UserModel) {
          _token = token;
          _user = result['user'] as UserModel;
          _status = AuthStatus.authenticated;
          _errorMessage = null;
        } else {
          await SecureStorageHelper.clearAll();
          _status = AuthStatus.unauthenticated;
          _user = null;
          _token = null;
          _errorMessage = result['message'] as String?;
        }
      }
    } catch (e) {
      _status = AuthStatus.error;
      _user = null;
      _token = null;
      _errorMessage = 'Failed to initialize authentication';
    }

    notifyListeners();
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _pendingVerificationEmail = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        _token = result['token'] as String?;
        _user = result['user'] as UserModel?;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        _pendingVerificationEmail = null;
        notifyListeners();
        return true;
      } else if (result['status'] == 'pending_verification') {
        // Email registered but not yet verified
        _status = AuthStatus.unauthenticated;
        _pendingVerificationEmail = result['email'] as String?;
        _errorMessage = result['message'] as String? ?? 'Email belum diverifikasi';
        notifyListeners();
        return false;
      } else {
        _status = AuthStatus.error;
        _errorMessage = result['message'] as String? ?? 'Login failed';
        _pendingVerificationEmail = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred during login';
      _pendingVerificationEmail = null;
      notifyListeners();
      return false;
    }
  }

  // Google login
  Future<bool> googleLogin({required String credential}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _pendingVerificationEmail = null;
    notifyListeners();

    try {
      final result = await _authService.googleLogin(credential: credential);

      if (result['success'] == true) {
        _token = result['token'] as String?;
        _user = result['user'] as UserModel?;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        _pendingVerificationEmail = null;
        notifyListeners();
        return true;
      }

      _status = AuthStatus.error;
      _errorMessage = result['message'] as String? ?? 'Google login failed';
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred during Google login';
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String nama,
    required String email,
    required String password,
    required String role,
    required String nomorHp,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        nama: nama,
        email: email,
        password: password,
        role: role,
        nomorHp: nomorHp,
      );

      if (result['success'] == true) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.error;
        _errorMessage = result['message'] as String? ?? 'Registration failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred during registration';
      notifyListeners();
      return false;
    }
  }

  // Verify registration with OTP
  Future<bool> verifyRegister({
    required String email,
    required String otp,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyRegister(
        email: email,
        otp: otp,
      );

      if (result['success'] == true) {
        _token = result['token'] as String?;
        _user = result['user'] as UserModel?;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.error;
        _errorMessage = result['message'] as String? ?? 'Verification failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred during verification';
      notifyListeners();
      return false;
    }
  }

  // Resend OTP
  Future<bool> resendOtp({
    required String email,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.resendRegisterOtp(
        email: email,
      );

      if (result['success'] == true) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.error;
        _errorMessage = result['message'] as String? ?? 'Failed to resend OTP';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.logout();
      _user = null;
      _token = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Failed to logout';
    }

    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Update user data locally
  void updateUser(UserModel newUser) {
    _user = newUser;
    notifyListeners();
  }
}
