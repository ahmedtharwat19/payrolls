import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../license/license_service.dart';
import 'permission.dart';
import 'role.dart';
import 'user_model.dart';

/// مسؤول عن: تسجيل الدخول، إنشاء المستخدمين، حساب الصلاحيات الحالية.
///
/// ملحوظة: كل الدوال بترجع 'ok' أو مفتاح ترجمة (مش نص عربي مباشر) عشان
/// تتوافق مع easy_localization. استخدم النتيجة كده في الـ UI:
///   final result = await auth.login(user, pass);
///   if (result != 'ok') showError(result.tr());
class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  Role? _currentRole;

  AppUser? get currentUser => _currentUser;
  Role? get currentRole => _currentRole;
  bool get isLoggedIn => _currentUser != null;

  bool can(Permission p) => _currentRole?.can(p) ?? false;

  /// بيتنادى مرة واحدة أول ما البرنامج يفتح: بيزرع الأدوار الافتراضية
  /// وأول مستخدم Admin لو مفيش مستخدمين خالص.
  Future<void> bootstrap() async {
    final db = await AppDatabase.instance.database;

    final roleCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM roles'),
        ) ??
        0;

    if (roleCount == 0) {
      for (final role in Role.defaultRoles()) {
        await db.insert('roles', {
          'id': role.id,
          'name': role.name,
          'permissions': jsonEncode(role.permissions.map((p) => p.name).toList()),
          'isSystemRole': role.isSystemRole ? 1 : 0,
        });
      }
    }

    final userCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;

    if (userCount == 0) {
      // أول مستخدم افتراضي: admin / admin123 - لازم يتغيّر أول تسجيل دخول
      await createUser(username: 'admin', password: 'admin123', roleId: 'admin', skipLicenseCheck: true);
    }
  }

  /// بيرجع 'ok' أو مفتاح ترجمة زي 'auth_error_wrong_password'
  Future<String> login(String username, String password) async {
    final db = await AppDatabase.instance.database;

    // فحص الترخيص الأول: لو الترخيص منتهي أو الجهاز مش مفعّل، امنع الدخول
    final licenseCheck = await LicenseService.instance.validate();
    if (!licenseCheck.isValid) {
      return licenseCheck.messageKey;
    }

    final rows = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (rows.isEmpty) return 'auth_error_user_not_found';

    final user = AppUser.fromMap(rows.first);
    if (!user.isActive) return 'auth_error_user_disabled';

    final hash = _hashPassword(password, user.salt);
    if (hash != user.passwordHash) return 'auth_error_wrong_password';

    final roleRows = await db.query('roles', where: 'id = ?', whereArgs: [user.roleId]);
    if (roleRows.isEmpty) return 'auth_error_role_not_found';

    _currentUser = user;
    _currentRole = Role.fromJson({
      ...roleRows.first,
      'permissions': jsonDecode(roleRows.first['permissions'] as String),
    });

    notifyListeners();
    return 'ok';
  }

  void logout() {
    _currentUser = null;
    _currentRole = null;
    notifyListeners();
  }

  /// إنشاء مستخدم جديد - بيتفحص الحد الأقصى المسموح به في الترخيص أولاً.
  /// بيرجع 'ok' أو مفتاح ترجمة.
  Future<String> createUser({
    required String username,
    required String password,
    required String roleId,
    bool skipLicenseCheck = false, // مستخدمة داخليًا بس وقت أول تشغيل (bootstrap)
  }) async {
    final db = await AppDatabase.instance.database;

    if (!skipLicenseCheck) {
      final userCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM users'),
          ) ??
          0;

      final license = await LicenseService.instance.getActiveLicense();
      if (license != null && userCount >= license.maxUsers) {
        return 'auth_error_max_users';
      }
    }

    final exists = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (exists.isNotEmpty) return 'auth_error_username_taken';

    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);

    await db.insert('users', {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'username': username,
      'passwordHash': hash,
      'salt': salt,
      'roleId': roleId,
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });

    return 'ok';
  }

  String _generateSalt([int length = 16]) {
    final rand = Random.secure();
    return base64Url.encode(List<int>.generate(length, (_) => rand.nextInt(256)));
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }
}
