import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String email;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String? avatarUrl;

  @HiveField(4)
  final String? bio;

  @HiveField(5)
  final String? phoneNumber;

  @HiveField(6)
  final bool emailVerified;

  @HiveField(7)
  final bool phoneVerified;

  @HiveField(8)
  final String? partnerId;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime? lastSeen;

   User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.phoneNumber,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.partnerId,
    required this.createdAt,
    this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    DateTime parseDT(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString()).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }

    DateTime? tryParseDT(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      emailVerified: (json['email_verified'] ?? false) == true,
      phoneVerified: (json['phone_verified'] ?? false) == true,
      partnerId: json['partner_id']?.toString(),
      createdAt: parseDT(json['created_at']),
      lastSeen: tryParseDT(json['last_seen']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'bio': bio,
      'phone_number': phoneNumber,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
      'partner_id': partnerId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'last_seen': lastSeen?.toUtc().toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? bio,
    String? phoneNumber,
    bool? emailVerified,
    bool? phoneVerified,
    String? partnerId,
    DateTime? createdAt,
    DateTime? lastSeen,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      partnerId: partnerId ?? this.partnerId,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  static void registerHiveAdapter() {
    Hive.registerAdapter(UserAdapter());
  }
}
