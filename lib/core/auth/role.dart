

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
    // ✅ تحويل isSystemRole من int إلى bool بشكل صحيح
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
      // صلاحية غير معروفة (مثلاً من نسخة أحدث) بتتجاهل بدل ما تتحوّل
      // لصلاحية فعلية - كان ده بيمنح viewEmployees بالغلط.
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
      Role(
        id: 'admin',
        name: 'role_admin',
        permissions: Permission.values,
        isSystemRole: true,
      ),
      Role(
        id: 'hr',
        name: 'role_hr',
        permissions: [
          Permission.viewEmployees,
          Permission.viewPayroll,
          Permission.runPayroll,
          Permission.editSalary,
          Permission.viewReports,
          Permission.exportReports,
        ],
        isSystemRole: true,
      ),
      Role(
        id: 'accountant',
        name: 'role_accountant',
        permissions: [
          Permission.viewEmployees,
          Permission.viewPayroll,
          Permission.runPayroll,
          Permission.viewReports,
          Permission.exportReports,
        ],
        isSystemRole: true,
      ),
      Role(
        id: 'viewer',
        name: 'role_viewer',
        permissions: [
          Permission.viewEmployees,
          Permission.viewPayroll,
          Permission.viewReports,
        ],
        isSystemRole: true,
      ),
    ];
  }
}