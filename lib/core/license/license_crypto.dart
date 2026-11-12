/* // lib/core/license/license_crypto.dart
//
// ⚠️ ملف مهم جدًا: نفس المحتوى بالظبط (حرفيًا) لازم يكون موجود في:
//   1) مشروع التطبيق الرئيسي (payrolls)         -> lib/core/license/license_crypto.dart
//   2) مشروع أداة الأدمن (license_admin_tool)   -> lib/license_crypto.dart (أو أي مكان)
// لو الملفين مش متطابقين حرفيًا، التشفير هيفشل لأن المفتاح هيبقى مختلف.
//
// إيه اللي بيعمله الملف ده:
// - بيحوّل بيانات الترخيص من JSON نصي واضح إلى صيغة Binary مضغوطة جدًا
//   (بدل ما يبقى فيه "customerName": ".." بيبقى بايتات مرتبة بترتيب ثابت).
// - بيشفّر الصيغة دي بـ AES-256-GCM قبل ما يوقّعها بـ Ed25519 (زي ما كانت
//   قبل كده)، يعني دلوقتي محدش يقدر "يقرا" محتوى الكود غير التطبيق نفسه
//   اللي عنده مفتاح فك التشفير - مش بس يعجز عن "تزويره" زي قبل كده.
// - المفتاح متقسّم على جزئين (XOR) بدل ما يتخزن كسلسلة واحدة واضحة في
//   الكود، عشان يصعب استخراجه بمجرد فتح الملف بأي محرر نصوص أو أداة
//   بحث بسيطة عن الـ strings جوه الـ binary بعد البناء.
//
// ⚠️ تنبيه صادق: مفيش نظام تشفير أوفلاين بيمنع 100% شخص محترف من عمل
// decompile للتطبيق واستخراج المفتاح منه وقت التشغيل (runtime). ده حد
// أقصى موجود في أي نظام ترخيص أوفلاين حتى عند شركات كبيرة. اللي احنا
// بنعمله هنا بيرفع الصعوبة بشكل كبير جدًا (محدش عادي هيقدر يفتح الكود
// بمحرر نصوص أو base64 decoder بسيط)، مش بيخليها مستحيلة نظريًا 100%.

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';

/// ------------------------------------------------------------------
/// مفتاح AES-256 مقسّم على جزئين (XOR) - لازم يتطابق مع نفس الجزئين
/// في المشروعين. لو حبيت تولّد مفتاح جديد بنفسك يومًا ما، تقدر تولّد
/// 2 مصفوفة عشوائية 32 بايت وتحط قيمة الـ XOR بتاعتهم هنا وهناك.
/// ------------------------------------------------------------------
const List<int> _keyPart1 = [
  97,
  191,
  96,
  136,
  71,
  194,
  22,
  72,
  203,
  169,
  11,
  19,
  78,
  35,
  221,
  98,
  254,
  224,
  219,
  124,
  26,
  126,
  132,
  29,
  238,
  147,
  203,
  105,
  170,
  140,
  166,
  147,
];
const List<int> _keyPart2 = [
  65,
  255,
  181,
  136,
  157,
  255,
  53,
  26,
  203,
  107,
  161,
  252,
  83,
  70,
  91,
  117,
  246,
  29,
  107,
  247,
  36,
  97,
  110,
  198,
  112,
  175,
  166,
  37,
  5,
  57,
  39,
  187,
];

List<int> _combineKeyParts() =>
    List<int>.generate(32, (i) => _keyPart1[i] ^ _keyPart2[i]);

/// ترتيب الخطط كبايت واحد بدل ما تتخزن كنص - بيوفر مساحة وبيمنع أي
/// اسم خطة غريب يتحط يدويًا.
const List<String> _planTable = [
  'demo',
  'monthly',
  'quarterly',
  'semiannual',
  'yearly',
  'lifetime',
  'custom',
];

int _planToByte(String plan) {
  final i = _planTable.indexOf(plan);
  return i == -1 ? _planTable.length - 1 : i; // fallback = custom
}

String _planFromByte(int b) =>
    (b >= 0 && b < _planTable.length) ? _planTable[b] : 'custom';

Uint8List _uint16(int v) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.big);
Uint8List _int32(int v) =>
    Uint8List(4)..buffer.asByteData().setInt32(0, v, Endian.big);

int _readUint16(List<int> b, int offset) =>
    ByteData.sublistView(Uint8List.fromList(b), offset, offset + 2)
        .getUint16(0, Endian.big);
int _readInt32(List<int> b, int offset) =>
    ByteData.sublistView(Uint8List.fromList(b), offset, offset + 4)
        .getInt32(0, Endian.big);

class LicenseCrypto {
  static const int nonceLength = 12; // AES-GCM
  static const int macLength = 16; // AES-GCM tag
  static const int signatureLength = 64; // Ed25519
  static const int fingerprintHashLength = 32; // SHA-256

  static final _aesAlgorithm = AesGcm.with256bits();
  static final _ed25519 = Ed25519();

  // -----------------------------------------------------------------
  // Binary payload encode/decode
  // -----------------------------------------------------------------

  /// بيحوّل بيانات الترخيص لصيغة binary مضغوطة (قبل التشفير).
  /// ملحوظة: بصمة الجهاز بتتخزن كـ SHA-256 hash (32 بايت) مش كنص خام،
  /// ده بيقصر الحجم وبيخلي حتى لو حد فك التشفير بالغلط ميلاقيش البصمة
  /// الخام للجهاز.
  static Uint8List encodePayload({
    required String customerName,
    required int maxUsers,
    required int maxDevices,
    required int? totalDays,
    required String plan,
    required String deviceFingerprint,
    required int slotNumber,
  }) {
    final nameBytes = utf8.encode(customerName);
    if (nameBytes.length > 255) {
      throw ArgumentError('customerName too long (max 255 bytes)');
    }
    final fpHash = sha256.convert(utf8.encode(deviceFingerprint)).bytes;

    final b = BytesBuilder();
    b.addByte(1); // version
    b.addByte(_planToByte(plan));
    b.add(_uint16(maxUsers));
    b.add(_uint16(maxDevices));
    b.add(_int32(totalDays ?? -1));
    b.addByte(slotNumber & 0xFF);
    b.add(fpHash); // 32 bytes
    b.addByte(nameBytes.length);
    b.add(nameBytes);
    return b.toBytes();
  }

  /// بيرجّع null لو الصيغة تالفة/غير معروفة.
  static Map<String, dynamic>? decodePayload(List<int> bytes) {
    try {
      if (bytes.length < 1 + 1 + 2 + 2 + 4 + 1 + fingerprintHashLength + 1) {
        return null;
      }
      var offset = 0;
      final version = bytes[offset++];
      if (version != 1) return null;

      final planByte = bytes[offset++];
      final maxUsers = _readUint16(bytes, offset);
      offset += 2;
      final maxDevices = _readUint16(bytes, offset);
      offset += 2;
      final totalDaysRaw = _readInt32(bytes, offset);
      offset += 4;
      final slotNumber = bytes[offset++];
      final fpHash = bytes.sublist(offset, offset + fingerprintHashLength);
      offset += fingerprintHashLength;
      final nameLen = bytes[offset++];
      if (offset + nameLen > bytes.length) return null;
      final customerName = utf8.decode(bytes.sublist(offset, offset + nameLen));

      return {
        'plan': _planFromByte(planByte),
        'maxUsers': maxUsers,
        'maxDevices': maxDevices,
        'totalDays': totalDaysRaw == -1 ? null : totalDaysRaw,
        'slotNumber': slotNumber,
        'deviceFingerprintHash': fpHash, // List<int>, 32 bytes
        'customerName': customerName,
      };
    } catch (_) {
      return null;
    }
  }

  // -----------------------------------------------------------------
  // تشفير + توقيع (بيتنادى من أداة الأدمن بس - هي الوحيدة اللي معاها
  // الـ private key)
  // -----------------------------------------------------------------
  static Future<Uint8List> encryptAndSign({
    required List<int> payloadBytes,
    required SimpleKeyPair signingKeyPair,
  }) async {
    final secretKey = SecretKey(_combineKeyParts());
    final nonce = _aesAlgorithm.newNonce();
    final secretBox = await _aesAlgorithm.encrypt(
      payloadBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final sealed = BytesBuilder()
      ..add(secretBox.nonce) // 12
      ..add(secretBox.cipherText) // متغيّر
      ..add(secretBox.mac.bytes); // 16
    final sealedBytes = sealed.toBytes();

    final signature = await _ed25519.sign(sealedBytes, keyPair: signingKeyPair);

    final result = BytesBuilder()
      ..add(sealedBytes)
      ..add(signature.bytes); // 64
    return result.toBytes();
  }

  // -----------------------------------------------------------------
  // تحقق من التوقيع + فك التشفير (بيتنادى من التطبيق الرئيسي بس)
  // -----------------------------------------------------------------
  static Future<Map<String, dynamic>?> verifyAndDecode({
    required List<int> licenseFileBytes,
    required String publicKeyBase64Url,
  }) async {
    try {
      final minLength = nonceLength + macLength + signatureLength;
      if (licenseFileBytes.length < minLength) return null;

      final sigStart = licenseFileBytes.length - signatureLength;
      final sealedBytes = licenseFileBytes.sublist(0, sigStart);
      final signatureBytes = licenseFileBytes.sublist(sigStart);

      final publicKey = SimplePublicKey(
        base64Url.decode(publicKeyBase64Url),
        type: KeyPairType.ed25519,
      );

      final isValid = await _ed25519.verify(
        sealedBytes,
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
      if (!isValid) return null;

      final nonce = sealedBytes.sublist(0, nonceLength);
      final macBytes = sealedBytes.sublist(sealedBytes.length - macLength);
      final cipherText =
          sealedBytes.sublist(nonceLength, sealedBytes.length - macLength);

      final secretKey = SecretKey(_combineKeyParts());
      final clear = await _aesAlgorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );

      return decodePayload(clear);
    } catch (_) {
      return null;
    }
  }

  /// مقارنة آمنة بين هاش بصمة الجهاز الحالي والهاش المخزّن في الكود.
  static bool fingerprintMatches(
      String currentFingerprint, List<int> storedHash) {
    final currentHash = sha256.convert(utf8.encode(currentFingerprint)).bytes;
    if (currentHash.length != storedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < currentHash.length; i++) {
      diff |= currentHash[i] ^ storedHash[i];
    }
    return diff == 0;
  }
}
 */
