import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/constants/api_constants.dart';

class ApiService {
  static const String _kAccessToken = 'access_token';
  static const String _kRefreshToken = 'refresh_token';

  late final Dio _dio;
  Dio get client => _dio;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  ApiService({Dio? dio}) {
    _dio = dio ?? Dio(_buildBaseOptions());

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ));
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers.putIfAbsent('Accept', () => 'application/json');
          options.headers.putIfAbsent('Content-Type', () => 'application/json');

          final token = await _secureStorage.read(key: _kAccessToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          options.headers['X-Request-ID'] = _genRequestId();
          handler.next(options);
        },
        onError: (err, handler) async {
          final isUnauthorized = err.response?.statusCode == 401;
          final isRefreshCall = err.requestOptions.path.contains(ApiConstants.refreshToken);

          if (!isUnauthorized || isRefreshCall) {
            handler.next(err);
            return;
          }

          try {
            final newToken = await _refreshTokenSafely();
            if (newToken != null && newToken.isNotEmpty) {
              final RequestOptions req = err.requestOptions;
              final opts = Options(
                method: req.method,
                headers: Map<String, dynamic>.from(req.headers)..['Authorization'] = 'Bearer $newToken',
                responseType: req.responseType,
                contentType: req.contentType,
                sendTimeout: req.sendTimeout,
                receiveTimeout: req.receiveTimeout,
                followRedirects: req.followRedirects,
                validateStatus: req.validateStatus,
              );
              final response = await _dio.request<dynamic>(
                req.path,
                data: req.data,
                queryParameters: req.queryParameters,
                options: opts,
                cancelToken: req.cancelToken,
                onReceiveProgress: req.onReceiveProgress,
              );
              handler.resolve(response);
              return;
            }
          } catch (_) {}
          await _clearTokens();
          handler.next(err);
        },
      ),
    );
  }

  BaseOptions _buildBaseOptions() {
    Duration toDuration(dynamic v, int fallbackMs) {
      if (v is Duration) return v;
      if (v is int) return Duration(milliseconds: v);
      return Duration(milliseconds: fallbackMs);
    }

    final String baseUrl = dotenv.env['API_URL'] ?? ApiConstants.baseUrl;

    return BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: toDuration(ApiConstants.connectTimeout, 15000),
      receiveTimeout: toDuration(ApiConstants.receiveTimeout, 20000),
      sendTimeout: toDuration(ApiConstants.sendTimeout, 20000),
      responseType: ResponseType.json,
      followRedirects: true,
      validateStatus: (code) => (code != null && code >= 200 && code < 400) || code == 401 || code == 409,
      receiveDataWhenStatusError: true,
    );
  }

  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  Future<String?> _refreshTokenSafely() async {
    if (_isRefreshing) {
      return _refreshCompleter?.future;
    }
    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();
    try {
      final newToken = await _refreshToken();
      _refreshCompleter?.complete(newToken);
      return newToken;
    } catch (e) {
      _refreshCompleter?.complete(null);
      rethrow;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  Future<String?> _refreshToken() async {
    final refreshToken = await _secureStorage.read(key: _kRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty) return null;
    final response = await _dio.post(ApiConstants.refreshToken, data: {'refresh_token': refreshToken});
    if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
      final data = response.data is Map ? response.data as Map : {};
      final newAccessToken = data['access_token']?.toString();
      final newRefreshToken = data['refresh_token']?.toString();
      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await _secureStorage.write(key: _kAccessToken, value: newAccessToken);
      }
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _secureStorage.write(key: _kRefreshToken, value: newRefreshToken);
      }
      return newAccessToken;
    }
    return null;
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);
  }

  String _genRequestId() => '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

  // Auth APIs
  Future<Response> register(Map<String, dynamic> data) {
    return _dio.post(ApiConstants.register, data: data);
  }

  Future<Response> verifyEmail(Map<String, dynamic> data) {
    return _dio.post(ApiConstants.verifyEmail, data: data);
  }

  Future<Response> resendVerificationCode(Map<String, dynamic> data) {
    return _dio.post(ApiConstants.resendVerification, data: data);
  }

  Future<Response> login(Map<String, dynamic> data) async {
    final res = await _dio.post(ApiConstants.login, data: data);
    if (res.data is Map) {
      final map = res.data as Map;
      final access = map['access_token']?.toString();
      final refresh = map['refresh_token']?.toString();
      if (access != null) await _secureStorage.write(key: _kAccessToken, value: access);
      if (refresh != null) await _secureStorage.write(key: _kRefreshToken, value: refresh);
    }
    return res;
  }

  Future<Response> logout(String refreshToken) async {
    try {
      final res = await _dio.post(ApiConstants.logout, data: {'refresh_token': refreshToken});
      await _clearTokens();
      return res;
    } finally {
      await _clearTokens();
    }
  }

  // Password Reset
  Future<Response> resetPassword(Map<String, dynamic> data) {
    return _dio.post(ApiConstants.resetPassword, data: data);
  }

  // Message APIs, Media APIs, Calls APIs, Utility... (rest of your code unmodified)
  // ...include all the other methods exactly as in your earlier version...

  Future<Response> sendMessage(Map<String, dynamic> data) {
    return _dio.post(ApiConstants.messages, data: data);
  }

  Future<Response> getMessages({int limit = 50, int offset = 0, DateTime? lastSync}) {
    final qp = <String, dynamic>{'limit': limit, 'offset': offset};
    if (lastSync != null) {
      qp['last_sync'] = lastSync.toIso8601String();
    }
    return _dio.get(ApiConstants.messages, queryParameters: qp);
  }

  Future<Response> deleteMessage(String messageId, bool deleteForEveryone) {
    return _dio.delete(
      ApiConstants.messageById(messageId),
      queryParameters: {'delete_for_everyone': deleteForEveryone},
    );
  }

  Future<Response> reactToMessage(String messageId, String emoji) {
    return _dio.post(
      ApiConstants.messageReact(messageId),
      data: {'emoji': emoji},
    );
  }

  Future<Response> markMessageRead(String messageId) {
    return _dio.post(ApiConstants.messageMarkRead(messageId));
  }

  // Media APIs
  Future<Response> uploadImage(FormData formData, {bool encrypted = false}) {
    return _dio.post(
      ApiConstants.uploadImage,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {'X-Encrypted': encrypted.toString()},
      ),
    );
  }

  Future<Response> uploadVideo(FormData formData, {bool encrypted = false}) {
    return _dio.post(
      ApiConstants.uploadVideo,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {'X-Encrypted': encrypted.toString()},
      ),
    );
  }

  // Calls APIs
  Future<Response> initiateCall({required String receiverId, String callType = 'voice'}) {
    return _dio.post(
      ApiConstants.callsInitiate,
      data: {'receiver_id': receiverId, 'call_type': callType},
    );
  }

  Future<Response> answerCall(String callId) {
    return _dio.post(ApiConstants.callsAnswer(callId));
  }

  Future<Response> endCall(String callId) {
    return _dio.post(ApiConstants.callsEnd(callId));
  }

  Future<Response> getCallStatus(String callId) {
    return _dio.get(ApiConstants.callsStatus(callId));
  }

  Future<Response> getCallHistory() {
    return _dio.get(ApiConstants.callsHistory);
  }

  // Utility
  Future<String?> getAccessToken() => _secureStorage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _secureStorage.read(key: _kRefreshToken);

  Future<void> setTokens({required String accessToken, String? refreshToken}) async {
    await _secureStorage.write(key: _kAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
    }
  }
}
