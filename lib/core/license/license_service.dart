import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'device_fingerprint.dart';
import 'license_model.dart';

/// نظام ترخيص أوفلاين بالكامل - نسخة "عد تنازلي مقاوم للتلاعب بالتاريخ".
///
/// المبدأ:
/// - كل كود مربوط ببصمة جهاز واحد بعينه من لحظة توليده (مايتنقلش لجهاز تاني).
/// - بدل ما نعتمد على "تاريخ انتهاء ثابت" (سهل التحايل عليه برجّع ساعة
///   الجهاز للخلف)، بنحتفظ بـ:
///     • remainingDays  → عدد الأيام المتبقية فعليًا
///     • lastCheckDate  → آخر يوم اتفتح فيه البرنامج وتم الفحص
///   كل مرة البرنامج يفتح:
///     • لو النهاردة *قبل* lastCheckDate  → التاريخ اتلاعب بيه (رجع للخلف)
///       → نرفض الفتح لحد ما المستخدم يرجّع التاريخ لقدام تاني.
///     • لو النهاردة *بعد* lastCheckDate  → ننقص الفرق بالأيام من
///       remainingDays ونحدّث lastCheckDate = النهاردة.
///     • لو remainingDays وصل صفر أو أقل → الترخيص انتهى فعلاً.
/// - كود الديمو (plan == 'demo') لا يُقبل على نفس الجهاز أكتر من مرة،
///   حتى لو الديمو الأول خلص، عن طريق علامة دائمة (demo_used) في الجهاز.
class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const String _publicKeyBase64 =
      'bc5cni8t2LDGdO2rPslHVbpzhX7RQ2XEVkbErPhTQ5Q=';

  final _algorithm = Ed25519();

  /// بنشتغل بتوقيت UTC مش وقت الجهاز المحلي - عشان لو المستخدم سافر
  /// وغيّر المنطقة الزمنية بشكل شرعي (رحلة، تغيير إعدادات بلد)، الساعة
  /// المحلية ممكن "ترجع" لحظيًا وده كان بيتفسّر غلط كتلاعب. UTC ثابت
  /// عالميًا ومابيتأثرش بتغيير المنطقة الزمنية خالص.
  DateTime _dateOnly(DateTime d) {
    final u = d.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
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

    // منع استخدام أكتر من ديمو واحد على نفس الجهاز، حتى لو الأول انتهى
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
    final db = await AppDatabase.instance.database;

    await db.insert(
      'license',
      {
        'id': 1,
        'licenseJson': jsonEncode(license.toJson()),
        'activatedAt': DateTime.now().toIso8601String(),
        'lastCheckDate': today.toIso8601String(),
        'remainingDays': license.totalDays, // null = دائم
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
    final license =
        LicenseData.fromJson(jsonDecode(row['licenseJson'] as String));

    // ترخيص دائم (plan == lifetime أو totalDays null) - مفيش عد تنازلي خالص
    if (license.totalDays == null) {
      return const LicenseCheckResult(true, 'ok');
    }

    final today = _dateOnly(DateTime.now());
    final lastCheckDate =
        _dateOnly(DateTime.parse(row['lastCheckDate'] as String));
    int remainingDays = row['remainingDays'] as int;

    if (today.isBefore(lastCheckDate)) {
      // تاريخ الجهاز اترجع للخلف - تلاعب واضح. نرفض لحد ما يرجّعوا لقدام.
      return LicenseCheckResult(false, 'license_error_clock_tampered',
          remainingDays: remainingDays);
    }

    if (today.isAfter(lastCheckDate)) {
      final daysPassed = today.difference(lastCheckDate).inDays;
      remainingDays -= daysPassed;

      await db.update(
        'license',
        {
          'lastCheckDate': today.toIso8601String(),
          'remainingDays': remainingDays,
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

  /// بيرجع عدد الأيام المتبقية من غير ما يعمل أي تحديث (للعرض بس، مثلاً
  /// في شاشة "معلومات الترخيص"). استخدم validate() لو عايز فحص فعلي.
  Future<int?> getRemainingDaysDisplay() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('license', where: 'id = 1');
    if (rows.isEmpty) return null;
    return rows.first['remainingDays'] as int?;
  }

  Future<String> currentDeviceFingerprint() => DeviceFingerprint.get();

  // ---------------------------------------------------------------------
  // جدول صغير key-value لتخزين أعلام دائمة زي "demo_used"
  // ---------------------------------------------------------------------
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
