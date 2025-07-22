// lib/controllers/employee_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee_model.dart';

class EmployeeController extends ChangeNotifier {
  List<Employee> _employees = [];
  List<Employee> get employees => _employees;

  final double _overtimeRate = 20; // Default, can be read from SharedPreferences

  Future<void> loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('employees');
    if (data != null) {
      final decoded = jsonDecode(data) as List;
      _employees = decoded.map((e) => Employee.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> saveEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_employees.map((e) => e.toJson()).toList());
    await prefs.setString('employees', encoded);
  }

  void addEmployee(Employee employee) {
    _employees.add(employee);
    notifyListeners();
    saveEmployees();
  }

  void updateEmployee(String id, Employee updated) {
    final index = _employees.indexWhere((e) => e.id == id);
    if (index != -1) {
      _employees[index] = updated;
      notifyListeners();
      saveEmployees();
    }
  }

  void deleteEmployee(String id) {
    _employees.removeWhere((e) => e.id == id);
    notifyListeners();
    saveEmployees();
  }

  void updateAttendanceByName(String name, double overtime, double lateMinutes) {
    final index = _employees.indexWhere((e) => e.name == name);
    if (index != -1) {
      final current = _employees[index];
      final newAllowances = current.allowances + overtime * _overtimeRate;
      final newDeductions = current.deductions + ((lateMinutes / 60) * (current.basicSalary / 30));
      _employees[index] = current.copyWith(
        allowances: newAllowances,
        deductions: newDeductions,
      );
      notifyListeners();
      saveEmployees();
    }
  }
}
