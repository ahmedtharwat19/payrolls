// lib/core/security/password_hasher.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// تجزئة كلمات المرور بـ PBKDF2-HMAC-SHA256 (بطيئة عمدًا ضد التخمين).
///
/// الصيغة المخزّنة: `pbkdf2-sha256$<iterations>$<hex>`.
/// الصيغة القديمة (SHA-256 واحدة بدون تكرار = 64 حرف hex) لسه بتتقبل عند
/// التحقق، وبعد أول دخول ناجح بيتم ترقيتها تلقائيًا للصيغة الجديدة.
class PasswordHasher {
  PasswordHasher._();

  static const String scheme = 'pbkdf2-sha256';
  static const int defaultIterations = 120000;

  static String generateSalt([int length = 16]) {
    final rand = Random.secure();
    return base64Url
        .encode(List<int>.generate(length, (_) => rand.nextInt(256)));
  }

  static bool isLegacy(String stored) => !stored.startsWith('$scheme\$');

  static bool needsUpgrade(String stored,
      {int iterations = defaultIterations}) {
    if (isLegacy(stored)) return true;
    final parts = stored.split('\$');
    return parts.length != 3 || (int.tryParse(parts[1]) ?? 0) < iterations;
  }

  /// بيشتغل في isolate منفصل (compute) عشان الواجهة ما تهنجش.
  static Future<String> hash(String password, String salt,
      {int iterations = defaultIterations}) async {
    final hex = await compute(_pbkdf2Hex, <Object>[password, salt, iterations]);
    return '$scheme\$$iterations\$$hex';
  }

  static Future<bool> verify(
      String password, String salt, String stored) async {
    if (isLegacy(stored)) {
      final legacy = sha256.convert(utf8.encode('$salt:$password')).toString();
      return constantTimeEquals(legacy, stored);
    }
    final parts = stored.split('\$');
    if (parts.length != 3) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    final hex =
        await compute(_pbkdf2Hex, <Object>[password, salt, iterations]);
    return constantTimeEquals(hex, parts[2]);
  }

  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// سياسة كلمة المرور. بترجع null لو مقبولة، أو مفتاح ترجمة للخطأ.
  static String? validatePolicy(String password, {String? username}) {
    if (password.length < 8) return 'auth_error_weak_password';
    final lower = password.toLowerCase();
    if (username != null &&
        username.isNotEmpty &&
        lower.contains(username.toLowerCase())) {
      return 'auth_error_weak_password';
    }
    const common = {
      'admin123', 'password', 'password1', '12345678', '123456789',
      '1234567890', 'qwerty123', 'iloveyou', 'admin1234',
    };
    if (common.contains(lower)) return 'auth_error_weak_password';
    final hasLetter = RegExp(r'[A-Za-z؀-ۿ]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    if (!(hasLetter && hasDigit)) return 'auth_error_weak_password';
    return null;
  }
}

/// دالة المستوى الأعلى المطلوبة لـ compute. args = [password, salt, iterations]
@visibleForTesting
String pbkdf2HexForTest(String password, String salt, int iterations) =>
    _pbkdf2Hex(<Object>[password, salt, iterations]);

String _pbkdf2Hex(List<Object> args) {
  final password = utf8.encode(args[0] as String);
  final salt = utf8.encode(args[1] as String);
  final iterations = args[2] as int;

  final hmac = Hmac(sha256, password);
  // كتلة واحدة (32 بايت) كفاية لـ SHA-256.
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final t = List<int>.from(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var k = 0; k < t.length; k++) {
      t[k] ^= u[k];
    }
  }
  return t.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
