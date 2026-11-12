import 'dart:convert';
import 'dart:io';
import 'dart:math'; // ✅ تمت الإضافة للمفتاح العشوائي
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // ✅ تمت الإضافة
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../license/device_fingerprint.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase() => instance;

  // ✅ رفعنا الإصدار لـ 11 عشان الـ Migration يشتغل ويضيف عمود fixedInsurance
  static const int dbVersion = 11;

  static const int _maxBackups = 10;

  static const List<int> _dbKeySaltPart1 = [
    197,
    37,
    224,
    128,
    184,
    58,
    228,
    69,
    181,
    254,
    227,
    62,
    81,
    159,
    192,
    168,
    10,
    194,
    209,
    65,
    141,
    41,
    190,
    80,
    125,
    224,
    151,
    7,
    176,
    161,
    204,
    215,
  ];
  static const List<int> _dbKeySaltPart2 = [
    208,
    143,
    75,
    225,
    124,
    101,
    187,
    61,
    32,
    215,
    200,
    232,
    68,
    167,
    126,
    100,
    55,
    203,
    134,
    82,
    87,
    159,
    66,
    102,
    69,
    186,
    40,
    157,
    54,
    39,
    116,
    149,
  ];

  // ✅ 1. المفتاح القديم (نستخدمه فقط لترحيل قواعد البيانات القديمة)
  Future<String> _deriveLegacyDbKeyHex() async {
    final salt =
        List<int>.generate(32, (i) => _dbKeySaltPart1[i] ^ _dbKeySaltPart2[i]);
    final fingerprint = await DeviceFingerprint.get();
    final combined = utf8.encode(fingerprint) + salt;
    final hash = sha256.convert(combined);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ✅ 2. المفتاح الجديد (عشوائي ومحفوظ في الويندوز)
  static const _secureStorage = FlutterSecureStorage();
  static const String _dbKeyStorageKey = 'db_master_key_v2';

  Future<String> _getOrCreateSecureDbKeyHex() async {
    try {
      final existingKey = await _secureStorage.read(key: _dbKeyStorageKey);
      if (existingKey != null && existingKey.isNotEmpty) return existingKey;
    } catch (_) {}

    // توليد مفتاح عشوائي 32 بايت
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final newKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    try {
      await _secureStorage.write(key: _dbKeyStorageKey, value: newKey);
    } catch (_) {}
    return newKey;
  }

  Database? _db;
  String? _dbFilePath;
  String? _backupsDirPath;
  String? _exeBackupsDirPath;
  String? _offsiteBackupsDirPath;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return openDatabase('payrolls.db',
          version: dbVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }

    final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String dbPath;
    if (isDesktop) {
      final supportDir = await getApplicationSupportDirectory();
      dbPath = supportDir.path;
    } else {
      dbPath = await getDatabasesPath();
    }
    final path = join(dbPath, 'payrolls.db');
    _dbFilePath = path;

    if (isDesktop) {
      _backupsDirPath = join(dbPath, 'backups');
      final exeDir = dirname(Platform.resolvedExecutable);
      final exeBackupsDirPath = join(exeDir, 'backups');
      _exeBackupsDirPath = exeBackupsDirPath;

      await _createBackupIfNeeded(path, _backupsDirPath!);
      await _createBackupIfNeeded(path, exeBackupsDirPath);
    }

    final newDbKeyHex = isDesktop ? await _getOrCreateSecureDbKeyHex() : null;

    if (isDesktop && newDbKeyHex != null) {
      try {
        await _migrateToEncryptedIfNeeded(path, newDbKeyHex);
      } catch (_) {}
    }

    // ✅ 3. محاولة فتح الداتابيز بالمفتاح الجديد، ولو فشلت نجرب القديم ونعمل ترقية
    if (isDesktop && newDbKeyHex != null) {
      try {
        final db = await openDatabase(
          path,
          version: dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onConfigure: (db) async {
            await db.execute("PRAGMA key = \"x'$newDbKeyHex'\"");
            final result = await db.rawQuery('PRAGMA cipher_version');
            final cipherVersion =
                result.isNotEmpty ? result.first.values.first : null;
            if (cipherVersion == null || cipherVersion == '') {
              throw StateError('SQLCipher مش متحمّلة صح');
            }
          },
        );
        if (isDesktop) {
          await _performOffsiteBackupIfConfigured(db, path);
        }
        return db;
      } catch (e) {
        // فشل الفتح بالمفتاح الجديد.. غالباً داتابيز قديمة متشفرة بالبصمة
        try {
          final legacyKeyHex = await _deriveLegacyDbKeyHex();
          final legacyDb = await openDatabase(
            path,
            version: dbVersion,
            onConfigure: (db) async {
              await db.execute("PRAGMA key = \"x'$legacyKeyHex'\"");
            },
          );

          // نجح الفتح بالمفتاح القديم! هنغير المفتاح للجديد (Rekey)
          await legacyDb.execute("PRAGMA rekey = \"x'$newDbKeyHex'\"");
          await legacyDb.close();

          // نفتح تاني بالمفتاح الجديد
          final db = await openDatabase(
            path,
            version: dbVersion,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
            onConfigure: (db) async {
              await db.execute("PRAGMA key = \"x'$newDbKeyHex'\"");
              final result = await db.rawQuery('PRAGMA cipher_version');
              final cipherVersion =
                  result.isNotEmpty ? result.first.values.first : null;
              if (cipherVersion == null || cipherVersion == '') {
                throw StateError('SQLCipher مش متحمّلة صح');
              }
            },
          );
          if (isDesktop) {
            await _performOffsiteBackupIfConfigured(db, path);
          }
          return db;
        } catch (legacyError) {
          // لو القديم فشل كمان، يبقى دي داتابيز جديدة (هتتعمل من onCreate)
          rethrow;
        }
      }
    }

    // Fallback للويب أو الموبايل
    final db = await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    if (isDesktop) {
      await _performOffsiteBackupIfConfigured(db, path);
    }

    return db;
  }

  Future<void> _migrateToEncryptedIfNeeded(
    String dbFilePath,
    String dbKeyHex,
  ) async {
    final dbFile = File(dbFilePath);
    if (!await dbFile.exists()) return;

    Database? plainDb;
    bool isPlainText = false;
    try {
      plainDb = await openDatabase(dbFilePath, readOnly: true);
      await plainDb.rawQuery('SELECT count(*) FROM sqlite_master');
      isPlainText = true;
    } catch (_) {
      isPlainText = false;
    } finally {
      await plainDb?.close();
    }

    if (!isPlainText) return;

    final tempEncryptedPath = '$dbFilePath.encrypting_tmp';
    final tempFile = File(tempEncryptedPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    Database? sourceDb;
    try {
      sourceDb = await openDatabase(dbFilePath);

      await sourceDb.execute(
        "ATTACH DATABASE '$tempEncryptedPath' AS encrypted_target "
        "KEY \"x'$dbKeyHex'\"",
      );
      await sourceDb.rawQuery("SELECT sqlcipher_export('encrypted_target')");
      await sourceDb.execute('DETACH DATABASE encrypted_target');
      await sourceDb.close();
      sourceDb = null;

      final verify = await openDatabase(tempEncryptedPath,
          singleInstance: false, onConfigure: (d) async {
        await d.execute("PRAGMA key = \"x'$dbKeyHex'\"");
      });
      try {
        final n = await verify.rawQuery(
            "SELECT count(*) AS c FROM sqlite_master WHERE type='table'");
        if ((n.first['c'] as int) == 0) {
          throw StateError('encrypted copy is empty');
        }
      } finally {
        await verify.close();
      }

      final oldPlaintextBackup = File('$dbFilePath.pre_encryption_backup');
      if (await oldPlaintextBackup.exists()) {
        await oldPlaintextBackup.delete();
      }
      await dbFile.rename(oldPlaintextBackup.path);
      await tempFile.rename(dbFilePath);

      try {
        final len = await oldPlaintextBackup.length();
        final raf = await oldPlaintextBackup.open(mode: FileMode.write);
        const chunk = 64 * 1024;
        final zeros = List<int>.filled(chunk, 0);
        var written = 0;
        while (written < len) {
          final n = (len - written) < chunk ? (len - written) : chunk;
          await raf.writeFrom(zeros, 0, n);
          written += n;
        }
        await raf.flush();
        await raf.close();
        await oldPlaintextBackup.delete();
      } catch (_) {}
    } catch (e) {
      await sourceDb?.close();
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> createManualBackupNow() async {
    if (_dbFilePath == null) return;

    if (_backupsDirPath != null) {
      await _createBackupIfNeeded(_dbFilePath!, _backupsDirPath!);
    }
    if (_exeBackupsDirPath != null) {
      await _createBackupIfNeeded(_dbFilePath!, _exeBackupsDirPath!);
    }

    final offsitePath = await getOffsiteBackupPath();
    if (offsitePath != null) {
      final dir = Directory(offsitePath);
      if (await dir.exists()) {
        _offsiteBackupsDirPath = offsitePath;
        await _createBackupIfNeeded(_dbFilePath!, offsitePath);
      }
    }
  }

  static const String _offsitePathMetaKey = 'backup_offsite_path';

  Future<String?> getOffsiteBackupPath() async {
    final db = await database;
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [_offsitePathMetaKey],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String;
    return value.isEmpty ? null : value;
  }

  Future<void> setOffsiteBackupPath(String? folderPath) async {
    final db = await database;
    await db.insert(
      'app_meta',
      {'key': _offsitePathMetaKey, 'value': folderPath ?? ''},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _performOffsiteBackupIfConfigured(
    Database db,
    String dbFilePath,
  ) async {
    try {
      final rows = await db.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: [_offsitePathMetaKey],
      );
      if (rows.isEmpty) return;
      final offsitePath = rows.first['value'] as String;
      if (offsitePath.isEmpty) return;

      final offsiteDir = Directory(offsitePath);
      if (!await offsiteDir.exists()) return;

      _offsiteBackupsDirPath = offsitePath;
      await _createBackupIfNeeded(dbFilePath, offsitePath);
    } catch (_) {}
  }

  Future<void> _createBackupIfNeeded(
    String dbFilePath,
    String backupsDirPath,
  ) async {
    try {
      final dbFile = File(dbFilePath);
      if (!await dbFile.exists()) return;

      final backupsDir = Directory(backupsDirPath);
      if (!await backupsDir.exists()) {
        await backupsDir.create(recursive: true);
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final backupPath = join(backupsDirPath, 'payrolls_backup_$timestamp.db');
      await dbFile.copy(backupPath);

      await _pruneOldBackups(backupsDir);
    } catch (_) {}
  }

  Future<void> _pruneOldBackups(Directory backupsDir) async {
    final files = backupsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList();

    if (files.length <= _maxBackups) return;

    files
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    for (final oldFile in files.skip(_maxBackups)) {
      try {
        await oldFile.delete();
      } catch (_) {}
    }
  }

  Future<List<File>> listBackups() async {
    final files = <File>[];

    for (final dirPath in [
      _backupsDirPath,
      _exeBackupsDirPath,
      _offsiteBackupsDirPath,
    ]) {
      if (dirPath == null) continue;
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      files.addAll(
        dir.listSync().whereType<File>().where((f) => f.path.endsWith('.db')),
      );
    }

    files
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  Future<void> restoreBackup(File backupFile) async {
    if (_dbFilePath == null) {
      throw StateError('لازم تفتح قاعدة البيانات مرة الأول قبل الاسترجاع');
    }

    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    await backupFile.copy(_dbFilePath!);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE  IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        passwordHash TEXT NOT NULL,
        salt TEXT NOT NULL,
        roleId TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        mustChangePassword INTEGER NOT NULL DEFAULT 0,
        failedAttempts INTEGER NOT NULL DEFAULT 0,
        lockedUntil TEXT
      )
    ''');

    await _createAuditLog(db);

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        permissions TEXT NOT NULL,
        isSystemRole INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS activated_devices (
        deviceFingerprint TEXT PRIMARY KEY,
        slotNumber INTEGER NOT NULL,
        activatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS license (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        licenseJson TEXT NOT NULL,
        activatedAt TEXT NOT NULL,
        lastCheckDate TEXT NOT NULL,
        remainingDays INTEGER,
        rawCode TEXT,
        integritySeal TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // ✅ تمت إضافة fixedInsurance في الـ CREATE TABLE
    await db.execute('''
      CREATE TABLE  IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        nameAr TEXT NOT NULL,
        nameEn TEXT NOT NULL,
        department TEXT,
        jobTitle TEXT,
        nationalId TEXT,
        hireDate TEXT,
        resignationDate TEXT,   
        contractType TEXT,
        employeeType TEXT,
        insuranceCode TEXT,
        insuranceFile TEXT,
        taxFile TEXT,
        basicSalary REAL NOT NULL DEFAULT 0,
        variableSalary REAL NOT NULL DEFAULT 0,
        allowances REAL NOT NULL DEFAULT 0,
        expenses REAL NOT NULL DEFAULT 0,
        deductions REAL NOT NULL DEFAULT 0,
        fixedInsurance REAL NOT NULL DEFAULT 0,
        salaryType TEXT NOT NULL DEFAULT 'net',
        paymentMethod TEXT NOT NULL DEFAULT 'cash',
        isActive INTEGER NOT NULL DEFAULT 1,
        bankName TEXT DEFAULT '',
        bankAccount TEXT DEFAULT '',
        bankSwift TEXT DEFAULT '',
        bankIban TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS attendance (
        id TEXT PRIMARY KEY,
        employeeId TEXT,
        employeeName TEXT,
        date TEXT,
        overtimeHours REAL,
        lateMinutes REAL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS payroll_records (
        id TEXT PRIMARY KEY,
        employeeId TEXT NOT NULL,
        employeeNameAr TEXT NOT NULL,
        employeeNameEn TEXT NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        basicSalary REAL NOT NULL,
        variableSalary REAL NOT NULL DEFAULT 0,
        allowances REAL NOT NULL,
        deductions REAL NOT NULL,
        taxAmount REAL NOT NULL DEFAULT 0,
        insuranceAmount REAL NOT NULL DEFAULT 0,
        netSalary REAL NOT NULL,
        generatedAt TEXT NOT NULL,
        notes TEXT DEFAULT '',
        UNIQUE(employeeId, month, year)
      )
    ''');

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS salary_payments (
        id TEXT PRIMARY KEY,
        payrollRecordId TEXT NOT NULL,
        amount REAL NOT NULL,
        cashAmount REAL NOT NULL DEFAULT 0,
        bankAmount REAL NOT NULL DEFAULT 0,
        paymentDate TEXT NOT NULL,
        notes TEXT DEFAULT '',
        FOREIGN KEY (payrollRecordId) REFERENCES payroll_records(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE license ADD COLUMN lastCheckDate TEXT');
      await db.execute('ALTER TABLE license ADD COLUMN remainingDays INTEGER');
      await db.execute('''
        CREATE TABLE  IF NOT EXISTS app_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      for (final col in ['bankName', 'bankAccount', 'bankSwift', 'bankIban']) {
        try {
          await db.execute(
              'ALTER TABLE employees ADD COLUMN $col TEXT DEFAULT \'\'');
        } catch (_) {}
      }
      try {
        await db.execute('''
          CREATE TABLE  IF NOT EXISTS attendance (
            id TEXT PRIMARY KEY,
            employeeId TEXT,
            employeeNameAr TEXT,
            employeeNameEn TEXT,
            date TEXT,
            overtimeHours REAL,
            lateMinutes REAL,
            notes TEXT
          )
        ''');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE  IF NOT EXISTS payroll_records (
          id TEXT PRIMARY KEY,
          employeeId TEXT NOT NULL,
          employeeNameAr TEXT NOT NULL,
          employeeNameEn TEXT NOT NULL,
          month INTEGER NOT NULL,
          year INTEGER NOT NULL,
          basicSalary REAL NOT NULL,
          allowances REAL NOT NULL,
          deductions REAL NOT NULL,
          taxAmount REAL NOT NULL DEFAULT 0,
          insuranceAmount REAL NOT NULL DEFAULT 0,
          netSalary REAL NOT NULL,
          generatedAt TEXT NOT NULL,
          notes TEXT DEFAULT '',
          UNIQUE(employeeId, month, year)
        )
      ''');

      await db.execute('''
        CREATE TABLE  IF NOT EXISTS salary_payments (
          id TEXT PRIMARY KEY,
          payrollRecordId TEXT NOT NULL,
          amount REAL NOT NULL,
          cashAmount REAL NOT NULL DEFAULT 0,
          bankAmount REAL NOT NULL DEFAULT 0,
          paymentDate TEXT NOT NULL,
          notes TEXT DEFAULT '',
          FOREIGN KEY (payrollRecordId) REFERENCES payroll_records(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      try {
        await db
            .execute('ALTER TABLE employees ADD COLUMN resignationDate TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN nameEn TEXT DEFAULT \'\'');
        await db.execute('ALTER TABLE employees RENAME COLUMN name TO nameAr');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE license ADD COLUMN rawCode TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE license ADD COLUMN integritySeal TEXT');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN variableSalary REAL NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE payroll_records ADD COLUMN variableSalary REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN expenses REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 10) {
      for (final sql in [
        'ALTER TABLE users ADD COLUMN mustChangePassword INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE users ADD COLUMN failedAttempts INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE users ADD COLUMN lockedUntil TEXT',
      ]) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
      await _createAuditLog(db);
    }

    // ✅ الخطوة السحرية: إضافة العمود الجديد للداتابيزات القديمة
    if (oldVersion < 11) {
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN fixedInsurance REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
  }

  Future<void> _createAuditLog(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        at TEXT NOT NULL,
        username TEXT,
        action TEXT NOT NULL,
        details TEXT
      )
    ''');
  }
}
