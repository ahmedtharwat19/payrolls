import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Derives the SQLCipher key using PBKDF2-HMAC-SHA256 with a random salt
/// stored in the platform's secure storage (Keychain / Keystore / libsecret).
class DatabaseKey {
  static const _saltKeyName = 'db_kdf_salt_v2';
  static const int _iterations = 200000;
  static const int _keyLength = 32;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  /// Returns the hex-encoded key suitable for SQLCipher's `PRAGMA key`.
  static Future<String> deriveHex(String deviceFingerprint) async {
    final salt = await _getOrCreateSalt();
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _iterations, _keyLength));
    final key = pbkdf2.process(
      Uint8List.fromList(utf8.encode(deviceFingerprint)),
    );
    return _toHex(key);
  }

  static Future<Uint8List> _getOrCreateSalt() async {
    final existing = await _storage.read(key: _saltKeyName);
    if (existing != null) return base64Decode(existing);

    final rnd = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(32, (_) => rnd.nextInt(256)),
    );
    await _storage.write(key: _saltKeyName, value: base64Encode(salt));
    return salt;
  }

  static String _toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
