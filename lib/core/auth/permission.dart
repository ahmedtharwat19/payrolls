/// كل صلاحية في النظام. أضف أي صلاحية جديدة هنا فقط، والباقي هياخدها أوتوماتيك.
enum Permission {
  viewEmployees,
  addEmployee,
  editEmployee,
  deleteEmployee,
  viewPayroll,
  runPayroll,
  editSalary,
  viewReports,
  exportReports,
  manageUsers,
  manageRoles,
  manageSettings,
  manageLicense,
}

extension PermissionLabel on Permission {
  /// مفتاح ترجمة (easy_localization) - استخدمه كده: permission.labelKey.tr()
  /// المفاتيح دي موجودة في ar.json/en.json (بعضها بيعيد استخدام مفاتيح
  /// موجودة أصلاً في المشروع زي add_employee/edit_employee).
  String get labelKey {
    switch (this) {
      case Permission.viewEmployees:
        return 'permission_view_employees';
      case Permission.addEmployee:
        return 'add_employee'; // مفتاح موجود بالفعل في المشروع
      case Permission.editEmployee:
        return 'edit_employee'; // مفتاح موجود بالفعل في المشروع
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
    }
  }
}
