// lib/controllers/employee_controller.dart

import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../database/employee_storage.dart';

class EmployeeController extends ChangeNotifier {
  List<Employee> _employees = [];
  final EmployeeStorage _storage = EmployeeStorage();

  List<Employee> get employees => _employees;

  EmployeeController() {
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    _employees = await _storage.getAllEmployees();
    notifyListeners();
  }

  /// إعادة تحميل الموظفين (متاحة للاستخدام الخارجي)
  Future<void> loadEmployees() async {
    await _loadEmployees();
  }

  /// اسم مستعار لـ loadEmployees
  Future<void> refresh() async {
    await _loadEmployees();
  }

  Future<void> addEmployee(Employee employee) async {
    await _storage.insertEmployee(employee);
    _employees.add(employee);
    notifyListeners();
  }

  Future<void> updateEmployee(Employee employee) async {
    await _storage.updateEmployee(employee);
    final index = _employees.indexWhere((e) => e.id == employee.id);
    if (index != -1) {
      _employees[index] = employee;
      notifyListeners();
    }
  }

  Future<void> deleteEmployee(String id) async {
    await _storage.deleteEmployee(id);
    _employees.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Employee? getEmployeeById(String id) {
    try {
      return _employees.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// تحديث الحضور لموظف بناءً على اسمه
  Future<void> updateAttendanceByName(
    String name,
    Map<String, dynamic> attendanceData, {
    BuildContext? context,
  }) async {
    final index = _employees.indexWhere(
      (e) =>
          e.nameAr.toLowerCase() == name.toLowerCase() ||
          e.nameEn.toLowerCase() == name.toLowerCase(),
    );
    if (index == -1) {
      throw Exception('الموظف "$name" غير موجود');
    }
    final employee = _employees[index];
    final displayName =
        context != null ? employee.getDisplayName(context) : employee.nameAr;

    print('✅ تم تحديث الحضور للموظف: $displayName');
    print('📊 البيانات: $attendanceData');

    notifyListeners();
  }
}
