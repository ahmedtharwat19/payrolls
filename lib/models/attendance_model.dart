// lib/models/attendance_model.dart

class Attendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final double overtimeHours; // ساعات الاوفر تايم
  final double lateMinutes;   // دقائق التأخير
  final String notes;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.overtimeHours = 0,
    this.lateMinutes = 0,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': date.toIso8601String(),
      'overtimeHours': overtimeHours,
      'lateMinutes': lateMinutes,
      'notes': notes,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as String,
      employeeId: map['employeeId'] as String,
      employeeName: map['employeeName'] as String,
      date: DateTime.parse(map['date'] as String),
      overtimeHours: (map['overtimeHours'] as num?)?.toDouble() ?? 0,
      lateMinutes: (map['lateMinutes'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
    );
  }

  // حساب ساعات العمل الفعلية
  double get effectiveHours => 8 - (lateMinutes / 60) + overtimeHours;

  // حساب الاوفر تايم بالجنيه (إذا كان لديك سعر الساعة)
  double calculateOvertimePay(double hourlyRate) {
    return overtimeHours * hourlyRate * 1.5; // 150% من السعر العادي
  }

  // حساب خصم التأخير (إذا كان لديك قيمة الخصم لكل دقيقة)
  double calculateLatePenalty(double penaltyPerMinute) {
    return lateMinutes * penaltyPerMinute;
  }
}