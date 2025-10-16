import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // << ADDED

import '../../core/constants/api_constants.dart';

enum WsStatus { disconnected, connecting, connected, reconnecting }

class WebSocketService {
  WebSocketChannel? _channel;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<WsStatus>.broadcast();

  bool _isConnected = false;
  bool _manuallyClosed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _watchdogTimer;
  DateTime? _lastPongAt;

  Future<String?> Function()? tokenProvider;
  final List<Map<String, dynamic>> _pendingQueue = [];

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<WsStatus> get statusStream => _statusController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;
    _manuallyClosed = false;
    _setStatus(_reconnectAttempts > 0 ? WsStatus.reconnecting : WsStatus.connecting);

    try {
      // Always fetch a fresh token in case it has been refreshed
      final token = await _getAccessToken();
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      final wsUrl = _buildWsUrl(token);
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _isConnected = true;
      _reconnectAttempts = 0;
      _setStatus(WsStatus.connected);

      _startPing();
      _startWatchdog();
      _flushPending();

      _channel!.stream.listen(
        (raw) {
          _handleIncoming(raw);
        },
        onError: (error, stack) {
          _handleDisconnect(error: error);
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _handleDisconnect(error: e);
    }
  }

  // Build WebSocket URL with token
  String _buildWsUrl(String token) {
    // Prefer dotenv for wsUrl if set, else fallback to ApiConstants.wsUrl
    final envBase = dotenv.env['SOCKET_URL'];
    final base = (envBase ?? ApiConstants.wsUrl).replaceAll(RegExp(r'/$'), ''); // ensure no trailing slash

    final path = ApiConstants.chatWs.startsWith('/')
        ? ApiConstants.chatWs
        : '/${ApiConstants.chatWs}';
    final url = '$base$path?token=$token';
    return url;
  }

  Future<String?> _getAccessToken() async {
    if (tokenProvider != null) {
      try {
        final t = await tokenProvider!.call();
        if (t != null && t.isNotEmpty) return t;
      } catch (_) {}
    }
    return _secureStorage.read(key: 'access_token');
  }

  void _handleIncoming(dynamic raw) {
    try {
      final data = raw is String ? jsonDecode(raw) as Map<String, dynamic> : (raw as Map).cast<String, dynamic>();
      if (data['type'] == 'pong') {
        _lastPongAt = DateTime.now();
      }
      _messageController.add(data);
    } catch (e) {
      if (kDebugMode) {
        print('WS parse error: $e');
      }
    }
  }

  void _handleDisconnect({Object? error}) {
    _stopPing();
    _stopWatchdog();

    _isConnected = false;
    if (!_manuallyClosed) {
      _setStatus(WsStatus.reconnecting);
      _scheduleReconnect();
    } else {
      _setStatus(WsStatus.disconnected);
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_manuallyClosed) return;
    final baseDelay = min(30, pow(2, _reconnectAttempts).toInt());
    final jitterMs = Random().nextInt(500);
    final delay = Duration(seconds: max(1, baseDelay), milliseconds: jitterMs);

    _reconnectAttempts = min(_reconnectAttempts + 1, 10);
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _lastPongAt = DateTime.now();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected) {
        sendMessage({'type': 'ping'});
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_isConnected) return;
      final last = _lastPongAt ?? DateTime.now();
      if (DateTime.now().difference(last).inSeconds > 75) {
        _forceReconnect();
      }
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void _forceReconnect() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _isConnected = false;
    _setStatus(WsStatus.reconnecting);
    _scheduleReconnect();
  }

  void _flushPending() {
    if (_pendingQueue.isEmpty || !_isConnected || _channel == null) return;
    for (final msg in List<Map<String, dynamic>>.from(_pendingQueue)) {
      _channel!.sink.add(jsonEncode(msg));
    }
    _pendingQueue.clear();
  }

  void _bufferOrSend(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    } else {
      _pendingQueue.add(message);
      if (!_manuallyClosed) {
        connect();
      }
    }
  }

  // -- Public send helpers --
  void sendMessage(Map<String, dynamic> message) {
    _bufferOrSend(message);
  }

  void sendTypingIndicator(String receiverId, bool isTyping) {
    _bufferOrSend({
      'type': 'typing',
      'receiver_id': receiverId,
      'is_typing': isTyping,
    });
  }

  void sendReadReceipt(String receiverId, List<String> messageIds) {
    _bufferOrSend({
      'type': 'read_receipt',
      'receiver_id': receiverId,
      'message_ids': messageIds,
      'read_at': DateTime.now().toIso8601String(),
    });
  }

  void sendSignal({
    required String toUserId,
    required String callId,
    required String signalType,
    required Map<String, dynamic> payload,
  }) {
    _bufferOrSend({
      'type': 'signal',
      'to': toUserId,
      'call_id': callId,
      'signal_type': signalType,
      'payload': payload,
    });
  }

  void sendPartyAction({
    required String roomId,
    required String action,
    String? provider,
    String? trackId,
    double? position,
  }) {
    _bufferOrSend({
      'type': 'party',
      'room_id': roomId,
      'action': action,
      'provider': provider,
      'track_id': trackId,
      'position': position,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // -- Lifecycle --
  Future<void> disconnect() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _stopPing();
    _stopWatchdog();

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _isConnected = false;
    _setStatus(WsStatus.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _statusController.close();
  }

  void _setStatus(WsStatus s) {
    if (!_statusController.isClosed) {
      _statusController.add(s);
    }
  }
}
