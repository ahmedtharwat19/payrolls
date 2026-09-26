/* import '../core/database/app_database.dart';
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
 */ /* 
import 'package:sqflite/sqflite.dart';
import '../core/database/app_database.dart';
import '../models/payroll_record_model.dart';
import '../models/employee_model.dart';
import '../services/tax_service.dart';
import '../services/payroll_calculator.dart';

class PayrollStorage {
  final AppDatabase _db = AppDatabase.instance;

  /// بيولّد راتب شهر معيّن لكل الموظفين النشطين (isActive) دفعة واحدة.
  /// لو راتب الموظف في نفس الشهر/السنة اتولّد قبل كده، بيتم تجاهله (مايتكررش)
  /// إلا لو overwrite = true.
  ///
  /// بيستخدم [PayrollCalculator] عشان لو نوع راتب الموظف "net"، يتصعّد
  /// الأساسي تلقائيًا بحيث الشركة تتحمل الضريبة والتأمين، والموظف يوصله
  /// نفس الراتب المتفق عليه بالظبط.
  Future<List<PayrollRecord>> generateMonthlyPayroll({
    required List<Employee> employees,
    required int month,
    required int year,
    required TaxService taxService,
    bool overwrite = false,
  }) async {
    final db = await _db.database;
    final results = <PayrollRecord>[];

    for (final e in employees.where((e) => e.isActive)) {
      final existing = await db.query(
        'payroll_records',
        where: 'employeeId = ? AND month = ? AND year = ?',
        whereArgs: [e.id, month, year],
      );

      if (existing.isNotEmpty && !overwrite) {
        results.add(PayrollRecord.fromMap(existing.first));
        continue;
      }

      final calc = PayrollCalculator.calculate(
        basicSalary: e.basicSalary,
        variableSalary: e.variableSalary,
        allowances: e.allowances,
        deductions: e.deductions,
        salaryType: e.salaryType,
        taxService: taxService,
      );

      final record = PayrollRecord(
        id: '${e.id}_${year}_$month',
        employeeId: e.id,
        employeeNameAr: e.nameAr,
        employeeNameEn: e.nameEn,
        month: month,
        year: year,
        basicSalary: calc.basicSalary,
        variableSalary: calc.variableSalary,
        allowances: calc.allowances,
        deductions: calc.deductions,
        taxAmount: calc.taxAmount,
        insuranceAmount: calc.insuranceAmount,
        netSalary: calc.netSalary,
        generatedAt: DateTime.now(),
      );

      await db.insert(
        'payroll_records',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      results.add(record);
    }

    return results;
  }

  Future<List<PayrollRecord>> getByMonth(int month, int year) async {
    final db = await _db.database;
    final rows = await db.query(
      'payroll_records',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
      orderBy: 'employeeNameAr ASC',
    );
    return rows.map((r) => PayrollRecord.fromMap(r)).toList();
  }

  Future<List<PayrollRecord>> getByEmployee(String employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'payroll_records',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
      orderBy: 'year DESC, month DESC',
    );
    return rows.map((r) => PayrollRecord.fromMap(r)).toList();
  }

  Future<void> deleteRecord(String id) async {
    final db = await _db.database;
    await db.delete('payroll_records', where: 'id = ?', whereArgs: [id]);
  }
}
 */
import 'package:sqflite/sqflite.dart';
import '../core/database/app_database.dart';
import '../models/salary_payment_model.dart';
import '../models/payroll_record_model.dart';
import '../models/employee_model.dart';
import '../services/tax_service.dart';
import '../services/payroll_calculator.dart';

class PaymentStorage {
  final AppDatabase _db = AppDatabase.instance;

  /// تسجيل دفعة جديدة (ممكن جزئية) لراتب موظف. تقدر تسجل أكتر من دفعة
  /// لنفس الـ payrollRecordId (مثلاً نص الراتب دلوقتي والباقي بعدين).
  Future<void> recordPayment(SalaryPayment payment) async {
    final db = await _db.database;
    await db.insert('salary_payments', payment.toMap());
  }