// lib/core/license/license_crypto.dart
//
// ⚠️ نفس المحتوى بالظبط في: payrolls + license_admin_tool
//
// ⚠️⚠️ المفاتيح اللي هنا مؤقتة (نُشرت في محادثة عامة). ولّد مفاتيحك
// بنفسك قبل النشر — راجع tools/generate_aes_key.dart في آخر الرد.
//
// ⚠️ الإصدار v2 من الـ payload: يستخدم issuedAt/expiresAt مطلقين بدل
// totalDays. الملفات المولّدة بـ v1 (النسخة القديمة) لن تُقبل من الآن.
// لو عندك تراخيص تجريبية قديمة، ولّدها من جديد بالأداة الجديدة.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';

// =========================================================================
// ⚠️⚠️⚠️  REPLACE THESE KEYS BEFORE PRODUCTION  ⚠️⚠️⚠️
// شغّل tools/generate_aes_key.dart واحط القيم الجديدة هنا وفي الأداة.
// =========================================================================
const List<int> _keyPart1 = [
  111,
  77,
  185,
  112,
  170,
  25,
  111,
  160,
  136,
  107,
  206,
  94,
  63,
  151,
  41,
  175,
  123,
  37,
  41,
  246,
  184,
  57,
  8,
  148,
  164,
  219,
  88,
  147,
  220,
  145,
  222,
  129,
];
const List<int> _keyPart2 = [
  39,
  139,
  73,
  242,
  109,
  31,
  191,
  41,
  161,
  43,
  114,
  15,
  89,
  133,
  83,
  29,
  37,
  146,
  164,
  240,
  134,
  17,
  175,
  55,
  15,
  129,
  138,
  36,
  81,
  143,
  108,
  173,
];

