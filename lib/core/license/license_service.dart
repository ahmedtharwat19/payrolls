/* import 'dart:convert';
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

    try {
      await db.insert(
        'license',
        {
          'id': 1,
          'licenseJson': jsonEncode(license.toJson()),
          // ⚠️ لازم تكون نفس القيمة (todayIso) اللي اتحسب بيها الـ seal
          // فوق، مش DateTime.now().toIso8601String() لوحدها - لأن أي
          // فرق ولو جزء من الثانية بيخلي الختم مش متطابق من أول تفعيل.
          'activatedAt': todayIso,
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
    } catch (e) {
      // ما نسيبش الخطأ يفضل "صامت" ويوهم المستخدم إن الزرار مش شغال -
      // زي ما حصل لما كان فيه عمود ناقص في قاعدة البيانات بعد ترقية غير مكتملة.
      return 'license_error_activation_failed';
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
 */ /* 
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'device_fingerprint.dart';
import 'license_crypto.dart';
import 'license_model.dart';

/// نظام ترخيص أوفلاين بالكامل - نسخة "عد تنازلي مقاوم للتلاعب بالتاريخ
/// + ختم تكامل مقاوم لتعديل قاعدة البيانات مباشرة + تشفير AES-256-GCM
/// فوق التوقيع Ed25519".
///
/// المبدأ (زي قبل كده):
/// - كل كود مربوط ببصمة جهاز واحد بعينه من لحظة توليده (مايتنقلش لجهاز تاني).
/// - بدل "تاريخ انتهاء ثابت"، بنحتفظ بعدّاد أيام (remainingDays) + آخر
///   يوم اتفحص فيه (lastCheckDate)، ولو الساعة رجعت للخلف نرفض الفتح.
/// - بنخزّن الكود الموقّع/المشفّر الأصلي (rawCode) ونعيد التحقق منه في
///   **كل مرة** (مش وقت التفعيل بس)، وبنحط "ختم تكامل" (HMAC) فوق القيم
///   المتغيّرة. لو حد فتح قاعدة البيانات بأداة خارجية وغيّر remainingDays
///   يدويًا، الختم مش هيتطابق والبرنامج هيرفض الفتح فورًا.
///
/// ⚠️ الإضافة الجديدة (طبقة التشفير): الكود دلوقتي مش JSON واضح ممضي -
/// هو binary مشفّر بـ AES-256-GCM ثم موقّع بـ Ed25519. محدش يقدر يقرا
/// محتواه (اسم العميل، البصمة، الخطة...) غير التطبيق نفسه اللي معاه
/// مفتاح فك التشفير. راجع تعليقات license_crypto.dart لتفاصيل أكتر.
class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const String _publicKeyBase64 =
      'bc5cni8t2LDGdO2rPslHVbpzhX7RQ2XEVkbErPhTQ5Q=';

  // قيمة ثابتة بتتخزن في عمود rawCode بدل كود موقّع حقيقي، عشان نميّز
  // "ديمو محلي بدأه المستخدم بنفسه" عن "ترخيص جه من الأدمن موقّع
  // وموزّع". لما validate() تلاقي القيمة دي، تعرف إنها متحتاجش تتحقق
  // من توقيع Ed25519 (مفيش توقيع أصلاً)، لكن لسه محتاجة تتحقق من ختم
  // الـ HMAC العادي.
  static const String _localDemoMarker = 'LOCAL_DEMO_V1';

  DateTime _dateOnly(DateTime d) {
    final u = d.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
  }

  // ---------------------------------------------------------------------
  // ختم التكامل: HMAC-SHA256 بمفتاح مشتق من التطبيق نفسه (مش من قاعدة
  // البيانات) - أي تعديل يدوي في القيم المخزّنة بيكسر التطابق فورًا.
  // rawCode هنا بقى base64 لبيانات binary مشفّرة، لكن المنطق نفسه زي
  // قبل كده تمامًا: أي حرف يتغيّر فيه بيكسر الختم.
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
  // تفعيل الجهاز الحالي بملف ترخيص (.lic) - الطريقة الأساسية دلوقتي.
  // ---------------------------------------------------------------------
  Future<String> activateFromBytes(List<int> licenseFileBytes) async {
    final decoded = await verifyLicenseBytes(licenseFileBytes);
    if (decoded == null) return 'license_error_invalid_code';

    return _activateWithDecoded(
      decoded: decoded,
      rawCodeText: base64Url.encode(licenseFileBytes),
    );
  }

  /// مسار احتياطي (متقدّم) لو حابب تلصق الكود كنص بدل ملف - النص هنا
  /// عبارة عن base64Url لنفس البيانات الـ binary المشفّرة (مش JSON واضح
  /// زي قبل كده)، فبرضه محدش يقدر يقرا محتواه.
  Future<String> activate(String pastedCode) async {
    List<int> bytes;
    try {
      bytes = base64Url.decode(pastedCode.trim());
    } catch (_) {
      return 'license_error_invalid_code';
    }
    return activateFromBytes(bytes);
  }

  // ---------------------------------------------------------------------
  // ديمو محلي بدون أي كود/ملف من الأدمن - المستخدم بيدوس زرار جوه
  // التطبيق نفسه ويشتغل على طول. شهر تقويمي كامل، ومحمي بختم HMAC زي
  // أي ترخيص تاني (تعديل remainingDays يدويًا في قاعدة البيانات بيكسر
  // الختم ويرفض الفتح فورًا)، لكن من غير توقيع Ed25519 لأنه مفيش أدمن
  // بيوقّع حاجة هنا أصلاً - ده بديل أخف حماية مقصود، مناسب لتجربة
  // مجانية قصيرة مش لترخيص مدفوع.
  // ---------------------------------------------------------------------
  Future<bool> isDemoAvailable() async {
    final used = await _getMeta('demo_used');
    return used != 'true';
  }

  Future<String> activateLocalDemo() async {
    final alreadyUsed = await _getMeta('demo_used');
    if (alreadyUsed == 'true') {
      return 'license_error_demo_already_used';
    }

    final fingerprint = await DeviceFingerprint.get();
    final today = _dateOnly(DateTime.now());
    final todayIso = today.toIso8601String();

    // شهر تقويمي كامل زي باقي الخطط في أداة الأدمن (مش 30 يوم ثابت).
    final endDate = DateTime.utc(today.year, today.month + 1, today.day);
    final totalDays = endDate.difference(today).inDays;

    final license = LicenseData(
      customerName: 'Trial',
      maxUsers: 1,
      maxDevices: 1,
      totalDays: totalDays,
      plan: 'demo',
    );

    final seal = _computeSeal(
      rawCode: _localDemoMarker,
      activationDate: todayIso,
      lastCheckDate: todayIso,
      remainingDays: totalDays,
      deviceFingerprint: fingerprint,
    );

    final db = await AppDatabase.instance.database;
    try {
      await db.insert(
        'license',
        {
          'id': 1,
          'licenseJson': jsonEncode(license.toJson()),
          'activatedAt': todayIso,
          'lastCheckDate': todayIso,
          'remainingDays': totalDays,
          'rawCode': _localDemoMarker,
          'integritySeal': seal,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.insert(
        'activated_devices',
        {
          'deviceFingerprint': fingerprint,
          'slotNumber': 0,
          'activatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _setMeta('demo_used', 'true');
    } catch (e) {
      return 'license_error_activation_failed';
    }

    return 'ok';
  }

  Future<String> _activateWithDecoded({
    required Map<String, dynamic> decoded,
    required String rawCodeText,
  }) async {
    final currentFingerprint = await DeviceFingerprint.get();
    final storedHash = decoded['deviceFingerprintHash'] as List<int>;
    if (!LicenseCrypto.fingerprintMatches(currentFingerprint, storedHash)) {
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
      rawCode: rawCodeText,
      activationDate: todayIso,
      lastCheckDate: todayIso,
      remainingDays: license.totalDays,
      deviceFingerprint: currentFingerprint,
    );

    try {
      await db.insert(
        'license',
        {
          'id': 1,
          'licenseJson': jsonEncode(license.toJson()),
          // ⚠️ لازم تكون نفس القيمة (todayIso) اللي اتحسب بيها الـ seal
          // فوق، مش DateTime.now().toIso8601String() لوحدها.
          'activatedAt': todayIso,
          'lastCheckDate': todayIso,
          'remainingDays': license.totalDays, // null = دائم
          'rawCode': rawCodeText,
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
    } catch (e) {
      return 'license_error_activation_failed';
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

    // صف قديم من قبل إضافة الختم/التشفير - محتاج إعادة تفعيل مرة واحدة
    // عشان ياخد الحماية الجديدة.
    if (rawCode == null || storedSeal == null) {
      return const LicenseCheckResult(false, 'license_error_not_activated');
    }

    // إعادة التحقق من توقيع/تشفير الكود الأصلي - مش هنثق في licenseJson
    // المخزّن. الاستثناء الوحيد: الديمو المحلي (مفيش توقيع أصلاً لأنه
    // اتفعّل من غير أدمن)، فبنعتمد بس على ختم الـ HMAC تحته.
    final isLocalDemo = rawCode == _localDemoMarker;
    int? totalDaysFromDecoded;

    if (!isLocalDemo) {
      Map<String, dynamic>? decoded;
      try {
        decoded = await verifyLicenseBytes(base64Url.decode(rawCode));
      } catch (_) {
        decoded = null;
      }
      if (decoded == null) {
        return const LicenseCheckResult(false, 'license_error_data_tampered');
      }
      totalDaysFromDecoded = decoded['totalDays'] as int?;
    }
    // الديمو المحلي مايكونش دائم أبدًا، فـ totalDaysFromDecoded بتفضل
    // null بس مش هتتفسّر كـ "ترخيص دائم" لأن isLocalDemo بيتفحص تحت.

    final lastCheckDateRaw = row['lastCheckDate'] as String;
    final remainingDaysRaw = row['remainingDays'] as int?;
    final activatedAtRaw = row['activatedAt'] as String;
    final expectedSeal = _computeSeal(
      rawCode: rawCode,
      activationDate: activatedAtRaw,
      lastCheckDate: lastCheckDateRaw,
      remainingDays: remainingDaysRaw,
      deviceFingerprint: fingerprint,
    );

    if (expectedSeal != storedSeal) {
      return const LicenseCheckResult(false, 'license_error_data_tampered');
    }

    if (!isLocalDemo && totalDaysFromDecoded == null) {
      return const LicenseCheckResult(true, 'ok'); // ترخيص دائم
    }

    final today = _dateOnly(DateTime.now());
    final lastCheckDate = _dateOnly(DateTime.parse(lastCheckDateRaw));
    // remainingDaysRaw لازم يكون موجود دايمًا هنا (بيتحط وقت التفعيل
    // في activateFromBytes/activateLocalDemo)، لكن fallback آمن لو حصل
    // أي ظرف غريب: للديمو المحلي مفيش totalDays مخزّن غير remainingDays
    // نفسه، وللتراخيص العادية بنرجع لـ totalDaysFromDecoded.
    int remainingDays = remainingDaysRaw ?? totalDaysFromDecoded ?? 0;

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
          'integritySeal': newSeal,
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

  /// تحقق من ملف/بيانات ترخيص binary (موقّعة ومشفّرة) وإرجاع بياناته لو
  /// سليمة، أو null لو تالفة/موقّعة بمفتاح غلط/متلاعب فيها.
  Future<Map<String, dynamic>?> verifyLicenseBytes(List<int> bytes) {
    return LicenseCrypto.verifyAndDecode(
      licenseFileBytes: bytes,
      publicKeyBase64Url: _publicKeyBase64,
    );
  }
}
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'device_fingerprint.dart';
import 'license_crypto.dart';
import 'license_model.dart';

/// نظام ترخيص أوفلاين بالكامل - نسخة "عد تنازلي مقاوم للتلاعب بالتاريخ
/// + ختم تكامل مقاوم لتعديل قاعدة البيانات مباشرة + تشفير AES-256-GCM
/// فوق التوقيع Ed25519".
///
/// المبدأ (زي قبل كده):
/// - كل كود مربوط ببصمة جهاز واحد بعينه من لحظة توليده (مايتنقلش لجهاز تاني).
/// - بدل "تاريخ انتهاء ثابت"، بنحتفظ بعدّاد أيام (remainingDays) + آخر
///   يوم اتفحص فيه (lastCheckDate)، ولو الساعة رجعت للخلف نرفض الفتح.
/// - بنخزّن الكود الموقّع/المشفّر الأصلي (rawCode) ونعيد التحقق منه في
///   **كل مرة** (مش وقت التفعيل بس)، وبنحط "ختم تكامل" (HMAC) فوق القيم
///   المتغيّرة. لو حد فتح قاعدة البيانات بأداة خارجية وغيّر remainingDays
///   يدويًا، الختم مش هيتطابق والبرنامج هيرفض الفتح فورًا.
///
/// ⚠️ الإضافة الجديدة (طبقة التشفير): الكود دلوقتي مش JSON واضح ممضي -
/// هو binary مشفّر بـ AES-256-GCM ثم موقّع بـ Ed25519. محدش يقدر يقرا
/// محتواه (اسم العميل، البصمة، الخطة...) غير التطبيق نفسه اللي معاه
/// مفتاح فك التشفير. راجع تعليقات license_crypto.dart لتفاصيل أكتر.
class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  // ⚠️ مفتاح جديد بعد تدوير المفتاح (Key Rotation) بتاريخ 2026-08-17 -
  // المفتاح القديم اتسرّب في git history لريبو public على GitHub.
  // راجع compromised_keys_backup للمرجعية لو احتجت تتبّع تراخيص قديمة.
  static const String _publicKeyBase64 =
      '2YvaBI0PQnulucFLW_XitiK8ALBLBEghvmDPrXF9iXU=';

  // قيمة ثابتة بتتخزن في عمود rawCode بدل كود موقّع حقيقي، عشان نميّز
  // "ديمو محلي بدأه المستخدم بنفسه" عن "ترخيص جه من الأدمن موقّع
  // وموزّع". لما validate() تلاقي القيمة دي، تعرف إنها متحتاجش تتحقق
  // من توقيع Ed25519 (مفيش توقيع أصلاً)، لكن لسه محتاجة تتحقق من ختم
  // الـ HMAC العادي.
  static const String _localDemoMarker = 'LOCAL_DEMO_V1';

  DateTime _dateOnly(DateTime d) {
    final u = d.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
  }

  // ---------------------------------------------------------------------
  // ختم التكامل: HMAC-SHA256 بمفتاح مشتق من التطبيق نفسه (مش من قاعدة
  // البيانات) - أي تعديل يدوي في القيم المخزّنة بيكسر التطابق فورًا.
  // rawCode هنا بقى base64 لبيانات binary مشفّرة، لكن المنطق نفسه زي
  // قبل كده تمامًا: أي حرف يتغيّر فيه بيكسر الختم.
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
  // تفعيل الجهاز الحالي بملف ترخيص (.lic) - الطريقة الأساسية دلوقتي.
  // ---------------------------------------------------------------------
  Future<String> activateFromBytes(List<int> licenseFileBytes) async {
    final decoded = await verifyLicenseBytes(licenseFileBytes);
    if (decoded == null) return 'license_error_invalid_code';

    return _activateWithDecoded(
      decoded: decoded,
      rawCodeText: base64Url.encode(licenseFileBytes),
    );
  }

  /// مسار احتياطي (متقدّم) لو حابب تلصق الكود كنص بدل ملف - النص هنا
  /// عبارة عن base64Url لنفس البيانات الـ binary المشفّرة (مش JSON واضح
  /// زي قبل كده)، فبرضه محدش يقدر يقرا محتواه.
  Future<String> activate(String pastedCode) async {
    List<int> bytes;
    try {
      bytes = base64Url.decode(pastedCode.trim());
    } catch (_) {
      return 'license_error_invalid_code';
    }
    return activateFromBytes(bytes);
  }

  // ---------------------------------------------------------------------
  // ديمو محلي بدون أي كود/ملف من الأدمن - المستخدم بيدوس زرار جوه
  // التطبيق نفسه ويشتغل على طول. شهر تقويمي كامل، ومحمي بختم HMAC زي
  // أي ترخيص تاني (تعديل remainingDays يدويًا في قاعدة البيانات بيكسر
  // الختم ويرفض الفتح فورًا)، لكن من غير توقيع Ed25519 لأنه مفيش أدمن
  // بيوقّع حاجة هنا أصلاً - ده بديل أخف حماية مقصود، مناسب لتجربة
  // مجانية قصيرة مش لترخيص مدفوع.
  // ---------------------------------------------------------------------
  Future<bool> isDemoAvailable() async {
    final used = await _getMeta('demo_used');
    return used != 'true';
  }

  Future<String> activateLocalDemo() async {
    final alreadyUsed = await _getMeta('demo_used');
    if (alreadyUsed == 'true') {
      return 'license_error_demo_already_used';
    }

    final fingerprint = await DeviceFingerprint.get();
    final today = _dateOnly(DateTime.now());
    final todayIso = today.toIso8601String();

    // شهر تقويمي كامل زي باقي الخطط في أداة الأدمن (مش 30 يوم ثابت).
    final endDate = DateTime.utc(today.year, today.month + 1, today.day);
    final totalDays = endDate.difference(today).inDays;

    final license = LicenseData(
      customerName: 'Trial',
      maxUsers: 1,
      maxDevices: 1,
      totalDays: totalDays,
      plan: 'demo',
    );

    final seal = _computeSeal(
      rawCode: _localDemoMarker,
      activationDate: todayIso,
      lastCheckDate: todayIso,
      remainingDays: totalDays,
      deviceFingerprint: fingerprint,
    );

    final db = await AppDatabase.instance.database;
    try {
      await db.insert(
        'license',
        {
          'id': 1,
          'licenseJson': jsonEncode(license.toJson()),
          'activatedAt': todayIso,
          'lastCheckDate': todayIso,
          'remainingDays': totalDays,
          'rawCode': _localDemoMarker,
          'integritySeal': seal,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.insert(
        'activated_devices',
        {
          'deviceFingerprint': fingerprint,
          'slotNumber': 0,
          'activatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _setMeta('demo_used', 'true');
    } catch (e) {
      return 'license_error_activation_failed';
    }

    return 'ok';
  }

  Future<String> _activateWithDecoded({
    required Map<String, dynamic> decoded,
    required String rawCodeText,
  }) async {
    final currentFingerprint = await DeviceFingerprint.get();
    final storedHash = decoded['deviceFingerprintHash'] as List<int>;
    if (!LicenseCrypto.fingerprintMatches(currentFingerprint, storedHash)) {
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
      rawCode: rawCodeText,
      activationDate: todayIso,
      lastCheckDate: todayIso,
      remainingDays: license.totalDays,
      deviceFingerprint: currentFingerprint,
    );

    try {
      await db.insert(
        'license',
        {
          'id': 1,
          'licenseJson': jsonEncode(license.toJson()),
          // ⚠️ لازم تكون نفس القيمة (todayIso) اللي اتحسب بيها الـ seal
          // فوق، مش DateTime.now().toIso8601String() لوحدها.
          'activatedAt': todayIso,
          'lastCheckDate': todayIso,
          'remainingDays': license.totalDays, // null = دائم
          'rawCode': rawCodeText,
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
    } catch (e) {
      return 'license_error_activation_failed';
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

    // صف قديم من قبل إضافة الختم/التشفير - محتاج إعادة تفعيل مرة واحدة
    // عشان ياخد الحماية الجديدة.
    if (rawCode == null || storedSeal == null) {
      return const LicenseCheckResult(false, 'license_error_not_activated');
    }

    // إعادة التحقق من توقيع/تشفير الكود الأصلي - مش هنثق في licenseJson
    // المخزّن. الاستثناء الوحيد: الديمو المحلي (مفيش توقيع أصلاً لأنه
    // اتفعّل من غير أدمن)، فبنعتمد بس على ختم الـ HMAC تحته.
    final isLocalDemo = rawCode == _localDemoMarker;
    int? totalDaysFromDecoded;

    if (!isLocalDemo) {
      Map<String, dynamic>? decoded;
      try {
        decoded = await verifyLicenseBytes(base64Url.decode(rawCode));
      } catch (_) {
        decoded = null;
      }
      if (decoded == null) {
        return const LicenseCheckResult(false, 'license_error_data_tampered');
      }
      totalDaysFromDecoded = decoded['totalDays'] as int?;
    }
    // الديمو المحلي مايكونش دائم أبدًا، فـ totalDaysFromDecoded بتفضل
    // null بس مش هتتفسّر كـ "ترخيص دائم" لأن isLocalDemo بيتفحص تحت.

    final lastCheckDateRaw = row['lastCheckDate'] as String;
    final remainingDaysRaw = row['remainingDays'] as int?;
    final activatedAtRaw = row['activatedAt'] as String;
    final expectedSeal = _computeSeal(
      rawCode: rawCode,
      activationDate: activatedAtRaw,
      lastCheckDate: lastCheckDateRaw,
      remainingDays: remainingDaysRaw,
      deviceFingerprint: fingerprint,
    );

    if (expectedSeal != storedSeal) {
      return const LicenseCheckResult(false, 'license_error_data_tampered');
    }

    if (!isLocalDemo && totalDaysFromDecoded == null) {
      return const LicenseCheckResult(true, 'ok'); // ترخيص دائم
    }

    final today = _dateOnly(DateTime.now());
    final lastCheckDate = _dateOnly(DateTime.parse(lastCheckDateRaw));
    // remainingDaysRaw لازم يكون موجود دايمًا هنا (بيتحط وقت التفعيل
    // في activateFromBytes/activateLocalDemo)، لكن fallback آمن لو حصل
    // أي ظرف غريب: للديمو المحلي مفيش totalDays مخزّن غير remainingDays
    // نفسه، وللتراخيص العادية بنرجع لـ totalDaysFromDecoded.
    int remainingDays = remainingDaysRaw ?? totalDaysFromDecoded ?? 0;

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
          'integritySeal': newSeal,
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

  /// تحقق من ملف/بيانات ترخيص binary (موقّعة ومشفّرة) وإرجاع بياناته لو
  /// سليمة، أو null لو تالفة/موقّعة بمفتاح غلط/متلاعب فيها.
  Future<Map<String, dynamic>?> verifyLicenseBytes(List<int> bytes) {
    return LicenseCrypto.verifyAndDecode(
      licenseFileBytes: bytes,
      publicKeyBase64Url: _publicKeyBase64,
    );
  }
}
