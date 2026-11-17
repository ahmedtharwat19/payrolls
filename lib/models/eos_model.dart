// lib/models/eos_model.dart

class EOSSettlement {
  final String id;
  final String employeeId;
  final DateTime endDate;
  final double yearsOfService;
  final double lastBasicSalary;
  final double settlementAmount;
  final double leaveBalanceAmount;
  final double totalAmount;
  final String paymentStatus; // pending, paid
  final DateTime? paidDate;
  final String? notes;
  final DateTime createdAt;

  EOSSettlement({
    required this.id,
    required this.employeeId,
    required this.endDate,
    required this.yearsOfService,
    required this.lastBasicSalary,
    required this.settlementAmount,
    this.leaveBalanceAmount = 0,
    required this.totalAmount,
    this.paymentStatus = 'pending',
    this.paidDate,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeId': employeeId,
        'endDate': endDate.toIso8601String(),
        'yearsOfService': yearsOfService,
        'lastBasicSalary': lastBasicSalary,
        'settlementAmount': settlementAmount,
        'leaveBalanceAmount': leaveBalanceAmount,
        'totalAmount': totalAmount,
        'paymentStatus': paymentStatus,
        'paidDate': paidDate?.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory EOSSettlement.fromMap(Map<String, dynamic> map) => EOSSettlement(
        id: map['id'] as String,
        employeeId: map['employeeId'] as String,
        endDate: DateTime.parse(map['endDate'] as String),
        yearsOfService: (map['yearsOfService'] as num).toDouble(),
        lastBasicSalary: (map['lastBasicSalary'] as num).toDouble(),
        settlementAmount: (map['settlementAmount'] as num).toDouble(),
        leaveBalanceAmount:
            (map['leaveBalanceAmount'] as num?)?.toDouble() ?? 0,
        totalAmount: (map['totalAmount'] as num).toDouble(),
        paymentStatus: map['paymentStatus'] as String? ?? 'pending',
        paidDate: map['paidDate'] != null
            ? DateTime.tryParse(map['paidDate'] as String)
            : null,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
