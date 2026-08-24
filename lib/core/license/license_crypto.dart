// lib/core/license/license_crypto.dart
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
