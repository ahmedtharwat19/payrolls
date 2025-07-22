import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/employee_model.dart';

class EmployeeStorage {
  static const _key = 'employees';

  static Future<void> saveEmployees(List<Employee> employees) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = employees.map((e) => e.toJson()).toList();
    await prefs.setString(_key, json.encode(jsonList));
  }

  static Future<List<Employee>> loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];
    final List decoded = json.decode(jsonString);
    return decoded.map<Employee>((e) => Employee.fromJson(e)).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
