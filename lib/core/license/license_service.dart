import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide Hmac;
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'device_fingerprint.dart';
import 'license_model.dart';

/// نظام ترخيص أوفلاين بالكامل - نسخة "عد تنازلي مقاوم للتلاعب بالتاريخ
/// + ختم تكامل مقاوم لتعديل قاعدة البيانات مباشرة".
///
/// المبدأ:
/// - كل كود مربوط ببصمة جهاز واحد بعينه من لحظة توليده (مايتنقلش لجهاز تاني).
/// - بدل "تاريخ انتهاء ثابت"، بنحتفظ بعدّاد أيام (remainingDays) + آخر
///   يوم اتفحص فيه (lastCheckDate)، ولو الساعة رجعت للخلف نرفض الفتح.
/// - ⚠️ الإضافة الجديدة: بنخزّن الكود الموقّع الأصلي (rawCode) ونعيد
///   التحقق من توقيعه في **كل مرة** (مش وقت التفعيل بس)، وبنحط "ختم
///   تكامل" (HMAC) فوق القيم المتغيّرة. لو حد فتح قاعدة البيانات بأداة
///   خارجية وغيّر remainingDays أو أي قيمة يدويًا، الختم مش هيتطابق
///   والبرنامج هيرفض الفتح فورًا - بدل ما يثق أعمى في أي قيمة مخزّنة.
class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const String _publicKeyBase64 =
      'bc5cni8t2LDGdO2rPslHVbpzhX7RQ2XEVkbErPhTQ5Q=';

  final _algorithm = Ed25519();

  DateTime _dateOnly(DateTime d) {
    final u = d.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
  }

  // ---------------------------------------------------------------------
  // ختم التكامل: HMAC-SHA256 بمفتاح مشتق من التطبيق نفسه (مش من قاعدة
  // البيانات) - أي تعديل يدوي في القيم المخزّنة بيكسر التطابق فورًا.
  // ---------------------------------------------------------------------
  List<int> get _integrityKey => sha256
      .convert(utf8.encode('$_publicKeyBase64::payrolls-integrity-v1'))
      .bytes;

  String _computeSeal({
    required String rawCode,
    required String activationDate,
    required String lastCheckDate,
    required int? remainingDays,
    required String deviceFingerprint,
  }) {
    final payload =
        '$rawCode|$activationDate|$lastCheckDate|$remainingDays|$deviceFingerprint';
    return Hmac(sha256, _integrityKey).convert(utf8.encode(payload)).toString();
  }

  // ---------------------------------------------------------------------
  // تفعيل الجهاز الحالي بكود مربوط بيه من الأساس (خطوة واحدة بس)
  // ---------------------------------------------------------------------
  Future<String> activate(String code) async {
    final decoded = await verifyCode(code);
    if (decoded == null) return 'license_error_invalid_code';

    final currentFingerprint = await DeviceFingerprint.get();
    if (decoded['deviceFingerprint'] != currentFingerprint) {
      return 'license_error_device_mismatch';
    }

    final plan = decoded['plan'] as String? ?? 'custom';

    if (plan == 'demo') {
      final alreadyUsed = await _getMeta('demo_used');
      if (alreadyUsed == 'true') {
        return 'license_error_demo_already_used';
      }
    }

    final license = LicenseData(
      customerName: decoded['customerName'],
      maxUsers: decoded['maxUsers'],
      maxDevices: decoded['maxDevices'],
      totalDays: decoded['totalDays'],
      plan: plan,
    );

    final today = _dateOnly(DateTime.now());
    final todayIso = today.toIso8601String();
    final db = await AppDatabase.instance.database;

    final seal = _computeSeal(
      rawCode: code,
      activationDate: todayIso,
      lastCheckDate: todayIso,
      remainingDays: license.totalDays,
      deviceFingerprint: currentFingerprint,
    );

    await db.insert(
      'license',
      {
        'id': 1,
        'licenseJson': jsonEncode(license.toJson()),
        'activatedAt': DateTime.now().toIso8601String(),
        'lastCheckDate': todayIso,
        'remainingDays': license.totalDays, // null = دائم
        'rawCode': code,
        'integritySeal': seal,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      'activated_devices',
      {
        'deviceFingerprint': currentFingerprint,
        'slotNumber': decoded['slotNumber'] ?? 0,
        'activatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (plan == 'demo') {
      await _setMeta('demo_used', 'true');
    }

    return 'ok';
  }

  // ---------------------------------------------------------------------
  // الفحص اليومي: بيتنادى عند فتح البرنامج / عند تسجيل الدخول
  // ---------------------------------------------------------------------
  Future<LicenseCheckResult> validate() async {
    final fingerprint = await DeviceFingerprint.get();
    final db = await AppDatabase.instance.database;

    final activated = await db.query(
      'activated_devices',
      where: 'deviceFingerprint = ?',
      whereArgs: [fingerprint],
    );
    if (activated.isEmpty) {
      return const LicenseCheckResult(false, 'license_error_not_activated');
    }

    final rows = await db.query('license', where: 'id = 1');
    if (rows.isEmpty) {
      return const LicenseCheckResult(false, 'license_error_not_activated');
    }

    final row = rows.first;
    final rawCode = row['rawCode'] as String?;
    final storedSeal = row['integritySeal'] as String?;

    // صف قديم من قبل إضافة الختم - محتاج إعادة تفعيل مرة واحدة عشان
    // ياخد الحماية الجديدة (مفيش طريقة نولّد ختم لبيانات قديمة من غيره).
    if (rawCode == null || storedSeal == null) {
      return const LicenseCheckResult(false, 'license_error_not_activated');
    }

    // إعادة التحقق من توقيع الكود الأصلي - مش هنثق في licenseJson المخزّن
    final decoded = await verifyCode(rawCode);
    if (decoded == null) {
      return const LicenseCheckResult(false, 'license_error_data_tampered');
    }

    final lastCheckDateRaw = row['lastCheckDate'] as String;
    final remainingDaysRaw = row['remainingDays'] as int?;
    final activatedAtRaw = row['activatedAt'] as String;
    // activationDate المستخدم في الختم وقت التفعيل كان lastCheckDate يوم
    // التفعيل نفسه (نفس القيمة وقتها) - فبنعيد حساب الختم بنفس القيم
    // المخزّنة دلوقتي عشان نتأكد إنها لسه زي ما اتسابت.
    final expectedSeal = _computeSeal(
      rawCode: rawCode,
      activationDate: activatedAtRaw,
      lastCheckDate: lastCheckDateRaw,
      remainingDays: remainingDaysRaw,
      deviceFingerprint: fingerprint,
    );

    if (expectedSeal != storedSeal) {
      // القيم المخزّنة اتغيّرت من بره البرنامج (تعديل يدوي في قاعدة البيانات)
      return const LicenseCheckResult(false, 'license_error_data_tampered');
    }

    final totalDays = decoded['totalDays'] as int?;

    if (totalDays == null) {
      return const LicenseCheckResult(true, 'ok'); // ترخيص دائم
    }

    final today = _dateOnly(DateTime.now());
    final lastCheckDate = _dateOnly(DateTime.parse(lastCheckDateRaw));
    int remainingDays = remainingDaysRaw ?? totalDays;

    if (today.isBefore(lastCheckDate)) {
      return LicenseCheckResult(false, 'license_error_clock_tampered',
          remainingDays: remainingDays);
    }

    if (today.isAfter(lastCheckDate)) {
      final daysPassed = today.difference(lastCheckDate).inDays;
      remainingDays -= daysPassed;

      final newLastCheckIso = today.toIso8601String();
      final newSeal = _computeSeal(
        rawCode: rawCode,
        activationDate: activatedAtRaw,
        lastCheckDate: newLastCheckIso,
        remainingDays: remainingDays,
        deviceFingerprint: fingerprint,
      );

      await db.update(
        'license',
        {
          'lastCheckDate': newLastCheckIso,
          'remainingDays': remainingDays,
          'integritySeal': newSeal, // لازم نحدّث الختم مع كل تحديث شرعي
        },
        where: 'id = 1',
      );
    }

    if (remainingDays <= 0) {
      return LicenseCheckResult(false, 'license_error_expired',
          remainingDays: 0);
    }

    return LicenseCheckResult(true, 'ok', remainingDays: remainingDays);
  }

  Future<LicenseData?> getActiveLicense() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('license', where: 'id = 1');
    if (rows.isEmpty) return null;
    return LicenseData.fromJson(
        jsonDecode(rows.first['licenseJson'] as String));
  }

  Future<int?> getRemainingDaysDisplay() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('license', where: 'id = 1');
    if (rows.isEmpty) return null;
    return rows.first['remainingDays'] as int?;
  }

  Future<String> currentDeviceFingerprint() => DeviceFingerprint.get();

  Future<String?> _getMeta(String key) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('app_meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> _setMeta(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