List<int> _combineKeyParts() =>
    List<int>.generate(32, (i) => _keyPart1[i] ^ _keyPart2[i]);

// =========================================================================

const List<String> _planTable = [
  'demo',
  'monthly',
  'quarterly',
  'semiannual',
  'yearly',
  'lifetime',
  'custom',
];

int _planToByteStrict(String plan) {
  final i = _planTable.indexOf(plan);
  if (i == -1) {
    throw ArgumentError.value(
        plan, 'plan', 'Unknown plan. Allowed: ${_planTable.join(', ')}');
  }
  return i;
}

String _planFromByte(int b) =>
    (b >= 0 && b < _planTable.length) ? _planTable[b] : 'custom';

Uint8List _uint16(int v) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.big);

Uint8List _int64(int v) =>
    Uint8List(8)..buffer.asByteData().setInt64(0, v, Endian.big);

int _readUint16(List<int> b, int offset) =>
    ByteData.sublistView(Uint8List.fromList(b), offset, offset + 2)
        .getUint16(0, Endian.big);

int _readInt64(List<int> b, int offset) =>
    ByteData.sublistView(Uint8List.fromList(b), offset, offset + 8)
        .getInt64(0, Endian.big);

class LicenseCrypto {
  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int signatureLength = 64;
  static const int fingerprintHashLength = 32;
  static const int maxLicenseFileSize = 64 * 1024;

