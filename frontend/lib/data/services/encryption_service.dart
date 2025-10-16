import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt; // CBC compatibility
import 'package:cryptography/cryptography.dart' as cg; // GCM (recommended)
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// End-to-end Encryption service for messages/media.
/// - Default compatible mode: AES-256-CBC (sync API) to avoid breaking existing code.
/// - Recommended new mode: AES-256-GCM (async API) with ciphertext+tag format to match backend.
/// - Keys: base64-encoded 32 bytes (256-bit).
class EncryptionService {
  late final Uint8List _keyBytes;

  // CBC (legacy/compat)
  late final encrypt.Key _cbcKey;
  late final encrypt.Encrypter _cbc;
  static const int _cbcIvLen = 16;

  // GCM (recommended)
  final cg.AesGcm _gcm = cg.AesGcm.with256bits();
  static const int _gcmNonceLen = 12; // 96-bit nonce
  static const int _gcmTagLen = 16; // 128-bit tag appended to ciphertext

  EncryptionService(String keyBase64) {
    _keyBytes = _b64Decode(keyBase64);
    if (_keyBytes.lengthInBytes != 32) {
      throw ArgumentError('ENCRYPTION_KEY must decode to 32 bytes (got ${_keyBytes.lengthInBytes})');
    }

    // CBC setup
    _cbcKey = encrypt.Key(_keyBytes);
    _cbc = encrypt.Encrypter(
      encrypt.AES(_cbcKey, mode: encrypt.AESMode.cbc), // PKCS7 padding by default
    );
  }

  // ---------------------------
  // CBC SYNC API (existing use)
  // ---------------------------

  /// Encrypt plaintext using AES-256-CBC (returns base64 ciphertext and 16-byte IV).
  Map<String, String> encryptMessage(String plaintext) {
    final iv = encrypt.IV.fromSecureRandom(_cbcIvLen);
    final encrypted = _cbc.encrypt(plaintext, iv: iv);
    return {
      'encrypted': encrypted.base64,
      'iv': iv.base64,
      'mode': 'cbc',
    };
  }

  /// Decrypt AES-256-CBC ciphertext using provided base64 IV.
  String decryptMessage(String encryptedText, String ivBase64) {
    final iv = encrypt.IV.fromBase64(ivBase64);
    final encrypted = encrypt.Encrypted.fromBase64(encryptedText);
    return _cbc.decrypt(encrypted, iv: iv);
  }

  // --------------------------------
  // GCM ASYNC API (preferred/new)
  // --------------------------------

  /// Encrypt plaintext with AES-256-GCM.
  /// Returns map with:
  /// - encrypted: base64(ciphertext || 16-byte tag)
  /// - iv: base64(12-byte nonce)
  /// - mode: 'gcm'
  Future<Map<String, String>> encryptMessageGcm(String plaintext, {List<int>? aad}) async {
    final nonce = _randomBytes(_gcmNonceLen);
    final secretKey = cg.SecretKey(_keyBytes);
    final box = await _gcm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
      aad: aad ?? [],
    );
    final combined = Uint8List(box.cipherText.length + box.mac.bytes.length)
      ..setRange(0, box.cipherText.length, box.cipherText)
      ..setRange(box.cipherText.length, box.cipherText.length + box.mac.bytes.length, box.mac.bytes);
    return {
      'encrypted': base64Encode(combined),
      'iv': base64Encode(nonce),
      'mode': 'gcm',
    };
  }

  /// Decrypt AES-256-GCM given base64(ciphertext||tag) and base64(nonce).
  Future<String> decryptMessageGcm(String encryptedBase64, String nonceBase64, {List<int>? aad}) async {
    final combined = base64Decode(encryptedBase64);
    if (combined.length < _gcmTagLen) {
      throw ArgumentError('Ciphertext too short for GCM.');
    }
    final ctLen = combined.length - _gcmTagLen;
    final cipher = Uint8List.view(combined.buffer, 0, ctLen);
    final tag = Uint8List.view(combined.buffer, ctLen, _gcmTagLen);
    final box = cg.SecretBox(cipher, nonce: base64Decode(nonceBase64), mac: cg.Mac(tag));
    final secretKey = cg.SecretKey(_keyBytes);
    final plain = await _gcm.decrypt(box, secretKey: secretKey, aad: aad  ?? []);
    return utf8.decode(plain);
  }

  // --------------------------------
  // Media bytes helpers (GCM)
  // --------------------------------

  /// Encrypt raw bytes using AES-256-GCM; returns base64 fields to send/store.
  Future<Map<String, String>> encryptBytesGcm(Uint8List data, {List<int>? aad}) async {
    final nonce = _randomBytes(_gcmNonceLen);
    final secretKey = cg.SecretKey(_keyBytes);
    final box = await _gcm.encrypt(
      data,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad ?? [],
    );
    final combined = Uint8List(box.cipherText.length + box.mac.bytes.length)
      ..setRange(0, box.cipherText.length, box.cipherText)
      ..setRange(box.cipherText.length, box.cipherText.length + box.mac.bytes.length, box.mac.bytes);
    return {
      'encrypted': base64Encode(combined),
      'iv': base64Encode(nonce),
      'mode': 'gcm',
    };
  }

  /// Decrypt raw bytes using AES-256-GCM from base64 fields.
  Future<Uint8List> decryptBytesGcm(String encryptedBase64, String nonceBase64, {List<int>? aad}) async {
    final combined = base64Decode(encryptedBase64);
    if (combined.length < _gcmTagLen) {
      throw ArgumentError('Ciphertext too short for GCM.');
    }
    final ctLen = combined.length - _gcmTagLen;
    final cipher = Uint8List.view(combined.buffer, 0, ctLen);
    final tag = Uint8List.view(combined.buffer, ctLen, _gcmTagLen);
    final box = cg.SecretBox(cipher, nonce: base64Decode(nonceBase64), mac: cg.Mac(tag));
    final secretKey = cg.SecretKey(_keyBytes);
    final plain = await _gcm.decrypt(box, secretKey: secretKey, aad: aad ?? [] );
    return Uint8List.fromList(plain);
  }

  // --------------------------------
  // Utilities
  // --------------------------------

  /// Client-side password hash (additional layer; server must still hash safely).
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a new 32-byte key (base64).
  static String generateKey() {
    final key = _randomBytes(32);
    return base64Encode(key);
  }

  /// Create or return existing base64 key stored securely on device.
  static Future<String> getOrCreateEncryptionKey() async {
    const storage = FlutterSecureStorage();
    String? key = await storage.read(key: 'encryption_key');
    if (key == null || key.isEmpty) {
      key = generateKey();
      await storage.write(key: 'encryption_key', value: key);
    }
    return key;
  }

  // --------------------------
  // Internal helpers
  // --------------------------

  // Secure random bytes using Random.secure()
  static Uint8List _randomBytes(int len) {
    final rnd = math.Random.secure();
    final bytes = Uint8List(len);
    for (var i = 0; i < len; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }

  static Uint8List _b64Decode(String b64) {
    final s = b64.trim();
    final pad = s.length % 4 == 0 ? '' : '=' * (4 - s.length % 4);
    return Uint8List.fromList(base64Decode(s + pad));
  }
}
