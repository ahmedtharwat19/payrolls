/* import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// ⚠️ ده المصدر الوحيد لقاعدة البيانات في المشروع كله.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase() => instance;

  // ✅ رفع الإصدار إلى 6 (كان واقف عند 4، فمigration الإصدار 5 بتاعك
  // (nameEn/nameAr) كان معمول لكنه معمول له trigger أصلاً لأن target
  // version كان أقل منه - ترقيته لـ 6 هنا خلته يشتغل كمان بالمرة)
  static const int dbVersion = 9;

  Database? _db;

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

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'payrolls.db');

    return openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        createdAt TEXT NOT NULL
      )
    ''');

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

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        nameAr TEXT NOT NULL,
        nameEn TEXT NOT NULL,
        department TEXT,
        jobTitle TEXT,
        nationalId TEXT,
        hireDate TEXT,
        resignationDate TEXT,   -- ✅ العمود الجديد
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
// وفي _onUpgrade:
    if (oldVersion < 4) {
      // إضافة resignationDate
      try {
        await db
            .execute('ALTER TABLE employees ADD COLUMN resignationDate TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // إضافة nameEn
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN nameEn TEXT DEFAULT \'\'');
        // قد نريد أيضاً تغيير name إلى nameAr
        await db.execute('ALTER TABLE employees RENAME COLUMN name TO nameAr');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      // ختم التكامل (Integrity Seal) - بيمنع تعديل الترخيص مباشرة من
      // قاعدة البيانات (SQLite Browser وغيره) من غير ما يتكشف فورًا
      //
      // ⚠️ الشرط كان oldVersion < 6 مع dbVersion = 6 في نفس الوقت - يعني
      // أي جهاز كان مثبّت عليه إصدار سابق شغال بالفعل بـ dbVersion = 6
      // (قبل إضافة العمودين دول) كان بيفضل عمره ما يشغّل الـ migration ده
      // لأن sqflite بينادي onUpgrade بس لو oldVersion != newVersion.
      // رفعنا dbVersion لـ 7 وغيّرنا الشرط عشان الجهاز ده ياخد الترقية.
      try {
        await db.execute('ALTER TABLE license ADD COLUMN rawCode TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE license ADD COLUMN integritySeal TEXT');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      // إضافة الراتب المتغيّر كجزء منفصل عن الأساسي والبدلات - عشان
      // مطابقة هيكل الراتب الحقيقي (أساسي + متغيّر + بدلات)
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
      // المصروفات - حقل خصم إضافي موجود في ملفات المرتبات الحقيقية
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN expenses REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
  }
}
 */
