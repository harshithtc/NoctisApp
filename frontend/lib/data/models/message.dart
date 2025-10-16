import 'package:hive/hive.dart';

part 'message.g.dart';

// Enums must be defined BEFORE the class
@HiveType(typeId: 2)
enum MessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  image,
  @HiveField(2)
  video,
  @HiveField(3)
  audio,
  @HiveField(4)
  file,
  @HiveField(5)
  voice,
}

@HiveType(typeId: 3)
enum MessageStatus {
  @HiveField(0)
  queued,
  @HiveField(1)
  sending,
  @HiveField(2)
  sent,
  @HiveField(3)
  delivered,
  @HiveField(4)
  read,
  @HiveField(5)
  failed,
}

// Main Message class
@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String clientId;

  @HiveField(2)
  final String senderId;

  @HiveField(3)
  final String receiverId;

  @HiveField(4)
  final MessageType messageType;

  @HiveField(5)
  final String encryptedContent;

  @HiveField(6)
  final String encryptionIv;

  @HiveField(7)
  final String? mediaUrl;

  @HiveField(8)
  final String? mediaThumbnailUrl;

  @HiveField(9)
  final Map<String, dynamic>? mediaMetadata;

  @HiveField(10)
  final String? replyToId;

  // emoji -> list of user ids
  @HiveField(11)
  final Map<String, List<String>> reactions;

  @HiveField(12)
  final bool isViewOnce;

  @HiveField(13)
  final int? selfDestructTimer;

  @HiveField(14)
  final MessageStatus status;

  @HiveField(15)
  final DateTime? deliveredAt;

  @HiveField(16)
  final DateTime? readAt;

  @HiveField(17)
  final DateTime createdAt;

  @HiveField(18)
  final bool deletedBySender;

  @HiveField(19)
  final bool deletedByReceiver;

  @HiveField(20)
  final bool deletedForEveryone;

  Message({
    required this.id,
    required this.clientId,
    required this.senderId,
    required this.receiverId,
    required this.messageType,
    required this.encryptedContent,
    required this.encryptionIv,
    this.mediaUrl,
    this.mediaThumbnailUrl,
    this.mediaMetadata,
    this.replyToId,
    this.reactions = const {},
    this.isViewOnce = false,
    this.selfDestructTimer,
    this.status = MessageStatus.sent,
    this.deliveredAt,
    this.readAt,
    required this.createdAt,
    this.deletedBySender = false,
    this.deletedByReceiver = false,
    this.deletedForEveryone = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final String statusStr = (json['status'] ?? 'sent').toString();
    final String typeStr = (json['message_type'] ?? 'text').toString();

    DateTime? tryParse(String? v) {
      if (v == null || v.isEmpty) return null;
      try {
        return DateTime.parse(v).toLocal();
      } catch (_) {
        return null;
      }
    }

    // Reactions: ensure Map<String, List<String>>
    Map<String, List<String>> parseReactions(dynamic v) {
      if (v is Map) {
        return v.map((k, val) {
          final key = k.toString();
          final list = (val as List?)?.map((e) => e.toString()).toList() ?? <String>[];
          return MapEntry(key, list);
        });
      }
      return <String, List<String>>{};
    }

    // Media metadata: must be Map<String, dynamic>
    Map<String, dynamic>? parseMeta(dynamic v) {
      if (v is Map) {
        return Map<String, dynamic>.from(v);
      }
      return null;
    }

    return Message(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      messageType: MessageType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => MessageType.text,
      ),
      encryptedContent: json['encrypted_content']?.toString() ?? '',
      encryptionIv: json['encryption_iv']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString(),
      mediaThumbnailUrl: json['media_thumbnail_url']?.toString(),
      mediaMetadata: parseMeta(json['media_metadata']),
      replyToId: json['reply_to_id']?.toString(),
      reactions: parseReactions(json['reactions']),
      isViewOnce: (json['is_view_once'] ?? false) == true,
      selfDestructTimer: json['self_destruct_timer'] is int
          ? json['self_destruct_timer'] as int
          : int.tryParse(json['self_destruct_timer']?.toString() ?? ''),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => MessageStatus.sent,
      ),
      deliveredAt: tryParse(json['delivered_at']?.toString()),
      readAt: tryParse(json['read_at']?.toString()),
      createdAt: tryParse(json['created_at']?.toString()) ?? DateTime.now(),
      deletedBySender: (json['deleted_by_sender'] ?? false) == true,
      deletedByReceiver: (json['deleted_by_receiver'] ?? false) == true,
      deletedForEveryone: (json['deleted_for_everyone'] ?? false) == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message_type': messageType.name,
      'encrypted_content': encryptedContent,
      'encryption_iv': encryptionIv,
      'media_url': mediaUrl,
      'media_thumbnail_url': mediaThumbnailUrl,
      'media_metadata': mediaMetadata,
      'reply_to_id': replyToId,
      'reactions': reactions,
      'is_view_once': isViewOnce,
      'self_destruct_timer': selfDestructTimer,
      'status': status.name,
      'delivered_at': deliveredAt?.toUtc().toIso8601String(),
      'read_at': readAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'deleted_by_sender': deletedBySender,
      'deleted_by_receiver': deletedByReceiver,
      'deleted_for_everyone': deletedForEveryone,
    };
  }

  Message copyWith({
    String? id,
    String? clientId,
    String? senderId,
    String? receiverId,
    MessageType? messageType,
    String? encryptedContent,
    String? encryptionIv,
    String? mediaUrl,
    String? mediaThumbnailUrl,
    Map<String, dynamic>? mediaMetadata,
    String? replyToId,
    Map<String, List<String>>? reactions,
    bool? isViewOnce,
    int? selfDestructTimer,
    MessageStatus? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? createdAt,
    bool? deletedBySender,
    bool? deletedByReceiver,
    bool? deletedForEveryone,
  }) {
    return Message(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      messageType: messageType ?? this.messageType,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      encryptionIv: encryptionIv ?? this.encryptionIv,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaThumbnailUrl: mediaThumbnailUrl ?? this.mediaThumbnailUrl,
      mediaMetadata: mediaMetadata ?? this.mediaMetadata,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      selfDestructTimer: selfDestructTimer ?? this.selfDestructTimer,
      status: status ?? this.status,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      deletedBySender: deletedBySender ?? this.deletedBySender,
      deletedByReceiver: deletedByReceiver ?? this.deletedByReceiver,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
    );
  }

  // Convenience helpers
  bool isMine(String currentUserId) => senderId == currentUserId;

  static void registerHiveAdapters() {
    // Generated adapters for Message (typeId:1) will be in message.g.dart
    // Manual enum adapters are defined below for safety if codegen isn't run.
    Hive.registerAdapter(MessageAdapter());
    Hive.registerAdapter(MessageTypeAdapter());
    Hive.registerAdapter(MessageStatusAdapter());
  }
}

// ============================================================================
// Hive Type Adapters for Enums (manual fallback)
// These MUST be at the END of the file, AFTER the Message class
// ============================================================================

class MessageTypeAdapter extends TypeAdapter<MessageType> {
  @override
  final int typeId = 2;

  @override
  MessageType read(BinaryReader reader) {
    final idx = reader.readByte();
    return MessageType.values[idx];
  }

  @override
  void write(BinaryWriter writer, MessageType obj) {
    writer.writeByte(obj.index);
  }
}

class MessageStatusAdapter extends TypeAdapter<MessageStatus> {
  @override
  final int typeId = 3;

  @override
  MessageStatus read(BinaryReader reader) {
    final idx = reader.readByte();
    return MessageStatus.values[idx];
  }

  @override
  void write(BinaryWriter writer, MessageStatus obj) {
    writer.writeByte(obj.index);
  }
}
