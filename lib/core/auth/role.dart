// lib/core/auth/role.dart
import 'permission.dart';

class Role {
  final String id;
  final String name;
  final List<Permission> permissions;
  final bool isSystemRole;

  const Role({
    required this.id,
    required this.name,
    this.permissions = const [],
    this.isSystemRole = false,
  });

  bool can(Permission p) => permissions.contains(p);

  factory Role.fromJson(Map<String, dynamic> json) {
    final isSystem = json['isSystemRole'];
    final bool isSystemRoleBool;
    if (isSystem is int) {
      isSystemRoleBool = isSystem == 1;
    } else if (isSystem is bool) {
      isSystemRoleBool = isSystem;
    } else {
      isSystemRoleBool = false;
    }

    return Role(
      id: json['id'] as String,
      name: json['name'] as String,
      permissions: (json['permissions'] as List<dynamic>)
          .map((e) => Permission.values.where((p) => p.name == e))
          .expand((m) => m)
          .toList(),
      isSystemRole: isSystemRoleBool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'permissions': permissions.map((p) => p.name).toList(),
      'isSystemRole': isSystemRole ? 1 : 0,
    };
  }

  static List<Role> defaultRoles() {
    return [
      // 1. المدير - كل الصلاحيات
      Role(
        id: 'admin',
        name: 'role_admin',
        permissions: Permission.values, // كل حاجة
        isSystemRole: true,
      ),

      // 2. HR - موارد بشرية (إجازات، جزاءات، حضور، إعدادات حضور)
      Role(
        id: 'hr',
        name: 'role_hr',
        permissions: [
          Permission.viewEmployees,
          Permission.addEmployee,
          Permission.editEmployee,
          Permission.viewPayroll,
          Permission.runPayroll,
          Permission.editSalary,
          Permission.viewReports,
          Permission.exportReports,
          Permission.manageAttendance, // ✅
          Permission.manageAttendanceSettings, // ✅ جديد
          Permission.manageLeaves, // ✅
          Permission.managePenalties, // ✅
          Permission.viewDashboard, // ✅
          Permission.viewEOSCalculator, // ✅
        ],
        isSystemRole: true,
      ),

      // 3. المحاسب - مالية فقط (مش حضور ولا إجازات)
      Role(
        id: 'accountant',
        name: 'role_accountant',
        permissions: [
          Permission.viewEmployees,
          Permission.viewPayroll,
          Permission.runPayroll,
          Permission.viewReports,
          Permission.exportReports,
          Permission.viewDashboard,
          Permission.viewCompliance, // ✅ بس ده
        ],
        isSystemRole: true,
      ),

      // 4. مشاهد - قراءة فقط
      Role(
        id: 'viewer',
        name: 'role_viewer',
        permissions: [
          Permission.viewEmployees,
          Permission.viewPayroll,
          Permission.viewReports,
          Permission.viewDashboard, // لوحة التحكم فقط
        ],
        isSystemRole: true,
      ),
    ];
  }
}
