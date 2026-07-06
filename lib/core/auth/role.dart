/* import 'permission.dart';

class Role {
  final String id;
  final String name; // مفتاح ترجمة (easy_localization) - استخدمه: role.name.tr()
  final Set<Permission> permissions;
  final bool isSystemRole; // الأدوار الافتراضية اللي المستخدم مايقدرش يمسحها

  const Role({
    required this.id,
    required this.name,
    required this.permissions,
    this.isSystemRole = false,
  });

  bool can(Permission p) => permissions.contains(p);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'permissions': permissions.map((p) => p.name).toList(),
        'isSystemRole': isSystemRole,
      };

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: json['id'],
        name: json['name'],
        isSystemRole: json['isSystemRole'] ?? false,
        permissions: (json['permissions'] as List)
            .map((name) => Permission.values.firstWhere((p) => p.name == name))
            .toSet(),
      );

  /// الأدوار الافتراضية اللي بتتزرع أول تشغيل للبرنامج
  static List<Role> defaultRoles() => [
        Role(
          id: 'admin',
          name: 'role_admin',
          isSystemRole: true,
          permissions: Permission.values.toSet(), // كل الصلاحيات
        ),
        Role(
          id: 'hr',
          name: 'role_hr',
          isSystemRole: true,
          permissions: {
            Permission.viewEmployees,
            Permission.addEmployee,
            Permission.editEmployee,
            Permission.viewPayroll,
            Permission.viewReports,
          },
        ),
        Role(
          id: 'accountant',
          name: 'role_accountant',
          isSystemRole: true,
          permissions: {
            Permission.viewEmployees,
            Permission.viewPayroll,
            Permission.runPayroll,
            Permission.editSalary,
            Permission.viewReports,
            Permission.exportReports,
          },
        ),
        Role(
          id: 'viewer',
          name: 'role_viewer',
          isSystemRole: true,
          permissions: {
            Permission.viewEmployees,
            Permission.viewPayroll,
            Permission.viewReports,
          },
        ),
      ];
}
 */

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
      permissions: (json['permissions'] as List<dynamic>)
          .map((e) => Permission.values.firstWhere(
                (p) => p.name == e,
                orElse: () => Permission.viewEmployees,
              ))
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