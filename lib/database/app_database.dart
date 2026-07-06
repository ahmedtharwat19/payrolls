// lib/database/app_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'payrolls.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE employees (
        id TEXT PRIMARY KEY,
        name TEXT,
        department TEXT,
        jobTitle TEXT,
        nationalId TEXT,
        hireDate TEXT,
        contractType TEXT,
        employeeType TEXT,
        insuranceCode TEXT,
        insuranceFile TEXT,
        taxFile TEXT,
        basicSalary REAL,
        allowances REAL,
        deductions REAL,
        salaryType TEXT,
        paymentMethod TEXT,
        isActive INTEGER,
        bankName TEXT,
        bankAccount TEXT,
        bankSwift TEXT,
        bankIban TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE roles (
        id TEXT PRIMARY KEY,
        name TEXT,
        permissions TEXT,
        isSystemRole INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE,
        passwordHash TEXT,
        salt TEXT,
        roleId TEXT,
        isActive INTEGER,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE license (
        id INTEGER PRIMARY KEY,
        licenseJson TEXT,
        activatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activated_devices (
        deviceFingerprint TEXT PRIMARY KEY,
        slotNumber INTEGER,
        activatedAt TEXT
      )
    ''');

    // في app_database.dart - أضف في دالة _onCreate

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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // إضافة أعمدة البنك إذا كانت غير موجودة
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN bankName TEXT');
        await db.execute('ALTER TABLE employees ADD COLUMN bankAccount TEXT');
        await db.execute('ALTER TABLE employees ADD COLUMN bankSwift TEXT');
        await db.execute('ALTER TABLE employees ADD COLUMN bankIban TEXT');
      } catch (_) {}
    }
  }
}
