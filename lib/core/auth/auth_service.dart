import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../audit/audit_log.dart';
import '../database/app_database.dart';
import '../license/license_service.dart';
import '../security/password_hasher.dart';
import 'permission.dart';
import 'role.dart';
import 'user_model.dart';

/// مسؤول عن: تسجيل الدخول، إدارة المستخدمين وكلمات المرور، حساب الصلاحيات.
///
/// كل الدوال بترجع 'ok' أو مفتاح ترجمة (مش نص مباشر) عشان تتوافق مع
/// easy_localization:
///   final result = await auth.login(user, pass);
///   if (result != 'ok') showError(result.tr());
class AuthService extends ChangeNotifier {
  /// بعد كام محاولة فاشلة نقفل الحساب مؤقتًا.
  static const int maxFailedAttempts = 5;
  static const int _maxLockMinutes = 30;

  /// كلمة مرور الحساب الافتراضي الأول - بيتجبر المستخدم يغيّرها فورًا.
  static const String _bootstrapPassword = 'admin123';

  AppUser? _currentUser;
  Role? _currentRole;

  AppUser? get currentUser => _currentUser;
  Role? get currentRole => _currentRole;
  bool get isLoggedIn => _currentUser != null;
  bool get mustChangePassword => _currentUser?.mustChangePassword ?? false;

  bool can(Permission p) => _currentRole?.can(p) ?? false;

  // =====================================================================
  // Bootstrap
  // =====================================================================