/* import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// ⚠️ ده المصدر الوحيد لقاعدة البيانات في المشروع كله.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase() => instance;

  // ✅ رفع الإصدار إلى 6 (كان واقف عند 4، فمigration الإصدار 5 بتاعك
  // (nameEn/nameAr) كان معمول لكنه معمول له trigger أصلاً لأن target
  // version كان أقل منه - ترقيته لـ 6 هنا خلته يشتغل كمان بالمرة)
  static const int dbVersion = 9;

  // عدد النسخ الاحتياطية اللي بنحتفظ بيها - الأقدم من كده بيتمسح تلقائيًا
  // عشان القرص مايمتلاش. كل نسخة كاملة لملف .db فبيانات المرتبات
  // (مش ضخمة عادةً) فـ 10 نسخ مساحة صغيرة جدًا مقابل حماية حقيقية.
  static const int _maxBackups = 10;

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

    // ⚠️ getDatabasesPath() بتاعة sqflite_common_ffi موصوف رسميًا في
    // التوثيق إنها "lame implementation" على الديسكتوب - غالبًا بترجع
    // مسار نسبي لمجلد التشغيل الحالي (working directory)، اللي ممكن
    // يتغيّر أو يتمسح مع أي flutter clean أو نقل للـ exe. عشان كده
    // بنستخدم path_provider بدلها للحصول على مسار قياسي وثابت:
    //   Windows: C:\Users\<user>\AppData\Roaming\<app_name>\
    //   macOS:   ~/Library/Application Support/<app_name>/
    //   Linux:   ~/.local/share/<app_name>/
    // ده بيحمي بيانات الموظفين والمرتبات من الضياع لو حد نضّف مجلد
    // الـ build أو نقل الـ exe بمفرده من غير الملفات المصاحبة له.
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

      // مجلد تاني إضافي جنب ملف الـ exe نفسه - أسهل توصله يدويًا (تاخده
      // بفلاشة أو تبعته بسهولة) عن مجلد AppData المخفي. ⚠️ ده مش بديل
      // عن نسخة AppData: مجلد الـ exe بيتمسح لو حد عمل Uninstall أو
      // إعادة تثبيت، فهو مصدر إضافي مش المصدر الأساسي.
      final exeDir = dirname(Platform.resolvedExecutable);
      final exeBackupsDirPath = join(exeDir, 'backups');
      _exeBackupsDirPath = exeBackupsDirPath;

      // ⚠️ بنعمل الباكأب قبل ما نفتح القاعدة أو نبدأ أي migration - لو
      // الترقية نفسها فشلت أو خرّبت البيانات لأي سبب، عندك نسخة سليمة
      // قبلها على طول. فشل أي مسار بيتم تجاهله لوحده (مثلاً لو مجلد
      // الـ exe تحت Program Files ومحتاج صلاحيات أدمن للكتابة فيه) وده
      // ميوقفش تشغيل التطبيق ولا يمنع المسار التاني من النجاح.
      await _createBackupIfNeeded(path, _backupsDirPath!);
      await _createBackupIfNeeded(path, exeBackupsDirPath);
    }

    final db = await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // ⚠️ الباكأب الخارجي (off-site) بيتنفّذ بعد فتح القاعدة، لأن مساره
    // متخزّن جوه app_meta نفسها. ده كمان بيديك ميزة إضافية: النسخة اللي
    // بتتاخد هنا فيها آخر تحديث للـ schema بعد أي migration، مش النسخة
    // القديمة قبله.
    if (isDesktop) {
      await _performOffsiteBackupIfConfigured(db, path);
    }

    return db;
  }

  // ---------------------------------------------------------------------
  // باكأب خارجي (Off-site) - مجلد المستخدم بيختاره بنفسه، الأفضل يكون
  // مجلد بيتزامن تلقائيًا مع الإنترنت (OneDrive/Google Drive) عشان
  // النسخة تفضل موجودة حتى لو الجهاز نفسه ضاع أو اتعطّل بالكامل. ده
  // الفرق الجوهري عن النسختين التانيين (AppData وجنب الـ exe) اللي
  // الاتنين على نفس القرص الفعلي وبيضيعوا مع بعض في نفس الكارثة.
  //
  // المسار متخزّن جوه app_meta نفسها (key = 'backup_offsite_path')،
  // فمحتاج القاعدة تكون متفتحة الأول عشان نقراه - عشان كده بيتنفّذ
  // بعد openDatabase مش قبلها زي المسارين التانيين.
  // ---------------------------------------------------------------------
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

  /// حفظ مسار مجلد الباكأب الخارجي (مثلاً مجلد جوه OneDrive بتاع
  /// المستخدم). ابعتله string فاضي أو null عشان توقف الباكأب الخارجي.
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

      // لو المجلد مش موجود دلوقتي (فلاشة مش متوصلة، OneDrive لسه
      // بيتزامن، إلخ) بنتجاهل بهدوء - مش مشكلة، هيحصل في التشغيل الجاي.
      final offsiteDir = Directory(offsitePath);
      if (!await offsiteDir.exists()) return;

      _offsiteBackupsDirPath = offsitePath;
      await _createBackupIfNeeded(dbFilePath, offsitePath);
    } catch (_) {
      // فشل الباكأب الخارجي مايوقفش التطبيق برضه - زي المسارين التانيين.
    }
  }

  // ---------------------------------------------------------------------
  // الدالة المشتركة اللي بتعمل الباكأب فعليًا - مستخدمة لكل الأماكن
  // الثلاثة (AppData، جنب الـ exe، الخارجي) بنفس المنطق: نسخة بتاريخ
  // ووقت، مع الاحتفاظ بآخر _maxBackups نسخة بس لكل مجلد.
  // ---------------------------------------------------------------------
  Future<void> _createBackupIfNeeded(
    String dbFilePath,
    String backupsDirPath,
  ) async {
    try {
      final dbFile = File(dbFilePath);
      // أول تشغيل للتطبيق - مفيش قاعدة بيانات لسه أصلاً، مفيش حاجة
      // نعمللها باكأب.
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
    } catch (_) {
      // فشل الباكأب مايمنعش التطبيق من الشغل - بس هيبقى مفيش نسخة
      // لهذا التشغيل بالتحديد في المجلد ده. لو حابب تتبّع الفشل ده،
      // ضيف logging هنا (مثلاً بتاع Sentry أو ملف log محلي).
    }
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

  /// قائمة بكل النسخ الاحتياطية الموجودة حاليًا من الأماكن الثلاثة
  /// (AppData + جنب الـ exe + الخارجي لو متفعّل)، الأحدث أولاً - مفيدة
  /// لو حابب تبني شاشة "استعادة نسخة احتياطية" في التطبيق.
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

  /// استرجاع نسخة احتياطية معيّنة - بيقفل الاتصال الحالي بقاعدة البيانات
  /// أولاً، يستبدل الملف الحالي بالنسخة المختارة، وبعدين يفتح الاتصال
  /// تاني. ⚠️ لازم تعمل restart للتطبيق بعد الاستدعاء ده عشان أي شاشة
  /// فاتحة بيانات قديمة في الذاكرة تتحدّث.
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
        createdAt TEXT NOT NULL
      )
    ''');

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

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        nameAr TEXT NOT NULL,
        nameEn TEXT NOT NULL,
        department TEXT,
        jobTitle TEXT,
        nationalId TEXT,
        hireDate TEXT,
        resignationDate TEXT,   -- ✅ العمود الجديد
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
// وفي _onUpgrade:
    if (oldVersion < 4) {
      // إضافة resignationDate
      try {
        await db
            .execute('ALTER TABLE employees ADD COLUMN resignationDate TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // إضافة nameEn
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN nameEn TEXT DEFAULT \'\'');
        // قد نريد أيضاً تغيير name إلى nameAr
        await db.execute('ALTER TABLE employees RENAME COLUMN name TO nameAr');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      // ختم التكامل (Integrity Seal) - بيمنع تعديل الترخيص مباشرة من
      // قاعدة البيانات (SQLite Browser وغيره) من غير ما يتكشف فورًا
      //
      // ⚠️ الشرط كان oldVersion < 6 مع dbVersion = 6 في نفس الوقت - يعني
      // أي جهاز كان مثبّت عليه إصدار سابق شغال بالفعل بـ dbVersion = 6
      // (قبل إضافة العمودين دول) كان بيفضل عمره ما يشغّل الـ migration ده
      // لأن sqflite بينادي onUpgrade بس لو oldVersion != newVersion.
      // رفعنا dbVersion لـ 7 وغيّرنا الشرط عشان الجهاز ده ياخد الترقية.
      try {
        await db.execute('ALTER TABLE license ADD COLUMN rawCode TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE license ADD COLUMN integritySeal TEXT');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      // إضافة الراتب المتغيّر كجزء منفصل عن الأساسي والبدلات - عشان
      // مطابقة هيكل الراتب الحقيقي (أساسي + متغيّر + بدلات)
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
      // المصروفات - حقل خصم إضافي موجود في ملفات المرتبات الحقيقية
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN expenses REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
  }
}
 */

