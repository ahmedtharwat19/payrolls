// lib/services/compliance_service.dart

import '../database/app_database.dart';

class ComplianceService {
  /// جلب إحصائيات الشهر للضرائب والتأمينات
  Future<Map<String, dynamic>> getMonthlyComplianceStats({
    required int month,
    required int year,
  }) async {
    final db = await AppDatabase.instance.database;

    // جلب كل سجلات المرتبات للشهر ده
    final records = await db.query(
      'payroll_records',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
    );

    double totalGross = 0;
    double totalBasic = 0;
    double totalTax = 0;
    double totalEmployeeInsurance = 0;
    // ملحوظة: حصة الشركة في التأمين مش متخزنة في سجل المرتب،
    // لكننا بنحسبها بنفس المعادلة لو حبينا، أو نكتفي بحصة الموظف للضرائب.

    for (var row in records) {
      totalBasic += (row['basicSalary'] as num).toDouble();
      totalGross += (row['basicSalary'] as num).toDouble() +
          (row['variableSalary'] as num?)!.toDouble();
      totalTax += (row['taxAmount'] as num?)?.toDouble() ?? 0;
      totalEmployeeInsurance +=
          (row['insuranceAmount'] as num?)?.toDouble() ?? 0;
    }

    return {
      'employeeCount': records.length,
      'totalBasic': totalBasic,
      'totalGross': totalGross,
      'totalTax': totalTax,
      'totalEmployeeInsurance': totalEmployeeInsurance,
    };
  }

  /// جلب توزيع الموظفين على الأقسام
  Future<Map<String, int>> getDepartmentDistribution() async {
    final db = await AppDatabase.instance.database;
    final employees = await db.query('employees', where: 'isActive = 1');

    final Map<String, int> distribution = {};
    for (var e in employees) {
      final dept = (e['department'] as String?) ?? 'Unknown';
      distribution[dept] = (distribution[dept] ?? 0) + 1;
    }
    return distribution;
  }

  /// جلب إجمالي الصرف (كاش وبنك) لشهر معين
  Future<Map<String, double>> getPaymentMethodDistribution({
    required int month,
    required int year,
  }) async {
    final db = await AppDatabase.instance.database;

    // بنجيب الموظفين اللي ليهم مرتبات في الشهر ده
    final records = await db.rawQuery('''
      SELECT e.paymentMethod, SUM(pr.netSalary) as total
      FROM payroll_records pr
      JOIN employees e ON pr.employeeId = e.id
      WHERE pr.month = ? AND pr.year = ?
      GROUP BY e.paymentMethod
    ''', [month, year]);

    double cash = 0.0;
    double bank = 0.0;

    for (var row in records) {
      if (row['paymentMethod'] == 'cash') {
        cash = (row['total'] as num?)?.toDouble() ?? 0.0;
      } else if (row['paymentMethod'] == 'bank') {
        bank = (row['total'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return {'cash': cash, 'bank': bank};
  }
}
