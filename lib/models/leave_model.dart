// lib/models/leave_model.dart

class LeaveRequest {
  final String id;
  final String employeeId;
  final String leaveType; // annual, sick, unpaid, emergency, maternity
  final DateTime startDate;
  final DateTime endDate;
  final int daysCount;
  final String status; // pending, approved, rejected
  final String? reason;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    this.status = 'pending',
    this.reason,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeId': employeeId,
        'leaveType': leaveType,
        'startDate': startDate.toIso8601String().split('T').first,
        'endDate': endDate.toIso8601String().split('T').first,
        'daysCount': daysCount,
        'status': status,
        'reason': reason,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory LeaveRequest.fromMap(Map<String, dynamic> map) => LeaveRequest(
        id: map['id'] as String,
        employeeId: map['employeeId'] as String,
        leaveType: map['leaveType'] as String,
        startDate: DateTime.parse(map['startDate'] as String),
        endDate: DateTime.parse(map['endDate'] as String),
        daysCount: map['daysCount'] as int,
        status: map['status'] as String? ?? 'pending',
        reason: map['reason'] as String?,
        approvedBy: map['approvedBy'] as String?,
        approvedAt: map['approvedAt'] != null
            ? DateTime.tryParse(map['approvedAt'] as String)
            : null,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}

class LeaveBalance {
  final String id;
  final String employeeId;
  final int year;
  final String leaveType;
  final int totalDays;
  final int usedDays;

  LeaveBalance({
    required this.id,
    required this.employeeId,
    required this.year,
    required this.leaveType,
    required this.totalDays,
    this.usedDays = 0,
  });

  int get remainingDays => totalDays - usedDays;

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeId': employeeId,
        'year': year,
        'leaveType': leaveType,
        'totalDays': totalDays,
        'usedDays': usedDays,
      };

  factory LeaveBalance.fromMap(Map<String, dynamic> map) => LeaveBalance(
        id: map['id'] as String,
        employeeId: map['employeeId'] as String,
        year: map['year'] as int,
        leaveType: map['leaveType'] as String,
        totalDays: map['totalDays'] as int,
        usedDays: map['usedDays'] as int? ?? 0,
      );
}
