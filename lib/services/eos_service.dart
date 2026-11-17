// lib/services/eos_service.dart

import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/eos_model.dart';
import '../models/employee_model.dart';

class EOSService {
  final _uuid = const Uuid();

  /// حساب مكافأة نهاية الخدمة.
  /// القاعدة (قانون العمل المصري 12 لسنة 2003):
  /// - أول 5 سنين: 21 يوم أجر أساسي عن كل سنة (شهر ونصف).
  /// - كل سنة بعد الـ 5: 30 يوم أجر أساسي (شهر كامل).
  /// - في حالة الاستقالة، المكافأة تُحسب بالتناسب (نصف المكافأة لو الخدمة < 5 سنين).
  double calculateSettlementAmount({
    required double lastBasicSalary,
    required double yearsOfService,
    required bool isResignation,
  }) {
    if (yearsOfService <= 0) return 0.0;

    // متوسط أجر اليوم
    final dailyWage = lastBasicSalary / 30;

    // حساب أساسي
    double settlement = 0.0;
    if (yearsOfService <= 5) {
      settlement = yearsOfService * 21 * dailyWage;
    } else {
      settlement =
          (5 * 21 * dailyWage) + ((yearsOfService - 5) * 30 * dailyWage);
    }

    // لو استقالة (وخدمة أقل من 5 سنين): المكافأة تكون ثلث المبلغ
    if (isResignation && yearsOfService < 5) {
      settlement = settlement / 3;
    } else if (isResignation && yearsOfService >= 5 && yearsOfService < 10) {
      settlement = settlement * (2 / 3);
    }

    return settlement;
  }

  /// حساب رصيد الإجازات المتبقي كمبلغ مالي (تضاف على مكافأة نهاية الخدمة).
  double calculateLeaveBalanceAmount({
    required int remainingLeaveDays,
    required double lastBasicSalary,
  }) {
    final dailyWage = lastBasicSalary / 30;
    return remainingLeaveDays * dailyWage;
  }

  /// إنشاء واعتماد تسوية نهاية الخدمة لموظف.
  Future<EOSSettlement> createSettlement({
    required Employee employee,
    required DateTime endDate,
    required double leaveBalanceAmount,
    required bool isResignation,
    String? notes,
  }) async {
    final db = await AppDatabase.instance.database;
    final startDate = DateTime.tryParse(employee.hireDate) ?? DateTime.now();

    // حساب سنوات الخدمة بالتفصيل (مع كسور السنة)
    final difference = endDate.difference(startDate).inDays;
    final yearsOfService = difference / 365.25;

    // حساب مكافأة نهاية الخدمة
    final settlementAmount = calculateSettlementAmount(
      lastBasicSalary: employee.basicSalary,
      yearsOfService: yearsOfService,
      isResignation: isResignation,
    );

    final totalAmount = settlementAmount + leaveBalanceAmount;

    final settlement = EOSSettlement(
      id: _uuid.v4(),
      employeeId: employee.id,
      endDate: endDate,
      yearsOfService: yearsOfService,
      lastBasicSalary: employee.basicSalary,
      settlementAmount: settlementAmount,
      leaveBalanceAmount: leaveBalanceAmount,
      totalAmount: totalAmount,
      paymentStatus: 'pending',
      notes: notes,
      createdAt: DateTime.now(),
    );

    await db.insert('eos_settlements', settlement.toMap());
    return settlement;
  }

  /// جلب كل تسويات نهاية الخدمة لموظف معين.
  Future<List<EOSSettlement>> getSettlementsForEmployee(
      String employeeId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'eos_settlements',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
      orderBy: 'endDate DESC',
    );
    return rows.map(EOSSettlement.fromMap).toList();
  }

  /// تحديث حالة الدفع.
  Future<void> markAsPaid(String settlementId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'eos_settlements',
      {
        'paymentStatus': 'paid',
        'paidDate': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [settlementId],
    );
  }
}
