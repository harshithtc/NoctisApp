import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/user.dart';
import '../../data/services/api_service.dart';
import '../../data/services/offline_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;
  final OfflineService _offlineService;
  final FlutterSecureStorage _secureStorage;

  AuthProvider({
    ApiService? apiService,
    OfflineService? offlineService,
    FlutterSecureStorage? secureStorage,
  })  : _apiService = apiService ?? ApiService(),
        _offlineService = offlineService ?? OfflineService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  // -----------------------
  // Lifecycle / Init
  // -----------------------
  Future<void> initialize() async {
    _setLoading(true);
    try {
      final user = await _offlineService.getUser();
      final token = await _secureStorage.read(key: 'access_token');
      if (user != null && token != null && token.isNotEmpty) {
        _currentUser = user;
      } else {
        _currentUser = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setCurrentUser(User? user, {bool persist = true}) async {
    _currentUser = user;
    if (persist && user != null) {
      await _offlineService.saveUser(user);
    }
    notifyListeners();
  }

  // -----------------------
  // Registration & Verify
  // -----------------------
  Future<String?> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiService.register({
        'email': email,
        'password': password,
        'name': name,
      });

      if (response.statusCode == 201) {
        _setLoading(false);
        return (response.data as Map)['user_id']?.toString();
      }

      _error = 'Registration failed';
      return null;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registerAndLogin({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final userId = await register(email: email, password: password, name: name);
      if (userId == null) {
        return false;
      }
      final ok = await login(email: email, password: password);
      return ok;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyEmail({
    required String userId,
    required String code,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiService.verifyEmail({
        'user_id': userId,
        'code': code,
      });

      if (response.statusCode == 200) {
        return true;
      }

      _error = 'Verification failed';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendVerificationCode({
    required String userId,
    required String email,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiService.resendVerificationCode({
        'user_id': userId,
        'email': email,
      });

      if (response.statusCode == 200) {
        return true;
      }

      _error = 'Failed to resend code';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -----------------------
  // Password Reset
  // -----------------------
  Future<bool> resetPassword({required String email}) async {
    _setLoading(true);
    _error = null;
    try {
      final response = await _apiService.resetPassword({'email': email});
      if (response.statusCode == 200) {
        return true;
      } else {
        _error = response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : 'Password reset failed';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -----------------------
  // Login / Logout
  // -----------------------
  Future<bool> login({
    required String email,
    required String password,
    String? deviceInfo,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiService.login({
        'email': email,
        'password': password,
        if (deviceInfo != null) 'device_info': deviceInfo,
      });

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>?;
        if (data == null) {
          _error = 'Invalid response from server';
          return false;
        }

        final accessToken = data['access_token']?.toString();
        if (accessToken == null || accessToken.isEmpty) {
          _error = 'No access token received';
          return false;
        }

        final userData = data['user'] as Map<String, dynamic>?;
        if (userData != null) {
          try {
            _currentUser = User.fromJson(userData);
            await _offlineService.saveUser(_currentUser!);
          } catch (e) {
            debugPrint('Error parsing user data: $e');
          }
        }

        notifyListeners();
        return true;
      }

      _error = 'Login failed with status: ${response.statusCode}';
      return false;
    } on Exception catch (e) {
      _error = 'Login error: ${e.toString()}';
      return false;
    } catch (e) {
      _error = 'Unexpected error: ${e.toString()}';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiService.logout(refreshToken);
      }
    } catch (e) {
      debugPrint('Logout API error: $e');
    }
    try {
      await _secureStorage.deleteAll();
      await _offlineService.clearAllCache();
    } catch (e) {
      debugPrint('Error clearing local data: $e');
    }
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  // -----------------------
  // Helpers
  // -----------------------
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<String?> getAccessToken() => _secureStorage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _secureStorage.read(key: 'refresh_token');

  Future<void> refreshFromCache() async {
    try {
      final token = await _secureStorage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        _currentUser = null;
        notifyListeners();
        return;
      }
      final cached = await _offlineService.getUser();
      if (cached != null) {
        _currentUser = cached;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('refreshFromCache error: $e');
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
