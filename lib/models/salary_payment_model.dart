/// دفعة صرف فعلية لراتب موظف - ممكن يكون فيه أكتر من دفعة لنفس الراتب
/// (مثلاً: نص الراتب الأول، والباقي بعدين)، وكل دفعة ممكن تتقسم كاش/بنك.
class SalaryPayment {
  final String id;
  final String payrollRecordId;
  final double amount; // = cashAmount + bankAmount (بيتحسب مش بيتدخل يدوي)
  final double cashAmount;
  final double bankAmount;
  final DateTime paymentDate;
  final String notes;

  const SalaryPayment({
    required this.id,
    required this.payrollRecordId,
    required this.cashAmount,
    required this.bankAmount,
    required this.paymentDate,
    this.notes = '',
  }) : amount = cashAmount + bankAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'payrollRecordId': payrollRecordId,
        'amount': amount,
        'cashAmount': cashAmount,
        'bankAmount': bankAmount,
        'paymentDate': paymentDate.toIso8601String(),
        'notes': notes,
      };

  factory SalaryPayment.fromMap(Map<String, dynamic> map) => SalaryPayment(
        id: map['id'] as String,
        payrollRecordId: map['payrollRecordId'] as String,
        cashAmount: (map['cashAmount'] as num).toDouble(),
        bankAmount: (map['bankAmount'] as num).toDouble(),
        paymentDate: DateTime.parse(map['paymentDate'] as String),
        notes: map['notes'] as String? ?? '',
      );
}
