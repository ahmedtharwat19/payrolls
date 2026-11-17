// lib/models/attendance_record_model.dart

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String date; // YYYY-MM-DD
  final String? checkInTime; // HH:mm
  final String? checkOutTime; // HH:mm
  final int lateMinutes;
  final int overtimeMinutes;
  final String status; // present, absent, leave, holiday
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.lateMinutes = 0,
    this.overtimeMinutes = 0,
    this.status = 'present',
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeId': employeeId,
        'date': date,
        'checkInTime': checkInTime,
        'checkOutTime': checkOutTime,
        'lateMinutes': lateMinutes,
        'overtimeMinutes': overtimeMinutes,
        'status': status,
        'notes': notes,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) =>
      AttendanceRecord(
        id: map['id'] as String,
        employeeId: map['employeeId'] as String,
        date: map['date'] as String,
        checkInTime: map['checkInTime'] as String?,
        checkOutTime: map['checkOutTime'] as String?,
        lateMinutes: map['lateMinutes'] as int? ?? 0,
        overtimeMinutes: map['overtimeMinutes'] as int? ?? 0,
        status: map['status'] as String? ?? 'present',
        notes: map['notes'] as String?,
      );
}
