import 'package:sqflite/sqflite.dart';
import '../core/database/app_database.dart';
import '../models/payroll_record_model.dart';
import '../models/employee_model.dart';

class PayrollStorage {
  final AppDatabase _db = AppDatabase.instance;

  /// بيولّد راتب شهر معيّن لكل الموظفين النشطين (isActive) دفعة واحدة.
  /// لو راتب الموظف في نفس الشهر/السنة اتولّد قبل كده، بيتم تجاهله (مايتكررش)
  /// إلا لو overwrite = true.
  Future<List<PayrollRecord>> generateMonthlyPayroll({
    required List<Employee> employees,
    required int month,
    required int year,
    required double Function(Employee e) calculateTax,
    required double Function(Employee e) calculateInsurance,
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

      final gross = e.basicSalary + e.allowances - e.deductions;
      final tax = calculateTax(e);
      final insurance = calculateInsurance(e);
      final net = gross - tax - insurance;

      final record = PayrollRecord(
        id: '${e.id}_${year}_$month',
        employeeId: e.id,
        employeeName: e.name,
        month: month,
        year: year,
        basicSalary: e.basicSalary,
        allowances: e.allowances,
        deductions: e.deductions,
        taxAmount: tax,
        insuranceAmount: insurance,
        netSalary: net,
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
      orderBy: 'employeeName ASC',
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
