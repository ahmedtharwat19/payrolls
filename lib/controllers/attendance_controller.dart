// lib/controllers/attendance_controller.dart

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/attendance_model.dart';
import '../database/attendance_storage.dart';
import 'employee_controller.dart';

class AttendanceController extends ChangeNotifier {
  List<Attendance> _attendances = [];
  final AttendanceStorage _storage = AttendanceStorage();

  List<Attendance> get attendances => _attendances;

  AttendanceController() {
    _loadAttendances();
  }

  Future<void> _loadAttendances() async {
    _attendances = await _storage.getAllAttendances();
    notifyListeners();
  }

  /// إضافة سجل حضور جديد
  Future<void> addAttendance(Attendance attendance) async {
    await _storage.insertAttendance(attendance);
    _attendances.add(attendance);
    notifyListeners();
  }

  /// تحديث الحضور للموظف بناءً على اسمه
  Future<void> updateAttendanceByName(
    String name, {
    double overtimeHours = 0,
    double lateMinutes = 0,
    String? date,
  }) async {
    try {
      // البحث عن الموظف
      final employeeController = EmployeeController();
      final employee = employeeController.employees.firstWhere(
        (e) => e.name.toLowerCase() == name.toLowerCase(),
        orElse: () => throw Exception('الموظف "$name" غير موجود'),
      );

      final attendance = Attendance(
        id: const Uuid().v4(),
        employeeId: employee.id,
        employeeName: employee.name,
        date: DateTime.parse(date ?? DateTime.now().toIso8601String()),
        overtimeHours: overtimeHours,
        lateMinutes: lateMinutes,
        notes: 'تم الاستيراد من ملف',
      );

      await addAttendance(attendance);
      
      print('✅ تم تحديث الحضور للموظف: ${employee.name}');
      print('   ⏰ الاوفر تايم: $overtimeHours ساعات');
      print('   ⏱️ التأخير: $lateMinutes دقائق');
      
    } catch (e) {
      print('❌ خطأ في تحديث الحضور: $e');
      rethrow;
    }
  }

  /// جلب سجلات الحضور لموظف
  Future<List<Attendance>> getAttendancesByEmployee(String employeeId) async {
    return await _storage.getAttendancesByEmployee(employeeId);
  }

  /// جلب سجلات الحضور لشهر معين
  Future<List<Attendance>> getAttendancesByMonth(int year, int month) async {
    return await _storage.getAttendancesByMonth(year, month);
  }

  /// جلب سجلات الحضور في نطاق تاريخي
  Future<List<Attendance>> getAttendancesByDateRange(
    DateTime start, 
    DateTime end,
  ) async {
    return await _storage.getAttendancesByDateRange(start, end);
  }

  /// حساب إجمالي الاوفر تايم لموظف في شهر
  Future<double> getTotalOvertimeByEmployeeAndMonth(
    String employeeId, 
    int year, 
    int month,
  ) async {
    return await _storage.getTotalOvertimeByEmployeeAndMonth(
      employeeId, 
      year, 
      month,
    );
  }

  /// حساب إجمالي التأخير لموظف في شهر
  Future<double> getTotalLateMinutesByEmployeeAndMonth(
    String employeeId, 
    int year, 
    int month,
  ) async {
    return await _storage.getTotalLateMinutesByEmployeeAndMonth(
      employeeId, 
      year, 
      month,
    );
  }

  /// حذف سجل حضور
  Future<void> deleteAttendance(String id) async {
    await _storage.deleteAttendance(id);
    _attendances.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  /// حذف جميع سجلات موظف
  Future<void> deleteByEmployee(String employeeId) async {
    await _storage.deleteByEmployee(employeeId);
    _attendances.removeWhere((a) => a.employeeId == employeeId);
    notifyListeners();
  }

  /// تحديث قائمة الحضور
  Future<void> refresh() async {
    await _loadAttendances();
  }
}