import '../core/database/app_database.dart';
import '../models/salary_payment_model.dart';

class PaymentStorage {
  final AppDatabase _db = AppDatabase.instance;

  /// تسجيل دفعة جديدة (ممكن جزئية) لراتب موظف. تقدر تسجل أكتر من دفعة
  /// لنفس الـ payrollRecordId (مثلاً نص الراتب دلوقتي والباقي بعدين).
  Future<void> recordPayment(SalaryPayment payment) async {
    final db = await _db.database;
    await db.insert('salary_payments', payment.toMap());
  }

  Future<List<SalaryPayment>> getPaymentsForRecord(String payrollRecordId) async {
    final db = await _db.database;
    final rows = await db.query(
      'salary_payments',
      where: 'payrollRecordId = ?',
      whereArgs: [payrollRecordId],
      orderBy: 'paymentDate ASC',
    );
    return rows.map((r) => SalaryPayment.fromMap(r)).toList();
  }

  /// إجمالي المدفوع فعليًا لراتب معيّن (مجموع كل الدفعات الجزئية)
  Future<double> getTotalPaid(String payrollRecordId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM salary_payments WHERE payrollRecordId = ?',
      [payrollRecordId],
    );
    return (result.first['total'] as num).toDouble();
  }

  /// المتبقي = صافي الراتب - إجمالي المدفوع. لو رصيد موجب يبقى لسه متبقي فلوس.
  Future<double> getRemainingBalance(String payrollRecordId, double netSalary) async {
    final paid = await getTotalPaid(payrollRecordId);
    return netSalary - paid;
  }

  /// تقرير: إجمالي الكاش والبنك المدفوعين في شهر/سنة معيّنة - مفيد
  /// لتقرير "صرف المرتبات" (كام كاش وكام حوّل بنك الشهر ده).
  Future<Map<String, double>> getMonthlyPaymentTotals(int month, int year) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(sp.cashAmount), 0) as totalCash,
        COALESCE(SUM(sp.bankAmount), 0) as totalBank
      FROM salary_payments sp
      INNER JOIN payroll_records pr ON pr.id = sp.payrollRecordId
      WHERE pr.month = ? AND pr.year = ?
    ''', [month, year]);

    final row = result.first;
    return {
      'cash': (row['totalCash'] as num).toDouble(),
      'bank': (row['totalBank'] as num).toDouble(),
    };
  }

  Future<void> deletePayment(String id) async {
    final db = await _db.database;
    await db.delete('salary_payments', where: 'id = ?', whereArgs: [id]);
  }
}
