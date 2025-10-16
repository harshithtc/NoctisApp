import 'package:hive/hive.dart';

import '../models/message.dart';
import '../models/user.dart';

class OfflineService {
  static const String messagesBox = 'cached_messages';
  static const String queueBox = 'message_queue';
  static const String userBox = 'user_data';
  static const String settingsBox = 'settings';

  // ---------------
  // Messages cache
  // ---------------
  /// Upsert a message in the cache keyed by message.id
  Future<void> cacheMessage(Message message) async {
    final box = await Hive.openBox<Message>(messagesBox);
    await box.put(message.id, message);
  }

  /// Bulk upsert messages
  Future<void> cacheMessages(List<Message> items) async {
    if (items.isEmpty) return;
    final box = await Hive.openBox<Message>(messagesBox);
    await box.putAll({for (final m in items) m.id: m});
  }

  /// Get cached messages, most recent first, with pagination
  Future<List<Message>> getCachedMessages({int limit = 50, int offset = 0}) async {
    final box = await Hive.openBox<Message>(messagesBox);
    final list = box.values.toList();

    // Sort by createdAt descending
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final start = offset.clamp(0, list.length);
    final end = (offset + limit).clamp(0, list.length);
    if (start >= list.length) return <Message>[];
    return list.sublist(start, end);
  }

  /// Remove a message from cache by id
  Future<void> removeCachedMessage(String messageId) async {
    final box = await Hive.openBox<Message>(messagesBox);
    await box.delete(messageId);
  }

  /// Clear cached messages
  Future<void> clearCachedMessages() async {
    final box = await Hive.openBox<Message>(messagesBox);
    await box.clear();
  }

  // ---------------
  // Queue handling
  // ---------------
  /// Queue a message for retry when online.
  /// Prevents duplicates by clientId; updates the existing queued entry if found.
  Future<void> queueMessage(Message message) async {
    final box = await Hive.openBox<Message>(queueBox);

    // Try to find existing by clientId
    dynamic existingKey;
    for (final key in box.keys) {
      final m = box.get(key);
      if (m?.clientId == message.clientId) {
        existingKey = key;
        break;
      }
    }

    if (existingKey != null) {
      await box.put(existingKey, message);
    } else {
      await box.add(message);
    }
  }

  /// Get queued messages in insertion order
  Future<List<Message>> getQueuedMessages() async {
    final box = await Hive.openBox<Message>(queueBox);
    return box.values.toList();
  }

  /// Remove a queued message by clientId
  Future<void> removeFromQueue(String clientId) async {
    final box = await Hive.openBox<Message>(queueBox);
    dynamic toDeleteKey;
    for (final key in box.keys) {
      final m = box.get(key);
      if (m?.clientId == clientId) {
        toDeleteKey = key;
        break;
      }
    }
    if (toDeleteKey != null) {
      await box.delete(toDeleteKey);
    }
  }

  /// Clear all queued messages
  Future<void> clearQueue() async {
    final box = await Hive.openBox<Message>(queueBox);
    await box.clear();
  }

  // ---------------
  // User profile
  // ---------------
  /// Save user data (single current user)
  Future<void> saveUser(User user) async {
    final box = await Hive.openBox<User>(userBox);
    await box.put('current_user', user);
  }

  /// Get saved user (if any)
  Future<User?> getUser() async {
    final box = await Hive.openBox<User>(userBox);
    return box.get('current_user');
  }

  /// Remove saved user
  Future<void> clearUser() async {
    final box = await Hive.openBox<User>(userBox);
    await box.delete('current_user');
  }

  // ---------------
  // Maintenance
  // ---------------
  /// Clear all cached data (messages, queue, user)
  Future<void> clearAllCache() async {
    await Hive.deleteBoxFromDisk(messagesBox);
    await Hive.deleteBoxFromDisk(queueBox);
    await Hive.deleteBoxFromDisk(userBox);
  }

  /// Rough cache size estimate in MB (heuristic)
  Future<double> getCacheSize() async {
    try {
      final messages = await Hive.openBox<Message>(OfflineService.messagesBox);
      final queue = await Hive.openBox<Message>(OfflineService.queueBox);
      // Heuristic: ~1KB per message entry
      final totalEntries = messages.length + queue.length;
      return totalEntries / 1024.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Search cached messages by encrypted content.
  /// Note: Searches ciphertext; for plaintext search, decrypt at the UI layer before filtering.
  Future<List<Message>> searchMessages(String query) async {
    final box = await Hive.openBox<Message>(messagesBox);
    final q = query.toLowerCase();
    return box.values.where((m) => m.encryptedContent.toLowerCase().contains(q)).toList();
  }
}