  // Envelope version — بايت في أول الملف (مشمول في التوقيع)
  static const int envelopeVersion = 2;

  // Payload version — بايت في أول البيانات المشفّرة (قبل التشفير)
  static const int payloadVersion = 2;

  static final _aesAlgorithm = AesGcm.with256bits();
  static final _ed25519 = Ed25519();

  // -----------------------------------------------------------------------
  // Encode v2 payload
  // -----------------------------------------------------------------------
  static Uint8List encodePayload({
    required String customerName,
    required int maxUsers,
    required int maxDevices,
    required DateTime issuedAt,
    required DateTime? expiresAt, // null = lifetime
    required String plan,
    required String deviceFingerprint,
    required int slotNumber,
  }) {
    if (slotNumber < 0 || slotNumber > 255) {
      throw ArgumentError('slotNumber must be in 0..255, got $slotNumber');
    }
    if (maxUsers < 0 || maxUsers > 0xFFFF) {
      throw ArgumentError('maxUsers must be in 0..65535, got $maxUsers');
    }
    if (maxDevices < 0 || maxDevices > 0xFFFF) {
      throw ArgumentError('maxDevices must be in 0..65535, got $maxDevices');
    }
    if (expiresAt != null && expiresAt.isBefore(issuedAt)) {
      throw ArgumentError('expiresAt must be after issuedAt');
    }
    final nameBytes = utf8.encode(customerName);
    if (nameBytes.length > 255) {
      throw ArgumentError(
          'customerName too long (max 255 UTF-8 bytes, got ${nameBytes.length})');
    }
    final fpHash = sha256.convert(utf8.encode(deviceFingerprint)).bytes;

    final b = BytesBuilder()
      ..addByte(payloadVersion)
      ..addByte(_planToByteStrict(plan))
      ..add(_uint16(maxUsers))
      ..add(_uint16(maxDevices))
      ..add(_int64(issuedAt.millisecondsSinceEpoch))
      ..add(_int64(expiresAt?.millisecondsSinceEpoch ?? -1))
      ..addByte(slotNumber)
      ..add(fpHash)
      ..addByte(nameBytes.length)
      ..add(nameBytes);
    return b.toBytes();
  }

