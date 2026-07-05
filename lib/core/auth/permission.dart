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
  /// اسم عرض بالعربي (تقدر تربطه بـ easy_localization بدل الكده لو حبيت)
  String get labelAr {
    switch (this) {
      case Permission.viewEmployees:
        return 'عرض الموظفين';
      case Permission.addEmployee:
        return 'إضافة موظف';
      case Permission.editEmployee:
        return 'تعديل موظف';
      case Permission.deleteEmployee:
        return 'حذف موظف';
      case Permission.viewPayroll:
        return 'عرض الرواتب';
      case Permission.runPayroll:
        return 'تشغيل دورة الرواتب';
      case Permission.editSalary:
        return 'تعديل الراتب';
      case Permission.viewReports:
        return 'عرض التقارير';
      case Permission.exportReports:
        return 'تصدير التقارير';
      case Permission.manageUsers:
        return 'إدارة المستخدمين';
      case Permission.manageRoles:
        return 'إدارة الأدوار';
      case Permission.manageSettings:
        return 'إعدادات النظام';
      case Permission.manageLicense:
        return 'إدارة الترخيص';
    }
  }
}
