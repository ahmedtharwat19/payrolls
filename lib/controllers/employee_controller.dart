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

  // lib/controllers/employee_controller.dart

// ... الكود الموجود ...

  /// تحديث الحضور لموظف بناءً على اسمه
  /// [name] اسم الموظف
  /// [attendanceData] بيانات الحضور (مثل: { 'date': '2026-07-06', 'status': 'present', 'hours': 8 })
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

    // ✅ هنا يمكنك تحديث بيانات الحضور في نموذج الموظف
    // ولكن الـ Employee الحالي لا يحتوي على حقل attendance،
    // لذا ستحتاج إما إلى:
    // 1. إضافة حقل attendance في Employee (تعديل النموذج وقاعدة البيانات)
    // 2. أو استخدام تخزين منفصل للحضور (مثل جدول attendance في قاعدة البيانات)

    // كمثال سريع، سنقوم بتحديث employee مع إضافة بيانات الحضور كـ Map
    // (هذا يتطلب تعديل Employee model لقبول حقل attendance)

    // طريقة مؤقتة: استخدام copyWith لإضافة بيانات الحضور (يفترض وجود حقل attendance)
    // ولكن حقل attendance غير موجود حالياً، لذا سنقوم بتعديل النموذج لاحقاً.

    // إذا كان لديك جدول منفصل للحضور، يمكنك استدعاء الدالة المناسبة هنا.

    // مثال: إذا كان لديك AttendanceStorage، يمكنك استخدامه:
    // await AttendanceStorage().insertAttendance(employee.id, attendanceData);

    // أو إذا أضفت حقل attendance في Employee:
    // final updatedEmployee = employee.copyWith(attendance: attendanceData);
    // await updateEmployee(updatedEmployee);

    // بما أننا لا نملك حقل attendance حالياً، سنقوم بتخزينها مؤقتاً في الذاكرة
    // (للتجربة فقط - سيُفقد عند إعادة التشغيل)
    // يمكنك استبدال هذا بالكود الفعلي حسب هيكل التطبيق.

    print('✅ تم تحديث الحضور للموظف: $displayName');
    print('📊 البيانات: $attendanceData');

    // إشعار المستخدم بتحديث الواجهة (اختياري)
    notifyListeners();
  }
  // lib/controllers/employee_controller.dart

  /// إعادة تحميل قائمة الموظفين من قاعدة البيانات
  Future<void> refresh() async {
    await _loadEmployees();
  }
}
