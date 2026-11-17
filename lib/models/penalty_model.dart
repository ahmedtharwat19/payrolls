// lib/models/penalty_model.dart

class Penalty {
  final String id;
  final String employeeId;
  final String date;
  final String type; // 'financial', 'warning', 'suspension'
  final double amount;
  final String? reason;
  final int? appliedToPayrollMonth;
  final int? appliedToPayrollYear;
  final DateTime createdAt;

  Penalty({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.type,
    required this.amount,
    this.reason,
    this.appliedToPayrollMonth,
    this.appliedToPayrollYear,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeId': employeeId,
        'date': date,
        'type': type,
        'amount': amount,
        'reason': reason,
        'appliedToPayrollMonth': appliedToPayrollMonth,
        'appliedToPayrollYear': appliedToPayrollYear,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Penalty.fromMap(Map<String, dynamic> map) => Penalty(
        id: map['id'] as String,
        employeeId: map['employeeId'] as String,
        date: map['date'] as String,
        type: map['type'] as String,
        amount: (map['amount'] as num).toDouble(),
        reason: map['reason'] as String?,
        appliedToPayrollMonth: map['appliedToPayrollMonth'] as int?,
        appliedToPayrollYear: map['appliedToPayrollYear'] as int?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
