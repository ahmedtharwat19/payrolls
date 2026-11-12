// lib/database/attendance_storage.dart

import 'package:sqflite/sqflite.dart';
import '../models/attendance_model.dart';
import 'app_database.dart';

class AttendanceStorage {
  final AppDatabase _db = AppDatabase();

  Future<void> insertAttendance(Attendance attendance) async {
    final db = await _db.database;
    await db.insert(
      'attendance',
      attendance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Attendance>> getAllAttendances() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query('attendance');
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<List<Attendance>> getAttendancesByEmployee(String employeeId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
    );
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<List<Attendance>> getAttendancesByMonth(int year, int month) async {
    final db = await _db.database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);
    
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<List<Attendance>> getAttendancesByDateRange(
    DateTime start, 
    DateTime end,
  ) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<void> deleteAttendance(String id) async {
    final db = await _db.database;
    await db.delete(
      'attendance',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteByEmployee(String employeeId) async {
    final db = await _db.database;
    await db.delete(
      'attendance',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
    );
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('attendance');
  }

  // ✅ حساب إجمالي ساعات الاوفر تايم لموظف في شهر
  Future<double> getTotalOvertimeByEmployeeAndMonth(
    String employeeId, 
    int year, 
    int month,
  ) async {
    final list = await getAttendancesByEmployee(employeeId);
    double total = 0;
    for (var a in list) {
      if (a.date.year == year && a.date.month == month) {
        total += a.overtimeHours;
      }
    }
    return total;
  }

  // ✅ حساب إجمالي دقائق التأخير لموظف في شهر
  Future<double> getTotalLateMinutesByEmployeeAndMonth(
    String employeeId, 
    int year, 
    int month,
  ) async {
    final list = await getAttendancesByEmployee(employeeId);
    double total = 0;
    for (var a in list) {
      if (a.date.year == year && a.date.month == month) {
        total += a.lateMinutes;
      }
    }
    return total;
  }
}