/*  import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// ⚠️ ده المصدر الوحيد لقاعدة البيانات في المشروع كله.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase() => instance;

  // ✅ رفع الإصدار إلى 6 (كان واقف عند 4، فمigration الإصدار 5 بتاعك
  // (nameEn/nameAr) كان معمول لكنه معمول له trigger أصلاً لأن target
  // version كان أقل منه - ترقيته لـ 6 هنا خلته يشتغل كمان بالمرة)
  static const int dbVersion = 9;

  // عدد النسخ الاحتياطية اللي بنحتفظ بيها - الأقدم من كده بيتمسح تلقائيًا
  // عشان القرص مايمتلاش. كل نسخة كاملة لملف .db فبيانات المرتبات
  // (مش ضخمة عادةً) فـ 10 نسخ مساحة صغيرة جدًا مقابل حماية حقيقية.
  static const int _maxBackups = 10;

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

    // ⚠️ getDatabasesPath() بتاعة sqflite_common_ffi موصوف رسميًا في
    // التوثيق إنها "lame implementation" على الديسكتوب - غالبًا بترجع
    // مسار نسبي لمجلد التشغيل الحالي (working directory)، اللي ممكن
    // يتغيّر أو يتمسح مع أي flutter clean أو نقل للـ exe. عشان كده
    // بنستخدم path_provider بدلها للحصول على مسار قياسي وثابت:
    //   Windows: C:\Users\<user>\AppData\Roaming\<app_name>\
    //   macOS:   ~/Library/Application Support/<app_name>/
    //   Linux:   ~/.local/share/<app_name>/
    // ده بيحمي بيانات الموظفين والمرتبات من الضياع لو حد نضّف مجلد
    // الـ build أو نقل الـ exe بمفرده من غير الملفات المصاحبة له.
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

      // مجلد تاني إضافي جنب ملف الـ exe نفسه - أسهل توصله يدويًا (تاخده
      // بفلاشة أو تبعته بسهولة) عن مجلد AppData المخفي. ⚠️ ده مش بديل
      // عن نسخة AppData: مجلد الـ exe بيتمسح لو حد عمل Uninstall أو
      // إعادة تثبيت، فهو مصدر إضافي مش المصدر الأساسي.
      final exeDir = dirname(Platform.resolvedExecutable);
      final exeBackupsDirPath = join(exeDir, 'backups');
      _exeBackupsDirPath = exeBackupsDirPath;

      // ⚠️ بنعمل الباكأب قبل ما نفتح القاعدة أو نبدأ أي migration - لو
      // الترقية نفسها فشلت أو خرّبت البيانات لأي سبب، عندك نسخة سليمة
      // قبلها على طول. فشل أي مسار بيتم تجاهله لوحده (مثلاً لو مجلد
      // الـ exe تحت Program Files ومحتاج صلاحيات أدمن للكتابة فيه) وده
      // ميوقفش تشغيل التطبيق ولا يمنع المسار التاني من النجاح.
      await _createBackupIfNeeded(path, _backupsDirPath!);
      await _createBackupIfNeeded(path, exeBackupsDirPath);
    }

    final db = await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // ⚠️ الباكأب الخارجي (off-site) بيتنفّذ بعد فتح القاعدة، لأن مساره
    // متخزّن جوه app_meta نفسها. ده كمان بيديك ميزة إضافية: النسخة اللي
    // بتتاخد هنا فيها آخر تحديث للـ schema بعد أي migration، مش النسخة
    // القديمة قبله.
    if (isDesktop) {
      await _performOffsiteBackupIfConfigured(db, path);
    }

    return db;
  }

  /// باكأب يدوي فوري لكل المسارات الثلاثة المتاحة دلوقتي - بيتنادى من
  /// شاشة إعدادات النسخ الاحتياطي، من غير ما يحتاج المستخدم يقفل
  /// ويفتح التطبيق تاني. مفيد خصوصًا لما المستخدم يظبط مجلد الباكأب
  /// الخارجي لأول مرة ومحتاج يتأكد إنه شغال على طول.
  Future<void> createManualBackupNow() async {
    if (_dbFilePath == null) return; // القاعدة لسه مفتحتش

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

  // ---------------------------------------------------------------------
  // باكأب خارجي (Off-site) - مجلد المستخدم بيختاره بنفسه، الأفضل يكون
  // مجلد بيتزامن تلقائيًا مع الإنترنت (OneDrive/Google Drive) عشان
  // النسخة تفضل موجودة حتى لو الجهاز نفسه ضاع أو اتعطّل بالكامل. ده
  // الفرق الجوهري عن النسختين التانيين (AppData وجنب الـ exe) اللي
  // الاتنين على نفس القرص الفعلي وبيضيعوا مع بعض في نفس الكارثة.
  //
  // المسار متخزّن جوه app_meta نفسها (key = 'backup_offsite_path')،
  // فمحتاج القاعدة تكون متفتحة الأول عشان نقراه - عشان كده بيتنفّذ
  // بعد openDatabase مش قبلها زي المسارين التانيين.
  // ---------------------------------------------------------------------
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

  /// حفظ مسار مجلد الباكأب الخارجي (مثلاً مجلد جوه OneDrive بتاع
  /// المستخدم). ابعتله string فاضي أو null عشان توقف الباكأب الخارجي.
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

      // لو المجلد مش موجود دلوقتي (فلاشة مش متوصلة، OneDrive لسه
      // بيتزامن، إلخ) بنتجاهل بهدوء - مش مشكلة، هيحصل في التشغيل الجاي.
      final offsiteDir = Directory(offsitePath);
      if (!await offsiteDir.exists()) return;

      _offsiteBackupsDirPath = offsitePath;
      await _createBackupIfNeeded(dbFilePath, offsitePath);
    } catch (_) {
      // فشل الباكأب الخارجي مايوقفش التطبيق برضه - زي المسارين التانيين.
    }
  }


  // ---------------------------------------------------------------------
  // الدالة المشتركة اللي بتعمل الباكأب فعليًا - مستخدمة لكل الأماكن
  // الثلاثة (AppData، جنب الـ exe، الخارجي) بنفس المنطق: نسخة بتاريخ
  // ووقت، مع الاحتفاظ بآخر _maxBackups نسخة بس لكل مجلد.
  // ---------------------------------------------------------------------
  Future<void> _createBackupIfNeeded(
    String dbFilePath,
    String backupsDirPath,
  ) async {
    try {
      final dbFile = File(dbFilePath);
      // أول تشغيل للتطبيق - مفيش قاعدة بيانات لسه أصلاً، مفيش حاجة
      // نعمللها باكأب.
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
    } catch (_) {
      // فشل الباكأب مايمنعش التطبيق من الشغل - بس هيبقى مفيش نسخة
      // لهذا التشغيل بالتحديد في المجلد ده. لو حابب تتبّع الفشل ده،
      // ضيف logging هنا (مثلاً بتاع Sentry أو ملف log محلي).
    }
  }

  Future<void> _pruneOldBackups(Directory backupsDir) async {
    final files = backupsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList();

    if (files.length <= _maxBackups) return;

    files.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));

    for (final oldFile in files.skip(_maxBackups)) {
      try {
        await oldFile.delete();
      } catch (_) {}
    }
  }

  /// قائمة بكل النسخ الاحتياطية الموجودة حاليًا من الأماكن الثلاثة
  /// (AppData + جنب الـ exe + الخارجي لو متفعّل)، الأحدث أولاً - مفيدة
  /// لو حابب تبني شاشة "استعادة نسخة احتياطية" في التطبيق.
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
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.db')),
      );
    }

    files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// استرجاع نسخة احتياطية معيّنة - بيقفل الاتصال الحالي بقاعدة البيانات
  /// أولاً، يستبدل الملف الحالي بالنسخة المختارة، وبعدين يفتح الاتصال
  /// تاني. ⚠️ لازم تعمل restart للتطبيق بعد الاستدعاء ده عشان أي شاشة
  /// فاتحة بيانات قديمة في الذاكرة تتحدّث.
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
        createdAt TEXT NOT NULL
      )
    ''');

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

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        nameAr TEXT NOT NULL,
        nameEn TEXT NOT NULL,
        department TEXT,
        jobTitle TEXT,
        nationalId TEXT,
        hireDate TEXT,
        resignationDate TEXT,   -- ✅ العمود الجديد
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
// وفي _onUpgrade:
    if (oldVersion < 4) {
      // إضافة resignationDate
      try {
        await db
            .execute('ALTER TABLE employees ADD COLUMN resignationDate TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // إضافة nameEn
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN nameEn TEXT DEFAULT \'\'');
        // قد نريد أيضاً تغيير name إلى nameAr
        await db.execute('ALTER TABLE employees RENAME COLUMN name TO nameAr');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      // ختم التكامل (Integrity Seal) - بيمنع تعديل الترخيص مباشرة من
      // قاعدة البيانات (SQLite Browser وغيره) من غير ما يتكشف فورًا
      //
      // ⚠️ الشرط كان oldVersion < 6 مع dbVersion = 6 في نفس الوقت - يعني
      // أي جهاز كان مثبّت عليه إصدار سابق شغال بالفعل بـ dbVersion = 6
      // (قبل إضافة العمودين دول) كان بيفضل عمره ما يشغّل الـ migration ده
      // لأن sqflite بينادي onUpgrade بس لو oldVersion != newVersion.
      // رفعنا dbVersion لـ 7 وغيّرنا الشرط عشان الجهاز ده ياخد الترقية.
      try {
        await db.execute('ALTER TABLE license ADD COLUMN rawCode TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE license ADD COLUMN integritySeal TEXT');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      // إضافة الراتب المتغيّر كجزء منفصل عن الأساسي والبدلات - عشان
      // مطابقة هيكل الراتب الحقيقي (أساسي + متغيّر + بدلات)
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
      // المصروفات - حقل خصم إضافي موجود في ملفات المرتبات الحقيقية
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN expenses REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
  }
} */

