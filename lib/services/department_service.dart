// lib/services/department_service.dart
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

class DepartmentService {
  Future<List<String>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('departments', orderBy: 'name ASC');
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> add(String name) async {
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return;

    final db = await AppDatabase.instance.database;
    await db.insert(
      'departments',
      {'id': trimmed, 'name': trimmed},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    // ✅ تحقق: هل فيه موظفين في القسم ده؟
    final employeesCount = await db.rawQuery(
      'SELECT COUNT(*) as c FROM employees WHERE department = ?',
      [id],
    );
    final count = employeesCount.first['c'] as int;
    if (count > 0) {
      throw Exception('department_has_employees');
    }
    await db.delete('departments', where: 'id = ?', whereArgs: [id]);
  }
}