  /// بيتنادى مرة واحدة أول ما البرنامج يفتح:
  /// - بيحدّث الأدوار النظامية (system roles) من الكود (عشان أي صلاحية
  ///   جديدة تتضاف للأدوار الموجودة في قواعد بيانات قديمة).
  /// - بيزرع أول مستخدم Admin لو مفيش مستخدمين، مع إجبار تغيير كلمة المرور.
  /// - بيجبر تغيير كلمة المرور لأي حساب لسه بكلمة المرور الافتراضية القديمة.
  Future<void> bootstrap() async {
    final db = await AppDatabase.instance.database;

    for (final role in Role.defaultRoles()) {
      await db.insert(
        'roles',
        {
          'id': role.id,
          'name': role.name,
          'permissions':
              jsonEncode(role.permissions.map((p) => p.name).toList()),
          'isSystemRole': role.isSystemRole ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final userCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;

    if (userCount == 0) {
      await _insertUser(
        username: 'admin',
        password: _bootstrapPassword,
        roleId: 'admin',
        mustChangePassword: true,
      );
      await AuditLog.record('bootstrap_admin_created', username: 'admin');
      return;
    }

    // ترقية حسابات موجودة لسه بالباسورد الافتراضي المعروف.
    final admins =
        await db.query('users', where: 'username = ?', whereArgs: ['admin']);
    for (final row in admins) {
      final u = AppUser.fromMap(row);
      if (!u.mustChangePassword &&
          await PasswordHasher.verify(
              _bootstrapPassword, u.salt, u.passwordHash)) {
        await db.update('users', {'mustChangePassword': 1},
            where: 'id = ?', whereArgs: [u.id]);
      }
    }
  }

  // =====================================================================
  // Login / logout
  // =====================================================================

  /// بيرجع 'ok' أو مفتاح ترجمة. رسالة موحّدة للمستخدم الغلط أو الباسورد
  /// الغلط عشان ما نكشفش وجود اسم المستخدم.
  Future<String> login(String username, String password) async {
    final db = await AppDatabase.instance.database;

    final licenseCheck = await LicenseService.instance.validate();
    if (!licenseCheck.isValid) {
      return licenseCheck.messageKey;
    }

    final rows = await db
        .query('users', where: 'username = ?', whereArgs: [username]);

    if (rows.isEmpty) {
      // نفس زمن التحقق تقريبًا عشان ما يتسرّبش وجود المستخدم من التوقيت.
      await PasswordHasher.hash(password, 'dummy-salt-for-timing');
      await AuditLog.record('login_failed_unknown_user');
      return 'auth_error_invalid_credentials';
    }

    final user = AppUser.fromMap(rows.first);

    if (user.isLocked) {
      await AuditLog.record('login_blocked_locked', username: username);
      return 'auth_error_locked';
    }

    final ok =
        await PasswordHasher.verify(password, user.salt, user.passwordHash);
    if (!ok) {
      await _registerFailure(db, user);
      return 'auth_error_invalid_credentials';
    }

    if (!user.isActive) {
      await AuditLog.record('login_blocked_disabled', username: username);
      return 'auth_error_user_disabled';
    }

    final roleRows =
        await db.query('roles', where: 'id = ?', whereArgs: [user.roleId]);
    if (roleRows.isEmpty) return 'auth_error_role_not_found';

    // نجاح: تصفير العدّاد + ترقية الهاش القديم لو لزم.
    final updates = <String, Object?>{
      'failedAttempts': 0,
      'lockedUntil': null,
    };
    if (PasswordHasher.needsUpgrade(user.passwordHash)) {
      final newSalt = PasswordHasher.generateSalt();
      updates['salt'] = newSalt;
      updates['passwordHash'] = await PasswordHasher.hash(password, newSalt);
    }
    await db.update('users', updates, where: 'id = ?', whereArgs: [user.id]);

    final fresh = await db.query('users', where: 'id = ?', whereArgs: [user.id]);
    _currentUser = AppUser.fromMap(fresh.first);
    _currentRole = Role.fromJson({
      ...roleRows.first,
      'permissions': jsonDecode(roleRows.first['permissions'] as String),
    });

    await AuditLog.record('login_ok', username: username);
    notifyListeners();
    return 'ok';
  }

  Future<void> _registerFailure(Database db, AppUser user) async {
    final attempts = user.failedAttempts + 1;
    DateTime? lockedUntil;
    if (attempts >= maxFailedAttempts) {
      final exp = attempts - maxFailedAttempts;
      final shift = exp < 0 ? 0 : (exp > 5 ? 5 : exp);
      final doubled = 1 << shift; // 1,2,4,8,16,32 دقيقة
      final minutes = doubled > _maxLockMinutes ? _maxLockMinutes : doubled;
      lockedUntil = DateTime.now().add(Duration(minutes: minutes));
    }
    await db.update(
      'users',
      {'failedAttempts': attempts, 'lockedUntil': lockedUntil?.toIso8601String()},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    await AuditLog.record(
      lockedUntil == null ? 'login_failed' : 'login_failed_account_locked',
      username: user.username,
    );
  }

  void logout() {
    final name = _currentUser?.username;
    _currentUser = null;
    _currentRole = null;
    if (name != null) {
      AuditLog.record('logout', username: name);
    }
    notifyListeners();
  }

  // =====================================================================
  // كلمات المرور
  // =====================================================================

  /// المستخدم الحالي يغيّر كلمة مروره بنفسه (لازم يدخل القديمة).
  Future<String> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _currentUser;
    if (user == null) return 'auth_error_forbidden';

    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [user.id]);
    if (rows.isEmpty) return 'auth_error_forbidden';
    final stored = AppUser.fromMap(rows.first);

    if (!await PasswordHasher.verify(
        currentPassword, stored.salt, stored.passwordHash)) {
      await AuditLog.record('password_change_failed', username: user.username);
      return 'auth_error_wrong_current_password';
    }
    final policy =
        PasswordHasher.validatePolicy(newPassword, username: user.username);
    if (policy != null) return policy;
    if (newPassword == currentPassword) return 'auth_error_same_password';

    await _setPassword(db, user.id, newPassword, mustChange: false);
    final fresh = await db.query('users', where: 'id = ?', whereArgs: [user.id]);
    _currentUser = AppUser.fromMap(fresh.first);
    await AuditLog.record('password_changed', username: user.username);
    notifyListeners();
    return 'ok';
  }

  /// مدير النظام يعمل reset لكلمة مرور مستخدم (بتتجبر تتغيّر عند أول دخول).
  Future<String> adminResetPassword({
    required String userId,
    required String newPassword,
  }) async {
    if (!can(Permission.manageUsers)) return 'auth_error_forbidden';
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return 'auth_error_user_not_found';
    final target = AppUser.fromMap(rows.first);

    final policy =
        PasswordHasher.validatePolicy(newPassword, username: target.username);
    if (policy != null) return policy;

    await _setPassword(db, userId, newPassword, mustChange: true);
    await db.update('users', {'failedAttempts': 0, 'lockedUntil': null},
        where: 'id = ?', whereArgs: [userId]);
    await AuditLog.record('password_reset_by_admin',
        username: _currentUser?.username, details: 'target=${target.username}');
    return 'ok';
  }

  Future<void> _setPassword(Database db, String userId, String password,
      {required bool mustChange}) async {
    final salt = PasswordHasher.generateSalt();
    final hash = await PasswordHasher.hash(password, salt);
    await db.update(
      'users',
      {
        'salt': salt,
        'passwordHash': hash,
        'mustChangePassword': mustChange ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // =====================================================================
  // إدارة المستخدمين (كلها بتتطلب manageUsers)
  // =====================================================================

  Future<List<AppUser>> listUsers() async {
    if (!can(Permission.manageUsers)) return const [];
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', orderBy: 'username ASC');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<List<Role>> listRoles() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('roles', orderBy: 'name ASC');
    return rows
        .map((r) => Role.fromJson({
              ...r,
              'permissions': jsonDecode(r['permissions'] as String),
            }))
        .toList();
  }

  /// إنشاء مستخدم جديد - بيتفحص الحد الأقصى المسموح به في الترخيص أولاً.
  /// الدالة العامة دايمًا بتتطلب صلاحية manageUsers لمستخدم مسجّل دخول.
  Future<String> createUser({
    required String username,
    required String password,
    required String roleId,
  }) async {
    if (!can(Permission.manageUsers)) return 'auth_error_forbidden';
    final db = await AppDatabase.instance.database;

    final cleanName = username.trim();
    if (cleanName.length < 3) return 'auth_error_invalid_username';

    final policy = PasswordHasher.validatePolicy(password, username: cleanName);
    if (policy != null) return policy;

    final userCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;
    final license = await LicenseService.instance.getActiveLicense();
    if (license != null && userCount >= license.maxUsers) {
      return 'auth_error_max_users';
    }

    final exists =
        await db.query('users', where: 'username = ?', whereArgs: [cleanName]);
    if (exists.isNotEmpty) return 'auth_error_username_taken';

    final roleExists =
        await db.query('roles', where: 'id = ?', whereArgs: [roleId]);
    if (roleExists.isEmpty) return 'auth_error_role_not_found';

    await _insertUser(
      username: cleanName,
      password: password,
      roleId: roleId,
      mustChangePassword: true,
    );
    await AuditLog.record('user_created',
        username: _currentUser?.username, details: 'target=$cleanName role=$roleId');
    return 'ok';
  }

  Future<String> setUserActive(String userId, bool active) async {
    if (!can(Permission.manageUsers)) return 'auth_error_forbidden';
    if (userId == _currentUser?.id && !active) {
      return 'auth_error_cannot_disable_self';
    }
    final db = await AppDatabase.instance.database;
    if (!active && await _isLastActiveAdmin(db, userId)) {
      return 'auth_error_last_admin';
    }
    await db.update('users', {'isActive': active ? 1 : 0},
        where: 'id = ?', whereArgs: [userId]);
    await AuditLog.record(active ? 'user_enabled' : 'user_disabled',
        username: _currentUser?.username, details: 'target_id=$userId');
    return 'ok';
  }

  Future<String> deleteUser(String userId) async {
    if (!can(Permission.manageUsers)) return 'auth_error_forbidden';
    if (userId == _currentUser?.id) return 'auth_error_cannot_disable_self';
    final db = await AppDatabase.instance.database;
    if (await _isLastActiveAdmin(db, userId)) return 'auth_error_last_admin';
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
    await AuditLog.record('user_deleted',
        username: _currentUser?.username, details: 'target_id=$userId');
    return 'ok';
  }

  Future<String> setUserRole(String userId, String roleId) async {
    if (!can(Permission.manageUsers)) return 'auth_error_forbidden';
    final db = await AppDatabase.instance.database;
    if (roleId != 'admin' && await _isLastActiveAdmin(db, userId)) {
      return 'auth_error_last_admin';
    }
    await db.update('users', {'roleId': roleId},
        where: 'id = ?', whereArgs: [userId]);
    await AuditLog.record('user_role_changed',
        username: _currentUser?.username,
        details: 'target_id=$userId role=$roleId');
    return 'ok';
  }

  /// هل المستخدم ده هو آخر Admin نشط؟ (لمنع قفل النظام على نفسه).
  Future<bool> _isLastActiveAdmin(Database db, String userId) async {
    final target = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (target.isEmpty) return false;
    if (target.first['roleId'] != 'admin' || target.first['isActive'] != 1) {
      return false;
    }
    final others = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM users WHERE roleId = 'admin' AND isActive = 1 AND id != ?",
          [userId],
        )) ??
        0;
    return others == 0;
  }

  Future<void> _insertUser({
    required String username,
    required String password,
    required String roleId,
    required bool mustChangePassword,
  }) async {
    final db = await AppDatabase.instance.database;
    final salt = PasswordHasher.generateSalt();
    final hash = await PasswordHasher.hash(password, salt);
    await db.insert('users', {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'username': username,
      'passwordHash': hash,
      'salt': salt,
      'roleId': roleId,
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'mustChangePassword': mustChangePassword ? 1 : 0,
      'failedAttempts': 0,
    });
  }
}
