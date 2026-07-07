/// راتب موظف واحد في شهر واحد - بيتولّد مرة واحدة لكل موظف/شهر (فريد).
class PayrollRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final int month; // 1-12
  final int year;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final double taxAmount;
  final double insuranceAmount;
  final double netSalary;
  final DateTime generatedAt;
  final String notes;

  const PayrollRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.year,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.taxAmount,
    required this.insuranceAmount,
    required this.netSalary,
    required this.generatedAt,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'month': month,
        'year': year,
        'basicSalary': basicSalary,
        'allowances': allowances,
        'deductions': deductions,
        'taxAmount': taxAmount,
        'insuranceAmount': insuranceAmount,
        'netSalary': netSalary,
        'generatedAt': generatedAt.toIso8601String(),
        'notes': notes,
      };

  factory PayrollRecord.fromMap(Map<String, dynamic> map) => PayrollRecord(
        id: map['id'] as String,
        employeeId: map['employeeId'] as String,
        employeeName: map['employeeName'] as String,
        month: map['month'] as int,
        year: map['year'] as int,
        basicSalary: (map['basicSalary'] as num).toDouble(),
        allowances: (map['allowances'] as num).toDouble(),
        deductions: (map['deductions'] as num).toDouble(),
        taxAmount: (map['taxAmount'] as num).toDouble(),
        insuranceAmount: (map['insuranceAmount'] as num).toDouble(),
        netSalary: (map['netSalary'] as num).toDouble(),
        generatedAt: DateTime.parse(map['generatedAt'] as String),
        notes: map['notes'] as String? ?? '',
      );
}