  Future<List<SalaryPayment>> getPaymentsForRecord(
      String payrollRecordId) async {
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
      'SELECT COALESCE(SUM(cashAmount + bankAmount), 0) as total FROM salary_payments WHERE payrollRecordId = ?',
      [payrollRecordId],
    );
    return (result.first['total'] as num).toDouble();
  }

  /// المتبقي = صافي الراتب - إجمالي المدفوع. لو رصيد موجب يبقى لسه متبقي فلوس.
  Future<double> getRemainingBalance(
      String payrollRecordId, double netSalary) async {
    final paid = await getTotalPaid(payrollRecordId);
    return netSalary - paid;
  }

  /// تقرير: إجمالي الكاش والبنك المدفوعين في شهر/سنة معيّنة - مفيد
  /// لتقرير "صرف المرتبات" (كام كاش وكام حوّل بنك الشهر ده).
  Future<Map<String, double>> getMonthlyPaymentTotals(
      int month, int year) async {
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

class PayrollStorage {
  final AppDatabase _db = AppDatabase.instance;

  /// بيولّد راتب شهر معيّن لكل الموظفين النشطين (isActive) دفعة واحدة.
  /// لو راتب الموظف في نفس الشهر/السنة اتولّد قبل كده، بيتم تجاهله (مايتكررش)
  /// إلا لو overwrite = true.
  ///
  /// بيستخدم [PayrollCalculator] عشان لو نوع راتب الموظف "net"، يتصعّد
  /// الأساسي تلقائيًا بحيث الشركة تتحمل الضريبة والتأمين، والموظف يوصله
  /// نفس الراتب المتفق عليه بالظبط.
  Future<List<PayrollRecord>> generateMonthlyPayroll({
    required List<Employee> employees,
    required int month,
    required int year,
    required TaxService taxService,
    bool overwrite = false,
  }) async {
    final db = await _db.database;
    final results = <PayrollRecord>[];

    for (final e in employees.where((e) => e.isActive)) {
      final existing = await db.query(
        'payroll_records',
        where: 'employeeId = ? AND month = ? AND year = ?',
        whereArgs: [e.id, month, year],
      );

      if (existing.isNotEmpty && !overwrite) {
        results.add(PayrollRecord.fromMap(existing.first));
        continue;
      }

      final calc = PayrollCalculator.calculate(
        basicSalary: e.basicSalary,
        variableSalary: e.variableSalary,
        allowances: e.allowances,
        deductions: e.deductions,
        salaryType: e.salaryType,
        taxService: taxService,
      );

      final record = PayrollRecord(
        id: '${e.id}_${year}_$month',
        employeeId: e.id,
        employeeNameAr: e.nameAr,
        employeeNameEn: e.nameEn,
        month: month,
        year: year,
        basicSalary: calc.basicSalary,
        variableSalary: calc.variableSalary,
        allowances: calc.allowances,
        deductions: calc.deductions,
        taxAmount: calc.taxAmount,
        insuranceAmount: calc.insuranceAmount,
        netSalary: calc.netSalary,
        generatedAt: DateTime.now(),
      );

      await db.insert(
        'payroll_records',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      results.add(record);
    }

    return results;
  }

  Future<List<PayrollRecord>> getByMonth(int month, int year) async {
    final db = await _db.database;
    final rows = await db.query(
      'payroll_records',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
      orderBy: 'employeeNameAr ASC',
    );
    return rows.map((r) => PayrollRecord.fromMap(r)).toList();
  }

  Future<List<PayrollRecord>> getByEmployee(String employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'payroll_records',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
      orderBy: 'year DESC, month DESC',
    );
    return rows.map((r) => PayrollRecord.fromMap(r)).toList();
  }

  Future<void> deleteRecord(String id) async {
    final db = await _db.database;
    await db.delete('payroll_records', where: 'id = ?', whereArgs: [id]);
  }
}