/* import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// ⚠️ ده المصدر الوحيد لقاعدة البيانات في المشروع كله.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase() => instance;

  // ✅ رفع الإصدار إلى 6 (كان واقف عند 4، فمigration الإصدار 5 بتاعك
  // (nameEn/nameAr) كان معمول لكنه معمول له trigger أصلاً لأن target
  // version كان أقل منه - ترقيته لـ 6 هنا خلته يشتغل كمان بالمرة)
  static const int dbVersion = 9;

  // عدد النسخ الاحتياطية اللي بنحتفظ بيها - الأقدم من كده بيتمسح تلقائيًا
  // عشان القرص مايمتلاش. كل نسخة كاملة لملف .db فبيانات المرتبات
  // (مش ضخمة عادةً) فـ 10 نسخ مساحة صغيرة جدًا مقابل حماية حقيقية.
  static const int _maxBackups = 10;

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

    // ⚠️ getDatabasesPath() بتاعة sqflite_common_ffi موصوف رسميًا في
    // التوثيق إنها "lame implementation" على الديسكتوب - غالبًا بترجع
    // مسار نسبي لمجلد التشغيل الحالي (working directory)، اللي ممكن
    // يتغيّر أو يتمسح مع أي flutter clean أو نقل للـ exe. عشان كده
    // بنستخدم path_provider بدلها للحصول على مسار قياسي وثابت:
    //   Windows: C:\Users\<user>\AppData\Roaming\<app_name>\
    //   macOS:   ~/Library/Application Support/<app_name>/
    //   Linux:   ~/.local/share/<app_name>/
    // ده بيحمي بيانات الموظفين والمرتبات من الضياع لو حد نضّف مجلد
    // الـ build أو نقل الـ exe بمفرده من غير الملفات المصاحبة له.
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

      // مجلد تاني إضافي جنب ملف الـ exe نفسه - أسهل توصله يدويًا (تاخده
      // بفلاشة أو تبعته بسهولة) عن مجلد AppData المخفي. ⚠️ ده مش بديل
      // عن نسخة AppData: مجلد الـ exe بيتمسح لو حد عمل Uninstall أو
      // إعادة تثبيت، فهو مصدر إضافي مش المصدر الأساسي.
      final exeDir = dirname(Platform.resolvedExecutable);
      final exeBackupsDirPath = join(exeDir, 'backups');
      _exeBackupsDirPath = exeBackupsDirPath;

      // ⚠️ بنعمل الباكأب قبل ما نفتح القاعدة أو نبدأ أي migration - لو
      // الترقية نفسها فشلت أو خرّبت البيانات لأي سبب، عندك نسخة سليمة
      // قبلها على طول. فشل أي مسار بيتم تجاهله لوحده (مثلاً لو مجلد
      // الـ exe تحت Program Files ومحتاج صلاحيات أدمن للكتابة فيه) وده
      // ميوقفش تشغيل التطبيق ولا يمنع المسار التاني من النجاح.
      await _createBackupIfNeeded(path, _backupsDirPath!);
      await _createBackupIfNeeded(path, exeBackupsDirPath);
    }

    final db = await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // ⚠️ الباكأب الخارجي (off-site) بيتنفّذ بعد فتح القاعدة، لأن مساره
    // متخزّن جوه app_meta نفسها. ده كمان بيديك ميزة إضافية: النسخة اللي
    // بتتاخد هنا فيها آخر تحديث للـ schema بعد أي migration، مش النسخة
    // القديمة قبله.
    if (isDesktop) {
      await _performOffsiteBackupIfConfigured(db, path);
    }

    return db;
  }

  /// باكأب يدوي فوري لكل المسارات الثلاثة المتاحة دلوقتي - بيتنادى من
  /// شاشة إعدادات النسخ الاحتياطي، من غير ما يحتاج المستخدم يقفل
  /// ويفتح التطبيق تاني. مفيد خصوصًا لما المستخدم يظبط مجلد الباكأب
  /// الخارجي لأول مرة ومحتاج يتأكد إنه شغال على طول.
  Future<void> createManualBackupNow() async {
    if (_dbFilePath == null) return; // القاعدة لسه مفتحتش

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

  // ---------------------------------------------------------------------
  // باكأب خارجي (Off-site) - مجلد المستخدم بيختاره بنفسه، الأفضل يكون
  // مجلد بيتزامن تلقائيًا مع الإنترنت (OneDrive/Google Drive) عشان
  // النسخة تفضل موجودة حتى لو الجهاز نفسه ضاع أو اتعطّل بالكامل. ده
  // الفرق الجوهري عن النسختين التانيين (AppData وجنب الـ exe) اللي
  // الاتنين على نفس القرص الفعلي وبيضيعوا مع بعض في نفس الكارثة.
  //
  // المسار متخزّن جوه app_meta نفسها (key = 'backup_offsite_path')،
  // فمحتاج القاعدة تكون متفتحة الأول عشان نقراه - عشان كده بيتنفّذ
  // بعد openDatabase مش قبلها زي المسارين التانيين.
  // ---------------------------------------------------------------------
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

  /// حفظ مسار مجلد الباكأب الخارجي (مثلاً مجلد جوه OneDrive بتاع
  /// المستخدم). ابعتله string فاضي أو null عشان توقف الباكأب الخارجي.
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

      // لو المجلد مش موجود دلوقتي (فلاشة مش متوصلة، OneDrive لسه
      // بيتزامن، إلخ) بنتجاهل بهدوء - مش مشكلة، هيحصل في التشغيل الجاي.
      final offsiteDir = Directory(offsitePath);
      if (!await offsiteDir.exists()) return;

      _offsiteBackupsDirPath = offsitePath;
      await _createBackupIfNeeded(dbFilePath, offsitePath);
    } catch (_) {
      // فشل الباكأب الخارجي مايوقفش التطبيق برضه - زي المسارين التانيين.
    }
  }


  // ---------------------------------------------------------------------
  // الدالة المشتركة اللي بتعمل الباكأب فعليًا - مستخدمة لكل الأماكن
  // الثلاثة (AppData، جنب الـ exe، الخارجي) بنفس المنطق: نسخة بتاريخ
  // ووقت، مع الاحتفاظ بآخر _maxBackups نسخة بس لكل مجلد.
  // ---------------------------------------------------------------------
  Future<void> _createBackupIfNeeded(
    String dbFilePath,
    String backupsDirPath,
  ) async {
    try {
      final dbFile = File(dbFilePath);
      // أول تشغيل للتطبيق - مفيش قاعدة بيانات لسه أصلاً، مفيش حاجة
      // نعمللها باكأب.
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
    } catch (_) {
      // فشل الباكأب مايمنعش التطبيق من الشغل - بس هيبقى مفيش نسخة
      // لهذا التشغيل بالتحديد في المجلد ده. لو حابب تتبّع الفشل ده،
      // ضيف logging هنا (مثلاً بتاع Sentry أو ملف log محلي).
    }
  }

  Future<void> _pruneOldBackups(Directory backupsDir) async {
    final files = backupsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList();

    if (files.length <= _maxBackups) return;

    files.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));

    for (final oldFile in files.skip(_maxBackups)) {
      try {
        await oldFile.delete();
      } catch (_) {}
    }
  }

  /// قائمة بكل النسخ الاحتياطية الموجودة حاليًا من الأماكن الثلاثة
  /// (AppData + جنب الـ exe + الخارجي لو متفعّل)، الأحدث أولاً - مفيدة
  /// لو حابب تبني شاشة "استعادة نسخة احتياطية" في التطبيق.
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
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.db')),
      );
    }

    files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// استرجاع نسخة احتياطية معيّنة - بيقفل الاتصال الحالي بقاعدة البيانات
  /// أولاً، يستبدل الملف الحالي بالنسخة المختارة، وبعدين يفتح الاتصال
  /// تاني. ⚠️ لازم تعمل restart للتطبيق بعد الاستدعاء ده عشان أي شاشة
  /// فاتحة بيانات قديمة في الذاكرة تتحدّث.
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
        createdAt TEXT NOT NULL
      )
    ''');

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

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        nameAr TEXT NOT NULL,
        nameEn TEXT NOT NULL,
        department TEXT,
        jobTitle TEXT,
        nationalId TEXT,
        hireDate TEXT,
        resignationDate TEXT,   -- ✅ العمود الجديد
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
// وفي _onUpgrade:
    if (oldVersion < 4) {
      // إضافة resignationDate
      try {
        await db
            .execute('ALTER TABLE employees ADD COLUMN resignationDate TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // إضافة nameEn
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN nameEn TEXT DEFAULT \'\'');
        // قد نريد أيضاً تغيير name إلى nameAr
        await db.execute('ALTER TABLE employees RENAME COLUMN name TO nameAr');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      // ختم التكامل (Integrity Seal) - بيمنع تعديل الترخيص مباشرة من
      // قاعدة البيانات (SQLite Browser وغيره) من غير ما يتكشف فورًا
      //
      // ⚠️ الشرط كان oldVersion < 6 مع dbVersion = 6 في نفس الوقت - يعني
      // أي جهاز كان مثبّت عليه إصدار سابق شغال بالفعل بـ dbVersion = 6
      // (قبل إضافة العمودين دول) كان بيفضل عمره ما يشغّل الـ migration ده
      // لأن sqflite بينادي onUpgrade بس لو oldVersion != newVersion.
      // رفعنا dbVersion لـ 7 وغيّرنا الشرط عشان الجهاز ده ياخد الترقية.
      try {
        await db.execute('ALTER TABLE license ADD COLUMN rawCode TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE license ADD COLUMN integritySeal TEXT');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      // إضافة الراتب المتغيّر كجزء منفصل عن الأساسي والبدلات - عشان
      // مطابقة هيكل الراتب الحقيقي (أساسي + متغيّر + بدلات)
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
      // المصروفات - حقل خصم إضافي موجود في ملفات المرتبات الحقيقية
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN expenses REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
  }
} */

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../license/device_fingerprint.dart';
// ⚠️ الاستيراد ده مهم حتى لو مش مستخدم بشكل مباشر في الكود - هو اللي
// بيخلي sqlite3.dart يحمّل نسخة SQLCipher من المكتبة بدل sqlite3
// العادية. لازم يكون موجود في pubspec.yaml (sqlcipher_flutter_libs)
// وميكونش sqlite3_flutter_libs موجود في نفس الوقت (تعارض).

