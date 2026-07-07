import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// ⚠️ ده المصدر الوحيد لقاعدة البيانات في المشروع كله. لازم كل الملفات
/// (employee_storage, attendance_storage, auth_service, license_service,
/// payroll_storage, payment_storage...) تستورد من هنا بس. لو فيه ملف تاني
/// اسمه app_database.dart في مكان تاني بيعمل openDatabase بنفسه، امسحه أو
/// خليه يعمل export لنفس الكلاس ده - وجود نسختين بيفتحوا نفس ملف قاعدة
/// البيانات بيسبب تعارض في الجداول حسب مين بيفتح الأول.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  /// للتوافق مع كود قديم بينادي AppDatabase() (بدل .instance) -
  /// بيرجع نفس الـ singleton بالظبط.
  factory AppDatabase() => instance;

  static const int dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return openDatabase('payrolls.db', version: dbVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
      CREATE TABLE users (
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
      CREATE TABLE roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        permissions TEXT NOT NULL,
        isSystemRole INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE activated_devices (
        deviceFingerprint TEXT PRIMARY KEY,
        slotNumber INTEGER NOT NULL,
        activatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE license (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        licenseJson TEXT NOT NULL,
        activatedAt TEXT NOT NULL,
        lastCheckDate TEXT NOT NULL,
        remainingDays INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE employees (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        department TEXT,
        jobTitle TEXT,
        nationalId TEXT,
        hireDate TEXT,
        contractType TEXT,
        employeeType TEXT,
        insuranceCode TEXT,
        insuranceFile TEXT,
        taxFile TEXT,
        basicSalary REAL NOT NULL DEFAULT 0,
        allowances REAL NOT NULL DEFAULT 0,
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
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        employeeId TEXT,
        employeeName TEXT,
        date TEXT,
        overtimeHours REAL,
        lateMinutes REAL,
        notes TEXT
      )
    ''');

    // ---- الجداول الجديدة: مرتبات شهرية + دفعات الصرف ----

    await db.execute('''
      CREATE TABLE payroll_records (
        id TEXT PRIMARY KEY,
        employeeId TEXT NOT NULL,
        employeeName TEXT NOT NULL,
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
      CREATE TABLE salary_payments (
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
        CREATE TABLE IF NOT EXISTS app_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      for (final col in ['bankName', 'bankAccount', 'bankSwift', 'bankIban']) {
        try {
          await db.execute('ALTER TABLE employees ADD COLUMN $col TEXT DEFAULT \'\'');
        } catch (_) {
          // العمود ممكن يكون موجود بالفعل لو جاي من نسخة قديمة تانية
        }
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS attendance (
            id TEXT PRIMARY KEY,
            employeeId TEXT,
            employeeName TEXT,
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
        CREATE TABLE IF NOT EXISTS payroll_records (
          id TEXT PRIMARY KEY,
          employeeId TEXT NOT NULL,
          employeeName TEXT NOT NULL,
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
        CREATE TABLE IF NOT EXISTS salary_payments (
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
  }
}
