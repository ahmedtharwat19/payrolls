// lib/services/penalty_service.dart

import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/penalty_model.dart';

class PenaltyService {
  final _uuid = const Uuid();

  /// إضافة جزاء جديد لموظف.
  Future<Penalty> addPenalty({
    required String employeeId,
    required String type,
    required double amount,
    String? reason,
    int? appliedMonth,
    int? appliedYear,
  }) async {
    final penalty = Penalty(
      id: _uuid.v4(),
      employeeId: employeeId,
      date: DateTime.now().toIso8601String().split('T').first,
      type: type,
      amount: amount,
      reason: reason,
      appliedToPayrollMonth: appliedMonth,
      appliedToPayrollYear: appliedYear,
      createdAt: DateTime.now(),
    );

    final db = await AppDatabase.instance.database;
    await db.insert('penalties', penalty.toMap());
    return penalty;
  }

  /// جلب كل جزاءات موظف.
  Future<List<Penalty>> getPenaltiesForEmployee(String employeeId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'penalties',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
      orderBy: 'date DESC',
    );
    return rows.map(Penalty.fromMap).toList();
  }

  /// حساب إجمالي الجزاءات المالية المطبقة على شهر وسنة معينين.
  Future<double> getMonthlyPenaltiesTotal({
    required String employeeId,
    required int month,
    required int year,
  }) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'penalties',
      where:
          'employeeId = ? AND appliedToPayrollMonth = ? AND appliedToPayrollYear = ?',
      whereArgs: [employeeId, month, year],
    );

    double total = 0.0;
    for (var row in rows) {
      final p = Penalty.fromMap(row);
      if (p.type == 'financial') {
        total += p.amount;
      }
    }
    return total;
  }
}