/// ⚠️ ده المصدر الوحيد لقاعدة البيانات في المشروع كله.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase() => instance;

  // ✅ رفع الإصدار إلى 6 (كان واقف عند 4، فمigration الإصدار 5 بتاعك
  // (nameEn/nameAr) كان معمول لكنه معمول له trigger أصلاً لأن target
  // version كان أقل منه - ترقيته لـ 6 هنا خلته يشتغل كمان بالمرة)
  static const int dbVersion = 9;

  // عدد النسخ الاحتياطية اللي بنحتفظ بيها - الأقدم من كده بيتمسح تلقائيًا
  // عشان القرص مايمتلاش. كل نسخة كاملة لملف .db فبيانات المرتبات
  // (مش ضخمة عادةً) فـ 10 نسخ مساحة صغيرة جدًا مقابل حماية حقيقية.
  static const int _maxBackups = 10;

  // ---------------------------------------------------------------------
  // مفتاح تشفير قاعدة البيانات (SQLCipher) - مشتق تلقائيًا من بصمة
  // الجهاز + ملح ثابت، بدل ما يعتمد على كلمة سر يدخلها المستخدم. ده
  // قرار مقصود: نظام أوفلاين بالكامل مفيش فيه "استرجاع كلمة سر" -
  // لو المستخدم نسي كلمة سر يدوية، البيانات بتضيع للأبد. الاشتقاق
  // التلقائي بيحمي من التهديد الحقيقي (نسخ الملف وقراءته بأداة خارجية
  // زي DB Browser) من غير مخاطرة فقدان دائم بسبب نسيان كلمة سر.
  //
  // ⚠️ الملح ده منفصل تمامًا عن مفتاح AES بتاع نظام الترخيص
  // (license_crypto.dart) - تسريب واحد فيهم ميأثرش على التاني.
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

  Future<String> _deriveDbKeyHex() async {
    final salt =
        List<int>.generate(32, (i) => _dbKeySaltPart1[i] ^ _dbKeySaltPart2[i]);
    final fingerprint = await DeviceFingerprint.get();
    final combined = utf8.encode(fingerprint) + salt;
    final hash = sha256.convert(combined);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
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

    // ⚠️ getDatabasesPath() بتاعة sqflite_common_ffi موصوف رسميًا في
    // التوثيق إنها "lame implementation" على الديسكتوب - غالبًا بترجع
    // مسار نسبي لمجلد التشغيل الحالي (working directory)، اللي ممكن
    // يتغيّر أو يتمسح مع أي flutter clean أو نقل للـ exe. عشان كده
    // بنستخدم path_provider بدلها للحصول على مسار قياسي وثابت:
    //   Windows: C:\Users\<user>\AppData\Roaming\<app_name>\
    //   macOS:   ~/Library/Application Support/<app_name>/
    //   Linux:   ~/.local/share/<app_name>/
    // ده بيحمي بيانات الموظفين والمرتبات من الضياع لو حد نضّف مجلد
    // الـ build أو نقل الـ exe بمفرده من غير الملفات المصاحبة له.
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

      // مجلد تاني إضافي جنب ملف الـ exe نفسه - أسهل توصله يدويًا (تاخده
      // بفلاشة أو تبعته بسهولة) عن مجلد AppData المخفي. ⚠️ ده مش بديل
      // عن نسخة AppData: مجلد الـ exe بيتمسح لو حد عمل Uninstall أو
      // إعادة تثبيت، فهو مصدر إضافي مش المصدر الأساسي.
      final exeDir = dirname(Platform.resolvedExecutable);
      final exeBackupsDirPath = join(exeDir, 'backups');
      _exeBackupsDirPath = exeBackupsDirPath;

      // ⚠️ بنعمل الباكأب قبل ما نفتح القاعدة أو نبدأ أي migration - لو
      // الترقية نفسها فشلت أو خرّبت البيانات لأي سبب، عندك نسخة سليمة
      // قبلها على طول. فشل أي مسار بيتم تجاهله لوحده (مثلاً لو مجلد
      // الـ exe تحت Program Files ومحتاج صلاحيات أدمن للكتابة فيه) وده
      // ميوقفش تشغيل التطبيق ولا يمنع المسار التاني من النجاح.
      await _createBackupIfNeeded(path, _backupsDirPath!);
      await _createBackupIfNeeded(path, exeBackupsDirPath);
    }

    final dbKeyHex = isDesktop ? await _deriveDbKeyHex() : null;

    if (isDesktop && dbKeyHex != null) {
      // لو قاعدة بيانات قديمة نص واضح موجودة من قبل تفعيل التشفير،
      // رحّلها لصيغة مشفّرة مرة واحدة بس قبل أي فتح عادي.
      // ⚠️ فشل الترحيل هنا (لأي سبب) ميوقفش تشغيل التطبيق - القاعدة
      // هتفضل نص واضح لهذا التشغيل بس، وهيتم المحاولة تاني في المرة
      // الجاية. الأولوية إن العميل يقدر يفتح البرنامج ويشتغل.
      try {
        await _migrateToEncryptedIfNeeded(path, dbKeyHex);
      } catch (_) {}
    }

    final db = await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: dbKeyHex == null
          ? null
          : (db) async {
              // صيغة x'...' الست-عشرية بتتجنب أي مشاكل quoting لو
              // المفتاح فيه حروف غريبة - هنا مستحيل لأنه hex بس، لكن
              // برضه أنضف صيغة موصى بيها رسميًا من SQLCipher.
              await db.execute("PRAGMA key = \"x'$dbKeyHex'\"");

              // ✅ تحقق دفاعي موصى بيه رسميًا من مكتبة sqlcipher_flutter_libs
              // نفسها: لو رجع string فاضي، معناه إننا مش فعليًا شغالين
              // بنسخة SQLCipher من sqlite3 (المكتبة مش محمّلة صح)،
              // فبنرمي استثناء واضح بدل ما نكمل بصمت وكأن التشفير شغال.
              final result = await db.rawQuery('PRAGMA cipher_version');
              final cipherVersion =
                  result.isNotEmpty ? result.first.values.first : null;
              if (cipherVersion == null || cipherVersion == '') {
                throw StateError(
                  'SQLCipher مش متحمّلة صح - تأكد إن sqlcipher_flutter_libs '
                  'مضافة في pubspec.yaml وإن sqlite3_flutter_libs مش موجودة '
                  'في نفس الوقت (تعارض بين المكتبتين).',
                );
              }
            },
    );

    // ⚠️ الباكأب الخارجي (off-site) بيتنفّذ بعد فتح القاعدة، لأن مساره
    // متخزّن جوه app_meta نفسها. ده كمان بيديك ميزة إضافية: النسخة اللي
    // بتتاخد هنا فيها آخر تحديث للـ schema بعد أي migration، مش النسخة
    // القديمة قبله.
    if (isDesktop) {
      await _performOffsiteBackupIfConfigured(db, path);
    }

    return db;
  }

  // ---------------------------------------------------------------------
  // ترحيل قاعدة بيانات نص واضح (من قبل تفعيل التشفير) لصيغة مشفّرة -
  // بيتم مرة واحدة بس، أول تشغيل بعد تحديث التطبيق للنسخة اللي فيها
  // SQLCipher. الآلية الرسمية الموصى بيها من SQLCipher نفسها:
  //   1) افتح الملف القديم عادي من غير مفتاح (لو نص واضح، هيفتح عادي)
  //   2) اعمل ATTACH لملف جديد فاضي بالمفتاح الجديد
  //   3) استخدم sqlcipher_export() اللي بينسخ كل الجداول والبيانات
  //      للملف الجديد المشفّر دفعة واحدة
  //   4) استبدل الملف القديم بالجديد
  // ---------------------------------------------------------------------
  Future<void> _migrateToEncryptedIfNeeded(
    String dbFilePath,
    String dbKeyHex,
  ) async {
    final dbFile = File(dbFilePath);
    if (!await dbFile.exists()) {
      // أول تشغيل للتطبيق خالص - مفيش قاعدة بيانات لسه، هتتعمل مشفّرة
      // من الأساس في onCreate، مفيش داعي لأي ترحيل.
      return;
    }

    // فحص سريع: القاعدة دي مشفّرة بالفعل ولا لسه نص واضح؟ بنحاول نقرا
    // منها من غير أي مفتاح - لو نجحنا، معناها نص واضح ولازم ترحيل.
    Database? plainDb;
    bool isPlainText = false;
    try {
      plainDb = await openDatabase(dbFilePath, readOnly: true);
      await plainDb.rawQuery('SELECT count(*) FROM sqlite_master');
      isPlainText = true;
    } catch (_) {
      // فشل الفتح/القراءة من غير مفتاح = غالبًا مشفّرة بالفعل من قبل.
      isPlainText = false;
    } finally {
      await plainDb?.close();
    }

    if (!isPlainText) return; // مفيش حاجة نعملها، القاعدة مشفّرة فعلاً

    final tempEncryptedPath = '$dbFilePath.encrypting_tmp';
    final tempFile = File(tempEncryptedPath);
    if (await tempFile.exists()) {
      // بقايا محاولة سابقة فشلت - امسحها وابدأ نضيف.
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

      // استبدال الملف القديم (نص واضح) بالنسخة المشفّرة الجديدة. بناخد
      // نسخة احتياطية من النص الواضح القديم بامتداد مختلف بدل ما نمسحه
      // فورًا - أمان إضافي لو حصل أي خطأ غير متوقع في اللحظة دي.
      final oldPlaintextBackup = File('$dbFilePath.pre_encryption_backup');
      if (await oldPlaintextBackup.exists()) {
        await oldPlaintextBackup.delete();
      }
      await dbFile.rename(oldPlaintextBackup.path);
      await tempFile.rename(dbFilePath);
    } catch (e) {
      // فشل الترحيل - سيب الملف الأصلي (نص واضح) زي ما هو، امسح أي
      // ملف مؤقت ناقص، والتطبيق هيحاول يرحّل تاني في التشغيل الجاي.
      await sourceDb?.close();
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// باكأب يدوي فوري لكل المسارات الثلاثة المتاحة دلوقتي - بيتنادى من
  /// شاشة إعدادات النسخ الاحتياطي، من غير ما يحتاج المستخدم يقفل
  /// ويفتح التطبيق تاني. مفيد خصوصًا لما المستخدم يظبط مجلد الباكأب
  /// الخارجي لأول مرة ومحتاج يتأكد إنه شغال على طول.
  Future<void> createManualBackupNow() async {
    if (_dbFilePath == null) return; // القاعدة لسه مفتحتش

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

  // ---------------------------------------------------------------------
  // باكأب خارجي (Off-site) - مجلد المستخدم بيختاره بنفسه، الأفضل يكون
  // مجلد بيتزامن تلقائيًا مع الإنترنت (OneDrive/Google Drive) عشان
  // النسخة تفضل موجودة حتى لو الجهاز نفسه ضاع أو اتعطّل بالكامل. ده
  // الفرق الجوهري عن النسختين التانيين (AppData وجنب الـ exe) اللي
  // الاتنين على نفس القرص الفعلي وبيضيعوا مع بعض في نفس الكارثة.
  //
  // المسار متخزّن جوه app_meta نفسها (key = 'backup_offsite_path')،
  // فمحتاج القاعدة تكون متفتحة الأول عشان نقراه - عشان كده بيتنفّذ
  // بعد openDatabase مش قبلها زي المسارين التانيين.
  // ---------------------------------------------------------------------
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

  /// حفظ مسار مجلد الباكأب الخارجي (مثلاً مجلد جوه OneDrive بتاع
  /// المستخدم). ابعتله string فاضي أو null عشان توقف الباكأب الخارجي.
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

      // لو المجلد مش موجود دلوقتي (فلاشة مش متوصلة، OneDrive لسه
      // بيتزامن، إلخ) بنتجاهل بهدوء - مش مشكلة، هيحصل في التشغيل الجاي.
      final offsiteDir = Directory(offsitePath);
      if (!await offsiteDir.exists()) return;

      _offsiteBackupsDirPath = offsitePath;
      await _createBackupIfNeeded(dbFilePath, offsitePath);
    } catch (_) {
      // فشل الباكأب الخارجي مايوقفش التطبيق برضه - زي المسارين التانيين.
    }
  }

  // ---------------------------------------------------------------------
  // الدالة المشتركة اللي بتعمل الباكأب فعليًا - مستخدمة لكل الأماكن
  // الثلاثة (AppData، جنب الـ exe، الخارجي) بنفس المنطق: نسخة بتاريخ
  // ووقت، مع الاحتفاظ بآخر _maxBackups نسخة بس لكل مجلد.
  // ---------------------------------------------------------------------
  Future<void> _createBackupIfNeeded(
    String dbFilePath,
    String backupsDirPath,
  ) async {
    try {
      final dbFile = File(dbFilePath);
      // أول تشغيل للتطبيق - مفيش قاعدة بيانات لسه أصلاً، مفيش حاجة
      // نعمللها باكأب.
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
    } catch (_) {
      // فشل الباكأب مايمنعش التطبيق من الشغل - بس هيبقى مفيش نسخة
      // لهذا التشغيل بالتحديد في المجلد ده. لو حابب تتبّع الفشل ده،
      // ضيف logging هنا (مثلاً بتاع Sentry أو ملف log محلي).
    }
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

  /// قائمة بكل النسخ الاحتياطية الموجودة حاليًا من الأماكن الثلاثة
  /// (AppData + جنب الـ exe + الخارجي لو متفعّل)، الأحدث أولاً - مفيدة
  /// لو حابب تبني شاشة "استعادة نسخة احتياطية" في التطبيق.
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

  /// استرجاع نسخة احتياطية معيّنة - بيقفل الاتصال الحالي بقاعدة البيانات
  /// أولاً، يستبدل الملف الحالي بالنسخة المختارة، وبعدين يفتح الاتصال
  /// تاني. ⚠️ لازم تعمل restart للتطبيق بعد الاستدعاء ده عشان أي شاشة
  /// فاتحة بيانات قديمة في الذاكرة تتحدّث.
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
        createdAt TEXT NOT NULL
      )
    ''');

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

    await db.execute('''
      CREATE TABLE  IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        nameAr TEXT NOT NULL,
        nameEn TEXT NOT NULL,
        department TEXT,
        jobTitle TEXT,
        nationalId TEXT,
        hireDate TEXT,
        resignationDate TEXT,   -- ✅ العمود الجديد
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
// وفي _onUpgrade:
    if (oldVersion < 4) {
      // إضافة resignationDate
      try {
        await db
            .execute('ALTER TABLE employees ADD COLUMN resignationDate TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // إضافة nameEn
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN nameEn TEXT DEFAULT \'\'');
        // قد نريد أيضاً تغيير name إلى nameAr
        await db.execute('ALTER TABLE employees RENAME COLUMN name TO nameAr');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      // ختم التكامل (Integrity Seal) - بيمنع تعديل الترخيص مباشرة من
      // قاعدة البيانات (SQLite Browser وغيره) من غير ما يتكشف فورًا
      //
      // ⚠️ الشرط كان oldVersion < 6 مع dbVersion = 6 في نفس الوقت - يعني
      // أي جهاز كان مثبّت عليه إصدار سابق شغال بالفعل بـ dbVersion = 6
      // (قبل إضافة العمودين دول) كان بيفضل عمره ما يشغّل الـ migration ده
      // لأن sqflite بينادي onUpgrade بس لو oldVersion != newVersion.
      // رفعنا dbVersion لـ 7 وغيّرنا الشرط عشان الجهاز ده ياخد الترقية.
      try {
        await db.execute('ALTER TABLE license ADD COLUMN rawCode TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE license ADD COLUMN integritySeal TEXT');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      // إضافة الراتب المتغيّر كجزء منفصل عن الأساسي والبدلات - عشان
      // مطابقة هيكل الراتب الحقيقي (أساسي + متغيّر + بدلات)
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
      // المصروفات - حقل خصم إضافي موجود في ملفات المرتبات الحقيقية
      try {
        await db.execute(
            'ALTER TABLE employees ADD COLUMN expenses REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
  }
}
