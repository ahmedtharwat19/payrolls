import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'device_fingerprint.dart';
import 'license_model.dart';

/// نظام ترخيص أوفلاين بالكامل:
/// - المفتاح الخاص عندك انت بس (في أداة الـ generator، خارج التطبيق نهائيًا)
/// - المفتاح العام مدمج هنا في التطبيق عشان يتحقق بس، مايقدرش يوقّع
///
/// ⚠️ لازم تستبدل _publicKeyBase64 بالمفتاح العام اللي هيطلعلك من generate_keys.dart
class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const String _publicKeyBase64 = 'REPLACE_WITH_YOUR_PUBLIC_KEY_BASE64';

  final _algorithm = Ed25519();

  // ---------------------------------------------------------------------
  // 1) تفعيل ترخيص العميل (مرة واحدة لكل شركة/عميل)
  // ---------------------------------------------------------------------
  Future<String> activateLicense(String licenseCode) async {
    final decoded = await verifyCode(licenseCode);
    if (decoded == null) return 'كود الترخيص غير صحيح أو تم التلاعب به';

    final db = await AppDatabase.instance.database;
    await db.insert(
      'license',
      {
        'id': 1,
        'licenseJson': jsonEncode(decoded),
        'activatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return 'ok';
  }

  // ---------------------------------------------------------------------
  // 2) تفعيل الجهاز الحالي (بعد ما تبعت بصمة الجهاز للمُصدر ويرجعلك كود)
  // ---------------------------------------------------------------------
  Future<String> activateDevice(String activationCode) async {
    final decoded = await verifyCode(activationCode);
    if (decoded == null) return 'كود التفعيل غير صحيح أو تم التلاعب به';

    final currentFingerprint = await DeviceFingerprint.get();
    if (decoded['deviceFingerprint'] != currentFingerprint) {
      return 'كود التفعيل ده خاص بجهاز تاني، مش الجهاز ده';
    }

    final license = await getActiveLicense();
    if (license == null) return 'لازم تفعّل ترخيص الشركة الأول قبل تفعيل الجهاز';

    final db = await AppDatabase.instance.database;
    final deviceCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM activated_devices'),
        ) ??
        0;

    final alreadyActivated = await db.query(
      'activated_devices',
      where: 'deviceFingerprint = ?',
      whereArgs: [currentFingerprint],
    );

    if (alreadyActivated.isEmpty && deviceCount >= license.maxDevices) {
      return 'وصلت للحد الأقصى لعدد الأجهزة المسموح بها (${license.maxDevices})';
    }

    await db.insert(
      'activated_devices',
      {
        'deviceFingerprint': currentFingerprint,
        'slotNumber': decoded['slotNumber'] ?? 0,
        'activatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return 'ok';
  }

  // ---------------------------------------------------------------------
  // 3) الفحص اليومي: بيتنادى عند فتح البرنامج / عند تسجيل الدخول
  // ---------------------------------------------------------------------
  Future<LicenseCheckResult> validate() async {
    final license = await getActiveLicense();
    if (license == null) {
      return const LicenseCheckResult(false, 'البرنامج غير مُفعّل. برجاء إدخال كود الترخيص');
    }
    if (license.isExpired) {
      return const LicenseCheckResult(false, 'انتهت صلاحية الترخيص، برجاء التجديد');
    }

    final fingerprint = await DeviceFingerprint.get();
    final db = await AppDatabase.instance.database;
    final activated = await db.query(
      'activated_devices',
      where: 'deviceFingerprint = ?',
      whereArgs: [fingerprint],
    );

    if (activated.isEmpty) {
      return const LicenseCheckResult(false, 'هذا الجهاز غير مُفعّل. برجاء إدخال كود تفعيل الجهاز');
    }

    return const LicenseCheckResult(true, 'ok');
  }

  Future<LicenseData?> getActiveLicense() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('license', where: 'id = 1');
    if (rows.isEmpty) return null;
    return LicenseData.fromJson(jsonDecode(rows.first['licenseJson'] as String));
  }

  Future<String> currentDeviceFingerprint() => DeviceFingerprint.get();

  // ---------------------------------------------------------------------
  // التحقق من التوقيع الرقمي - القلب الأمني للنظام كله
  // كود الترخيص شكله: base64(JSON بيانات).base64(توقيع)
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>?> verifyCode(String code) async {
    try {
      final parts = code.trim().split('.');
      if (parts.length != 2) return null;

      final payloadBytes = base64Url.decode(parts[0]);
      final signatureBytes = base64Url.decode(parts[1]);

      final publicKey = SimplePublicKey(
        base64Url.decode(_publicKeyBase64),
        type: KeyPairType.ed25519,
      );

      final isValid = await _algorithm.verify(
        payloadBytes,
        signature: Signature(signatureBytes, publicKey: publicKey),
      );

      if (!isValid) return null;
      return jsonDecode(utf8.decode(payloadBytes));
    } catch (_) {
      return null;
    }
  }
}
