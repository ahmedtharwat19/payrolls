import 'permission.dart';

class Role {
  final String id;
  final String name; // اسم الدور: Admin, HR, Accountant, Viewer...
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
          name: 'مدير النظام',
          isSystemRole: true,
          permissions: Permission.values.toSet(), // كل الصلاحيات
        ),
        const Role(
          id: 'hr',
          name: 'موارد بشرية',
          isSystemRole: true,
          permissions: {
            Permission.viewEmployees,
            Permission.addEmployee,
            Permission.editEmployee,
            Permission.viewPayroll,
            Permission.viewReports,
          },
        ),
        const Role(
          id: 'accountant',
          name: 'محاسب',
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
        const Role(
          id: 'viewer',
          name: 'مشاهدة فقط',
          isSystemRole: true,
          permissions: {
            Permission.viewEmployees,
            Permission.viewPayroll,
            Permission.viewReports,
          },
        ),
      ];
}
