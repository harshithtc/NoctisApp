import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../../data/models/message.dart';
import '../../data/models/user.dart';
import '../../data/services/api_service.dart';
import '../../data/services/websocket_service.dart';
import '../../data/services/offline_service.dart';
import '../../data/services/encryption_service.dart';

class ChatProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  final OfflineService _offlineService = OfflineService();
  late EncryptionService _encryptionService;

  final List<Message> _messages = [];
  final List<Message> _queuedMessages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  String? _error;

  // Pagination properties
  bool _hasMoreMessages = true;
  final int _pageSize = 50;

  // Reply message
  Message? _replyMessage;

  List<Message> get messages => _messages;
  List<Message> get queuedMessages => _queuedMessages;
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;
  String? get error => _error;
  bool get isConnected => _wsService.isConnected;
  Message? get replyMessage => _replyMessage;
  bool get hasMoreMessages => _hasMoreMessages;

  StreamSubscription? _wsMsgSub;
  StreamSubscription? _wsStatusSub;

  /// Initialize chat
  Future<void> initialize(String encryptionKey, User currentUser) async {
    _encryptionService = EncryptionService(encryptionKey);

    // Load cached messages
    await loadCachedMessages();

    // Load queued messages
    await loadQueuedMessages();

    // Provide token provider to WS for robust reconnects
    _wsService.tokenProvider = () => _apiService.getAccessToken();

    // Connect WebSocket
    await _wsService.connect();

    // Listen to WebSocket messages
    _wsMsgSub?.cancel();
    _wsMsgSub = _wsService.messageStream.listen(
      (data) => _handleWebSocketMessage(data, currentUser),
      onError: (_) {},
    );

    // On WS connected, try sending any queued messages
    _wsStatusSub?.cancel();
    _wsStatusSub = _wsService.statusStream.listen((status) {
      if (_wsService.isConnected) {
        _sendQueuedMessages();
      }
    });

    // Sync messages
    await syncMessages();
  }

  /// Load cached messages from local storage
  Future<void> loadCachedMessages() async {
    _isLoading = true;
    notifyListeners();

    try {
      final cached = await _offlineService.getCachedMessages(limit: 100);
      _messages
        ..clear()
        ..addAll(cached);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load queued messages
  Future<void> loadQueuedMessages() async {
    try {
      final queued = await _offlineService.getQueuedMessages();
      _queuedMessages
        ..clear()
        ..addAll(queued);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  /// Fetch more messages (pagination)
  Future<void> fetchMoreMessages() async {
    if (_isLoading || !_hasMoreMessages) return;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getMessages(
        limit: _pageSize,
        offset: _messages.length, // Use offset for pagination
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data as List : [];
        if (data.length < _pageSize) _hasMoreMessages = false;

        for (final json in data) {
          final message = Message.fromJson(json);
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message); // Add to end (oldest messages)
            await _offlineService.cacheMessage(message);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Sync messages with server
  Future<void> syncMessages() async {
    if (!_wsService.isConnected) return;

    try {
      final lastMessage = _messages.isNotEmpty ? _messages.first : null;
      final response = await _apiService.getMessages(
        limit: 50,
        lastSync: lastMessage?.createdAt,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data as List : [];
        for (final json in data) {
          final message = Message.fromJson(json);

          // Cache message
          await _offlineService.cacheMessage(message);

          // Add to list if not exists
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.insert(0, message);
          }
        }

        // Send queued messages
        await _sendQueuedMessages();

        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  /// Send queued messages
  Future<void> _sendQueuedMessages() async {
    for (final message in List<Message>.from(_queuedMessages)) {
      try {
        await _sendMessageToServer(message);
        await _offlineService.removeFromQueue(message.clientId);
        _queuedMessages.remove(message);
      } catch (_) {
        // Keep in queue on failure
      }
    }
    notifyListeners();
  }

  /// Send message
  Future<void> sendMessage({
    required String receiverId,
    required String content,
    required User currentUser,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? replyToId,
    bool isViewOnce = false,
    int? selfDestructTimer,
  }) async {
    try {
      final encrypted = _encryptionService.encryptMessage(content);

      final clientId = const Uuid().v4();
      final provisionalId = const Uuid().v4();
      final message = Message(
        id: provisionalId,
        clientId: clientId,
        senderId: currentUser.id,
        receiverId: receiverId,
        messageType: type,
        encryptedContent: encrypted['encrypted']!,
        encryptionIv: encrypted['iv']!,
        mediaUrl: mediaUrl,
        replyToId: replyToId,
        isViewOnce: isViewOnce,
        selfDestructTimer: selfDestructTimer,
        status: _wsService.isConnected ? MessageStatus.sending : MessageStatus.queued,
        createdAt: DateTime.now(),
      );

      _messages.insert(0, message);
      await _offlineService.cacheMessage(message);

      if (_wsService.isConnected) {
        await _sendMessageToServer(message);
      } else {
        await _offlineService.queueMessage(message);
        _queuedMessages.add(message);
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Send message to server
  Future<void> _sendMessageToServer(Message message) async {
    try {
      final response = await _apiService.sendMessage(message.toJson());

      if (response.statusCode == 201) {
        final serverMessage = Message.fromJson(response.data);

        final index = _messages.indexWhere((m) => m.clientId == message.clientId);
        if (index != -1) {
          _messages[index] = serverMessage;
        }

        await _offlineService.cacheMessage(serverMessage);

        _wsService.sendMessage({
          'type': 'message',
          'message_id': serverMessage.id,
          'client_id': serverMessage.clientId,
          'receiver_id': message.receiverId,
          'delivered_at': DateTime.now().toIso8601String(),
          'message': serverMessage.toJson(),
        });

        notifyListeners();
      } else {
        throw Exception('Unexpected status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Handle incoming WebSocket messages
  Future<void> _handleWebSocketMessage(Map<String, dynamic> data, User currentUser) async {
    final type = data['type'];

    switch (type) {
      case 'new_message':
        if (data['message'] != null) {
          final message = Message.fromJson(data['message']);

          if (!_messages.any((m) => m.id == message.id)) {
            _messages.insert(0, message);
            await _offlineService.cacheMessage(message);

            if (message.receiverId == currentUser.id) {
              _wsService.sendReadReceipt(message.senderId, [message.id]);
            }

            notifyListeners();
          }
        } else {
          try {
            final res = await _apiService.getMessages(limit: 1);
            if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
              final latest = Message.fromJson(res.data.first as Map<String, dynamic>);
              if (!_messages.any((m) => m.id == latest.id)) {
                _messages.insert(0, latest);
                await _offlineService.cacheMessage(latest);

                if (latest.receiverId == currentUser.id) {
                  _wsService.sendReadReceipt(latest.senderId, [latest.id]);
                }

                notifyListeners();
              }
            }
          } catch (_) {
            // ignore sync failure
          }
        }
        break;

      case 'message_delivered':
        final messageId = data['message_id']?.toString();
        final deliveredAtStr = data['delivered_at']?.toString();
        if (messageId != null && deliveredAtStr != null) {
          final deliveredAt = DateTime.tryParse(deliveredAtStr);
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              status: MessageStatus.delivered,
              deliveredAt: deliveredAt,
            );
            notifyListeners();
          }
        }
        break;

      case 'messages_read':
        final ids = (data['message_ids'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        final readAt = DateTime.tryParse(data['read_at']?.toString() ?? '');
        for (final id in ids) {
          final idx = _messages.indexWhere((m) => m.id == id);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(
              status: MessageStatus.read,
              readAt: readAt,
            );
          }
        }
        notifyListeners();
        break;

      case 'typing':
        _isTyping = data['is_typing'] == true;
        notifyListeners();
        break;

      default:
        if (kDebugMode) {
          // ignore: avoid_print
          print('WS event ignored: $type');
        }
    }
  }

  /// Decrypt message content
  String _decryptContent(String encryptedContent, String iv) {
    try {
      return _encryptionService.decryptMessage(encryptedContent, iv);
    } catch (_) {
      return '[Encrypted Message]';
    }
  }

  /// Decrypt message - public method for ChatScreen
  String decryptMessage(Message message) {
    return _decryptContent(message.encryptedContent, message.encryptionIv);
  }

  /// Delete message
  Future<void> deleteMessage(String messageId, bool deleteForEveryone) async {
    try {
      await _apiService.deleteMessage(messageId, deleteForEveryone);

      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  /// React to message
  Future<void> reactToMessage(String messageId, String emoji) async {
    try {
      await _apiService.reactToMessage(messageId, emoji);
    } catch (e) {
      _error = e.toString();
    }
  }

  /// Send typing indicator
  void sendTypingIndicator(String receiverId, bool isTyping) {
    _wsService.sendTypingIndicator(receiverId, isTyping);
  }

  /// Clear all messages
  Future<void> clearAllMessages() async {
    try {
      await _offlineService.clearAllCache();
      _messages.clear();
      _hasMoreMessages = true; // Reset pagination state
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  /// Set reply message
  void setReplyMessage(Message? message) {
    _replyMessage = message;
    notifyListeners();
  }

  /// Clear reply message
  void clearReplyMessage() {
    _replyMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsMsgSub?.cancel();
    _wsStatusSub?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}
