// lib/core/auth/permission.dart

enum Permission {
  // ============ الموظفين ============
  viewEmployees,
  addEmployee,
  editEmployee,
  deleteEmployee,

  // ============ المرتبات ============
  viewPayroll,
  runPayroll,
  editSalary,

  // ============ التقارير ============
  viewReports,
  exportReports,

  // ============ الإدارة ============
  manageUsers,
  manageRoles,
  manageSettings,
  manageLicense,
  manageData,

  // ============ ✅ جديد: الموارد البشرية ============
  manageAttendance,
  manageLeaves,
  managePenalties,
  viewDashboard,
  viewCompliance,
  viewEOSCalculator,
  manageAttendanceSettings,
}

extension PermissionLabel on Permission {
  String get labelKey {
    switch (this) {
      case Permission.viewEmployees:
        return 'permission_view_employees';
      case Permission.addEmployee:
        return 'add_employee';
      case Permission.editEmployee:
        return 'edit_employee';
      case Permission.deleteEmployee:
        return 'delete_employee';
      case Permission.viewPayroll:
        return 'permission_view_payroll';
      case Permission.runPayroll:
        return 'permission_run_payroll';
      case Permission.editSalary:
        return 'permission_edit_salary';
      case Permission.viewReports:
        return 'permission_view_reports';
      case Permission.exportReports:
        return 'permission_export_reports';
      case Permission.manageUsers:
        return 'permission_manage_users';
      case Permission.manageRoles:
        return 'permission_manage_roles';
      case Permission.manageSettings:
        return 'permission_manage_settings';
      case Permission.manageLicense:
        return 'permission_manage_license';
      case Permission.manageData:
        return 'permission_manage_data';
      case Permission.manageAttendance:
        return 'permission_manage_attendance';
      case Permission.manageLeaves:
        return 'permission_manage_leaves';
      case Permission.managePenalties:
        return 'permission_manage_penalties';
      case Permission.viewDashboard:
        return 'permission_view_dashboard';
      case Permission.viewCompliance:
        return 'permission_view_compliance';
      case Permission.viewEOSCalculator:
        return 'permission_view_eos';
      case Permission.manageAttendanceSettings:
        return 'permission_manage_attendance_settings';
    }
  }
}