  // -----------------------------------------------------------------------
  // Decode payload (v2 only)
  // -----------------------------------------------------------------------
  static Map<String, dynamic>? decodePayload(List<int> bytes) {
    try {
      const minLen = 1 + 1 + 2 + 2 + 8 + 8 + 1 + fingerprintHashLength + 1;
      if (bytes.length < minLen) return null;

      var offset = 0;
      final version = bytes[offset++];
      if (version != payloadVersion) return null;

      final planByte = bytes[offset++];
      final maxUsers = _readUint16(bytes, offset);
      offset += 2;
      final maxDevices = _readUint16(bytes, offset);
      offset += 2;
      final issuedAtMs = _readInt64(bytes, offset);
      offset += 8;
      final expiresAtMs = _readInt64(bytes, offset);
      offset += 8;
      final slotNumber = bytes[offset++];
      final fpHash = bytes.sublist(offset, offset + fingerprintHashLength);
      offset += fingerprintHashLength;
      final nameLen = bytes[offset++];
      if (offset + nameLen > bytes.length) return null;
      final customerName = utf8.decode(bytes.sublist(offset, offset + nameLen));
      offset += nameLen;

      if (offset != bytes.length) return null; // trailing bytes → reject

      return {
        'plan': _planFromByte(planByte),
        'maxUsers': maxUsers,
        'maxDevices': maxDevices,
        'issuedAt': DateTime.fromMillisecondsSinceEpoch(issuedAtMs),
        'expiresAt': expiresAtMs == -1
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
        'slotNumber': slotNumber,
        'deviceFingerprintHash': fpHash,
        'customerName': customerName,
      };
    } catch (_) {
      return null;
    }
  }

  // -----------------------------------------------------------------------
  // Encrypt + sign (admin tool only)
  // -----------------------------------------------------------------------
  static Future<Uint8List> encryptAndSign({
    required List<int> payloadBytes,
    required SimpleKeyPair signingKeyPair,
  }) async {
    final secretKey = SecretKey(_combineKeyParts());
    // ⚠️ NEVER reuse nonce with same key.
    final nonce = _aesAlgorithm.newNonce();
    final secretBox = await _aesAlgorithm.encrypt(
      payloadBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // الموقّع عليه: envelopeVersion || nonce || ciphertext || mac
    final signedPart = (BytesBuilder()
          ..addByte(envelopeVersion)
          ..add(secretBox.nonce)
          ..add(secretBox.cipherText)
          ..add(secretBox.mac.bytes))
        .toBytes();

    final signature = await _ed25519.sign(signedPart, keyPair: signingKeyPair);

    return (BytesBuilder()
          ..add(signedPart)
          ..add(signature.bytes))
        .toBytes();
  }

  // -----------------------------------------------------------------------
  // Verify + decrypt (client app)
  // -----------------------------------------------------------------------
  static Future<Map<String, dynamic>?> verifyAndDecode({
    required List<int> licenseFileBytes,
    required String publicKeyBase64Url,
  }) async {
    try {
      if (licenseFileBytes.isEmpty) return null;
      if (licenseFileBytes.length > maxLicenseFileSize) return null;

      final version = licenseFileBytes[0];
      if (version != envelopeVersion) return null;

      const minLen = 1 + nonceLength + macLength + signatureLength;
      if (licenseFileBytes.length < minLen) return null;

      final sigStart = licenseFileBytes.length - signatureLength;
      final signedPart = licenseFileBytes.sublist(0, sigStart);
      final signatureBytes = licenseFileBytes.sublist(sigStart);

      final publicKey = SimplePublicKey(
        base64Url.decode(publicKeyBase64Url),
        type: KeyPairType.ed25519,
      );

      final isValid = await _ed25519.verify(
        signedPart,
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
      if (!isValid) return null;

      // استخراج sealed (بدون version byte)
      final sealed = signedPart.sublist(1);
      final nonce = sealed.sublist(0, nonceLength);
      final macBytes = sealed.sublist(sealed.length - macLength);
      final cipherText = sealed.sublist(nonceLength, sealed.length - macLength);

      final secretKey = SecretKey(_combineKeyParts());
      final clear = await _aesAlgorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );

      return decodePayload(clear);
    } catch (_) {
      return null;
    }
  }

  static bool fingerprintMatches(
    String currentFingerprint,
    List<int> storedHash,
  ) {
    final currentHash = sha256.convert(utf8.encode(currentFingerprint)).bytes;
    if (currentHash.length != storedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < currentHash.length; i++) {
      diff |= currentHash[i] ^ storedHash[i];
    }
    return diff == 0;
  }
}
