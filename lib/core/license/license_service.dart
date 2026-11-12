/*  

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
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
    final value = rows.isEmpty ? null : rows.first['value'] as String;
    // علامة "الديمو اتستخدم" بتتحفظ كمان في ملف خارج قاعدة البيانات، عشان
    // مسح القاعدة أو تعديل جدول app_meta لوحده ميرجّعش الديمو من جديد.
    if (key == 'demo_used' && value != 'true' && await _demoMirrorExists()) {
      return 'true';
    }
    return value;
  }

  Future<void> _setMeta(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (key == 'demo_used' && value == 'true') await _writeDemoMirror();
  }

  // ---- نسخة مرآة لعلامة الديمو (ملف مختوم ومربوط ببصمة الجهاز) ----
  Future<File?> _demoMirrorFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}.lic_mirror');
    } catch (_) {
      return null;
    }
  }

  Future<String> _demoMirrorSeal() async {
    final fp = await DeviceFingerprint.get();
    return Hmac(sha256, _integrityKey)
        .convert(utf8.encode('demo_used|$fp'))
        .toString();
  }

  Future<bool> _demoMirrorExists() async {
    try {
      final f = await _demoMirrorFile();
      if (f == null || !await f.exists()) return false;
      return (await f.readAsString()).trim() == await _demoMirrorSeal();
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeDemoMirror() async {
    try {
      final f = await _demoMirrorFile();
      if (f == null) return;
      await f.writeAsString(await _demoMirrorSeal(), flush: true);
    } catch (_) {}
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
// lib/core/license/license_service.dart
//
// v2 rewrite:
// - مفتاح HMAC للتكامل عشوائي 32 بايت، مخزّن في flutter_secure_storage
//   (مش مشتق من الـ public key زي قبل كده).
// - الترخيص بيستخدم expiresAt مطلق من الـ payload الموقّع — مفيش
//   عدّاد remainingDays في منطق التحقق.
// - إعادة استيراد نفس الملف آمنة (expiresAt ثابت في التوقيع).

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'device_fingerprint.dart';
import 'license_crypto.dart';
import 'license_model.dart';

class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  // ⚠️ Public key من أداة الأدمن (Ed25519).
  // لو عملت key rotation لـ Ed25519، بدّلها هنا.
  static const String _publicKeyBase64 =
      '2YvaBI0PQnulucFLW_XitiK8ALBLBEghvmDPrXF9iXU=';

  static const String _localDemoMarker = 'LOCAL_DEMO_V1';
  static const int _localDemoDays = 30;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static const String _integrityKeyName = 'license_integrity_key_v2';

  Future<List<int>>? _integrityKeyFuture;

  // -------------------------------------------------------------------
  // Integrity key — عشوائي، مخزّن في secure storage
  // -------------------------------------------------------------------
  Future<List<int>> _integrityKey() {
    return _integrityKeyFuture ??= _loadOrCreateIntegrityKey();
  }

  Future<List<int>> _loadOrCreateIntegrityKey() async {
    try {
      final existing = await _storage.read(key: _integrityKeyName);
      if (existing != null) return base64Decode(existing);
    } catch (_) {
      // secure storage غير متاح → fallback لمفتاح مشتق (أقل أماناً،
      // لكن يسمح للتطبيق بالعمل في بيئات معزولة).
      return sha256
          .convert(utf8.encode('fallback-integrity|$_publicKeyBase64'))
          .bytes;
    }
    final rnd = Random.secure();
    final key = List<int>.generate(32, (_) => rnd.nextInt(256));
    try {
      await _storage.write(key: _integrityKeyName, value: base64Encode(key));
    } catch (_) {/* ignore */}
    return key;
  }

  Future<String> _computeSeal({
    required String rawCode,
    required String activationDate,
    required String lastCheckDate,
    required int? remainingDays,
    required String deviceFingerprint,
  }) async {
    final key = await _integrityKey();
    final payload =
        '$rawCode|$activationDate|$lastCheckDate|$remainingDays|$deviceFingerprint';
    return Hmac(sha256, key).convert(utf8.encode(payload)).toString();
  }

  // -------------------------------------------------------------------
  // Activation
  // -------------------------------------------------------------------
  Future<String> activateFromBytes(List<int> licenseFileBytes) async {
    final decoded = await verifyLicenseBytes(licenseFileBytes);
    if (decoded == null) return 'license_error_invalid_code';
    return _activateWithDecoded(
      decoded: decoded,
      rawCodeText: base64Url.encode(licenseFileBytes),
    );
  }

  Future<String> activate(String pastedCode) async {
    List<int> bytes;
    try {
      bytes = base64Url.decode(pastedCode.trim());
    } catch (_) {
      return 'license_error_invalid_code';
    }
    return activateFromBytes(bytes);
  }

  // -------------------------------------------------------------------
  // Local demo (من داخل التطبيق، بدون .lic من الأدمن)
  // -------------------------------------------------------------------
  Future<bool> isDemoAvailable() async {
    final used = await _getMeta('demo_used');
    return used != 'true';
  }

  Future<String> activateLocalDemo() async {
    if (await _getMeta('demo_used') == 'true') {
      return 'license_error_demo_already_used';
    }

    final fingerprint = await DeviceFingerprint.get();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: _localDemoDays));

    final license = LicenseData(
      customerName: 'Trial',
      maxUsers: 1,
      maxDevices: 1,
      plan: 'demo',
      issuedAt: now,
      expiresAt: expiresAt,
      totalDays: _localDemoDays,
    );

    final nowIso = now.toIso8601String();
    final seal = await _computeSeal(
      rawCode: _localDemoMarker,
      activationDate: nowIso,
      lastCheckDate: nowIso,
      remainingDays: _localDemoDays,
      deviceFingerprint: fingerprint,
    );

    final db = await AppDatabase.instance.database;
    try {
      await db.insert(
        'license',
        {
          'id': 1,
          'licenseJson': jsonEncode(license.toJson()),
          'activatedAt': nowIso,
          'lastCheckDate': nowIso,
          'remainingDays': _localDemoDays,
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
          'activatedAt': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _setMeta('demo_used', 'true');
    } catch (_) {
      return 'license_error_activation_failed';
    }
    return 'ok';
  }

  // -------------------------------------------------------------------
  // Activation flow
  // -------------------------------------------------------------------
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
    if (plan == 'demo' && await _getMeta('demo_used') == 'true') {
      return 'license_error_demo_already_used';
    }

    final issuedAt = decoded['issuedAt'] as DateTime?;
    final expiresAt = decoded['expiresAt'] as DateTime?;

    // رفض ترخيص منتهي من لحظة الاستيراد
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      return 'license_error_expired';
    }

    final license = LicenseData(
      customerName: decoded['customerName'],
      maxUsers: decoded['maxUsers'],
      maxDevices: decoded['maxDevices'],
      plan: plan,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      totalDays: (issuedAt != null && expiresAt != null)
          ? expiresAt.difference(issuedAt).inDays
          : null,
    );

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final remaining = expiresAt?.difference(now).inDays;

    final seal = await _computeSeal(
      rawCode: rawCodeText,
      activationDate: nowIso,
      lastCheckDate: nowIso,
      remainingDays: remaining,
      deviceFingerprint: currentFingerprint,
    );

    final db = await AppDatabase.instance.database;
    try {
      await db.insert(
        'license',
        {
          'id': 1,
          'licenseJson': jsonEncode(license.toJson()),
          'activatedAt': nowIso,
          'lastCheckDate': nowIso,
          'remainingDays': remaining,
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
          'activatedAt': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (plan == 'demo') await _setMeta('demo_used', 'true');
    } catch (_) {
      return 'license_error_activation_failed';
    }
    return 'ok';
  }

  // -------------------------------------------------------------------
  // Validate (daily check)
  // -------------------------------------------------------------------
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
    if (rawCode == null || storedSeal == null) {
      return const LicenseCheckResult(false, 'license_error_not_activated');
    }

    // 1) تحقق من سلامة الصف المخزّن
    final expectedSeal = await _computeSeal(
      rawCode: rawCode,
      activationDate: row['activatedAt'] as String,
      lastCheckDate: row['lastCheckDate'] as String,
      remainingDays: row['remainingDays'] as int?,
      deviceFingerprint: fingerprint,
    );
    if (expectedSeal != storedSeal) {
      return const LicenseCheckResult(false, 'license_error_data_tampered');
    }

    // 2) الديمو المحلي
    if (rawCode == _localDemoMarker) {
      final licenseData = LicenseData.fromJson(
        jsonDecode(row['licenseJson'] as String),
      );
      final expiresAt = licenseData.expiresAt;
      if (expiresAt == null) {
        return const LicenseCheckResult(false, 'license_error_data_tampered');
      }
      final now = DateTime.now();
      if (now.isAfter(expiresAt)) {
        return const LicenseCheckResult(false, 'license_error_expired');
      }
      final remaining = expiresAt.difference(now).inDays;
      await _updateLastCheck(
        db: db,
        rawCode: rawCode,
        row: row,
        fingerprint: fingerprint,
        remaining: remaining,
      );
      return LicenseCheckResult(true, 'ok', remainingDays: remaining);
    }

    // 3) الترخيص العادي: إعادة التحقق من التوقيع والتشفير
    Map<String, dynamic>? decoded;
    try {
      decoded = await verifyLicenseBytes(base64Url.decode(rawCode));
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      return const LicenseCheckResult(false, 'license_error_data_tampered');
    }

    // 4) فحص الانتهاء (expiresAt مطلق من التوقيع)
    final expiresAt = decoded['expiresAt'] as DateTime?;
    final now = DateTime.now();
    if (expiresAt != null && now.isAfter(expiresAt)) {
      return const LicenseCheckResult(false, 'license_error_expired');
    }

    // 5) تحديث lastCheckDate وremainingDays للعرض فقط
    final remaining = expiresAt?.difference(now).inDays;
    await _updateLastCheck(
      db: db,
      rawCode: rawCode,
      row: row,
      fingerprint: fingerprint,
      remaining: remaining,
    );

    return LicenseCheckResult(true, 'ok', remainingDays: remaining);
  }

  Future<void> _updateLastCheck({
    required Database db,
    required String rawCode,
    required Map<String, Object?> row,
    required String fingerprint,
    required int? remaining,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final newSeal = await _computeSeal(
      rawCode: rawCode,
      activationDate: row['activatedAt'] as String,
      lastCheckDate: nowIso,
      remainingDays: remaining,
      deviceFingerprint: fingerprint,
    );
    await db.update(
      'license',
      {
        'lastCheckDate': nowIso,
        'remainingDays': remaining,
        'integritySeal': newSeal,
      },
      where: 'id = 1',
    );
  }

  // -------------------------------------------------------------------
  // Public helpers
  // -------------------------------------------------------------------
  Future<LicenseData?> getActiveLicense() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('license', where: 'id = 1');
    if (rows.isEmpty) return null;
    return LicenseData.fromJson(
        jsonDecode(rows.first['licenseJson'] as String));
  }

  Future<int?> getRemainingDaysDisplay() async {
    final license = await getActiveLicense();
    return license?.computedRemainingDays;
  }

  Future<String> currentDeviceFingerprint() => DeviceFingerprint.get();

  Future<Map<String, dynamic>?> verifyLicenseBytes(List<int> bytes) {
    return LicenseCrypto.verifyAndDecode(
      licenseFileBytes: bytes,
      publicKeyBase64Url: _publicKeyBase64,
    );
  }

  // -------------------------------------------------------------------
  // Meta helpers (demo_used) + mirror
  // -------------------------------------------------------------------
  Future<String?> _getMeta(String key) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('app_meta', where: 'key = ?', whereArgs: [key]);
    final value = rows.isEmpty ? null : rows.first['value'] as String;
    if (key == 'demo_used' && value != 'true' && await _demoMirrorExists()) {
      return 'true';
    }
    return value;
  }

  Future<void> _setMeta(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (key == 'demo_used' && value == 'true') await _writeDemoMirror();
  }

  Future<File?> _demoMirrorFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}.lic_mirror');
    } catch (_) {
      return null;
    }
  }

  Future<String> _demoMirrorSeal() async {
    final fp = await DeviceFingerprint.get();
    final key = await _integrityKey();
    return Hmac(sha256, key).convert(utf8.encode('demo_used|$fp')).toString();
  }

  Future<bool> _demoMirrorExists() async {
    try {
      final f = await _demoMirrorFile();
      if (f == null || !await f.exists()) return false;
      return (await f.readAsString()).trim() == await _demoMirrorSeal();
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeDemoMirror() async {
    try {
      final f = await _demoMirrorFile();
      if (f == null) return;
      await f.writeAsString(await _demoMirrorSeal(), flush: true);
    } catch (_) {}
  }
}
