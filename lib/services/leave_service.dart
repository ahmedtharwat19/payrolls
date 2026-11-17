// lib/services/leave_service.dart (النسخة المحدثة)

import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/leave_model.dart';

class LeaveService {
  final _uuid = const Uuid();

  Future<void> initializeLeaveBalance({
    required String employeeId,
    required int year,
    int annualDays = 21,
  }) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query(
      'leave_balances',
      where: 'employeeId = ? AND year = ? AND leaveType = ?',
      whereArgs: [employeeId, year, 'annual'],
    );

    if (existing.isEmpty) {
      final balance = LeaveBalance(
        id: _uuid.v4(),
        employeeId: employeeId,
        year: year,
        leaveType: 'annual',
        totalDays: annualDays,
        usedDays: 0,
      );
      await db.insert('leave_balances', balance.toMap());
    }
  }

  Future<LeaveRequest> requestLeave({
    required String employeeId,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final daysCount = endDate.difference(startDate).inDays + 1;
    final request = LeaveRequest(
      id: _uuid.v4(),
      employeeId: employeeId,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      daysCount: daysCount,
      status: 'pending',
      reason: reason,
      createdAt: DateTime.now(),
    );

    final db = await AppDatabase.instance.database;
    await db.insert('leave_requests', request.toMap());
    return request;
  }

  Future<bool> approveLeave({
    required String requestId,
    required String approverUsername,
  }) async {
    final db = await AppDatabase.instance.database;
    final rows = await db
        .query('leave_requests', where: 'id = ?', whereArgs: [requestId]);
    if (rows.isEmpty) return false;

    final request = LeaveRequest.fromMap(rows.first);
    if (request.status != 'pending') return false;

    if (request.leaveType == 'annual' || request.leaveType == 'sick') {
      final year = request.startDate.year;
      final balanceRows = await db.query(
        'leave_balances',
        where: 'employeeId = ? AND year = ? AND leaveType = ?',
        whereArgs: [request.employeeId, year, request.leaveType],
      );

      if (balanceRows.isNotEmpty) {
        final balance = LeaveBalance.fromMap(balanceRows.first);
        if (balance.remainingDays < request.daysCount) return false;

        await db.update(
          'leave_balances',
          {'usedDays': balance.usedDays + request.daysCount},
          where: 'id = ?',
          whereArgs: [balance.id],
        );
      }
    }

    await db.update(
      'leave_requests',
      {
        'status': 'approved',
        'approvedBy': approverUsername,
        'approvedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [requestId],
    );
    return true;
  }

  Future<void> rejectLeave({
    required String requestId,
    required String approverUsername,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'leave_requests',
      {
        'status': 'rejected',
        'approvedBy': approverUsername,
        'approvedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }

  Future<int> getRemainingLeaveDays({
    required String employeeId,
    required int year,
  }) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'leave_balances',
      where: 'employeeId = ? AND year = ? AND leaveType = ?',
      whereArgs: [employeeId, year, 'annual'],
    );
    if (rows.isEmpty) return 0;
    return LeaveBalance.fromMap(rows.first).remainingDays;
  }

  /// ✅ دالة جديدة: حساب أيام الإجازة بدون راتب في شهر معين.
  Future<int> getUnpaidLeaveDaysInMonth({
    required String employeeId,
    required int month,
    required int year,
  }) async {
    final db = await AppDatabase.instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final prefix = '$year-$monthStr';

    final rows = await db.query(
      'leave_requests',
      where:
          "employeeId = ? AND leaveType = 'unpaid' AND status = 'approved' AND startDate LIKE ?",
      whereArgs: [employeeId, '$prefix%'],
    );

    int totalDays = 0;
    for (var row in rows) {
      totalDays += LeaveRequest.fromMap(row).daysCount;
    }
    return totalDays;
  }
}
