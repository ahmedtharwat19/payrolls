// lib/database/employee_storage.dart

import 'package:sqflite/sqflite.dart';
import '../models/employee_model.dart';
import 'app_database.dart';

class EmployeeStorage {
  final AppDatabase _db = AppDatabase();

/*   Future<void> insertEmployee(Employee employee) async {
    final db = await _db.database;
    await db.insert(
      'employees',
      employee.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  } */

  // lib/database/employee_storage.dart

  Future<void> insertEmployee(Employee employee) async {
    try {
      final db = await _db.database;
      await db.insert(
        'employees',
        employee.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ تم إضافة الموظف: ${employee.nameAr} (${employee.nameEn})');
    } catch (e) {
      print('❌ خطأ في الإضافة: $e');
      rethrow;
    }
  }

  Future<List<Employee>> getAllEmployees() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query('employees');
    return maps.map((map) => Employee.fromMap(map)).toList();
  }

  Future<Employee?> getEmployeeById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Employee.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateEmployee(Employee employee) async {
    final db = await _db.database;
    await db.update(
      'employees',
      employee.toMap(),
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  Future<void> deleteEmployee(String id) async {
    final db = await _db.database;
    await db.delete(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('employees');
  }
}
