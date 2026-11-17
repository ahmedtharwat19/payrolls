// lib/services/attendance_service.dart

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/settings/attendance_settings.dart';
import '../database/app_database.dart';
import '../models/attendance_record_model.dart';

class AttendanceService {
  final _uuid = const Uuid();

  Future<AttendanceRecord?> checkIn(String employeeId) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    final settings = await AttendanceSettingsService.load();
    // ✅ لو اليوم ده عطلة، متسجلش حضور
    if (settings.isWeekend(now)) {
      return null;
    }

    final existing = await db.query(
      'attendance_records',
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, today],
    );
    if (existing.isNotEmpty) {
      return AttendanceRecord.fromMap(existing.first);
    }

    // ✅ حساب التأخير بعد سماحية الـ Grace Period
    final workStart = settings.getWorkStart(now);
    final graceEnd = workStart.add(Duration(minutes: settings.graceMinutes));
    int lateMins = 0;
    if (now.isAfter(graceEnd)) {
      lateMins = now.difference(workStart).inMinutes;
    }

    final record = AttendanceRecord(
      id: _uuid.v4(),
      employeeId: employeeId,
      date: today,
      checkInTime: DateFormat('HH:mm').format(now),
      lateMinutes: lateMins,
      status: 'present',
    );
    await db.insert('attendance_records', record.toMap());
    return record;
  }

  Future<AttendanceRecord?> checkOut(String employeeId) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    final settings = await AttendanceSettingsService.load();

    final existing = await db.query(
      'attendance_records',
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, today],
    );
    if (existing.isEmpty) return null;

    final record = AttendanceRecord.fromMap(existing.first);
    if (record.checkOutTime != null) return record;

    // ✅ حساب الإضافي بعد نهاية العمل
    final workEnd = settings.getWorkEnd(now);
    int overtimeMins = 0;
    if (now.isAfter(workEnd)) {
      overtimeMins = now.difference(workEnd).inMinutes;
    }

    await db.update(
      'attendance_records',
      {
        'checkOutTime': DateFormat('HH:mm').format(now),
        'overtimeMinutes': overtimeMins,
      },
      where: 'id = ?',
      whereArgs: [record.id],
    );

    return record;
  }

  Future<AttendanceRecord?> getAttendanceForDay(
      String employeeId, String date) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'attendance_records',
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
    if (rows.isEmpty) return null;
    return AttendanceRecord.fromMap(rows.first);
  }

  Future<Map<String, int>> getMonthlyAttendanceStats({
    required String employeeId,
    required int month,
    required int year,
  }) async {
    final db = await AppDatabase.instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final prefix = '$year-$monthStr';

    final rows = await db.query(
      'attendance_records',
      where: 'employeeId = ? AND date LIKE ?',
      whereArgs: [employeeId, '$prefix%'],
    );

    int totalLate = 0;
    int totalOvertime = 0;
    for (var row in rows) {
      final record = AttendanceRecord.fromMap(row);
      totalLate += record.lateMinutes;
      totalOvertime += record.overtimeMinutes;
    }
    return {
      'totalLateMinutes': totalLate,
      'totalOvertimeMinutes': totalOvertime,
    };
  }
}
