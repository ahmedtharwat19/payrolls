// lib/core/settings/attendance_settings.dart
import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';

class AttendanceSettings {
  final String workStartTime; // "HH:mm" مثال "09:00"
  final String workEndTime; // "HH:mm" مثال "17:00"
  final int graceMinutes; // سماحية التأخير بالدقائق
  final double overtimeRate; // معدل الإضافي (1.5 = مرة ونص)
  final Set<int> weekendDays; // أيام العطلة (1=الاثنين...7=الأحد)

  const AttendanceSettings({
    this.workStartTime = '09:00',
    this.workEndTime = '17:00',
    this.graceMinutes = 15,
    this.overtimeRate = 1.5,
    this.weekendDays = const {5, 6}, // الجمعة والسبت
  });

  DateTime getWorkStart(DateTime day) {
    final parts = workStartTime.split(':');
    return DateTime(
        day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  DateTime getWorkEnd(DateTime day) {
    final parts = workEndTime.split(':');
    return DateTime(
        day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  bool isWeekend(DateTime day) => weekendDays.contains(day.weekday);

  /// إجمالي دقائق العمل في اليوم
  int get workMinutes => getWorkEnd(DateTime.now())
      .difference(getWorkStart(DateTime.now()))
      .inMinutes;

  AttendanceSettings copyWith({
    String? workStartTime,
    String? workEndTime,
    int? graceMinutes,
    double? overtimeRate,
    Set<int>? weekendDays,
  }) {
    return AttendanceSettings(
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      overtimeRate: overtimeRate ?? this.overtimeRate,
      weekendDays: weekendDays ?? this.weekendDays,
    );
  }
}

class AttendanceSettingsService {
  static const String _prefix = 'attendance_';

  /// تحميل الإعدادات من قاعدة البيانات، أو القيم الافتراضية لو مفيش.
  static Future<AttendanceSettings> load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'app_meta',
      where: 'key LIKE ?',
      whereArgs: ['$_prefix%'],
    );
    final map = <String, String>{};
    for (var r in rows) {
      final key = (r['key'] as String).substring(_prefix.length);
      map[key] = r['value'] as String;
    }

    return AttendanceSettings(
      workStartTime: map['work_start'] ?? '09:00',
      workEndTime: map['work_end'] ?? '17:00',
      graceMinutes: int.tryParse(map['grace_minutes'] ?? '15') ?? 15,
      overtimeRate: double.tryParse(map['overtime_rate'] ?? '1.5') ?? 1.5,
      weekendDays: (map['weekend_days'] ?? '5,6')
          .split(',')
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toSet(),
    );
  }

  static Future<void> save(AttendanceSettings s) async {
    final db = await AppDatabase.instance.database;
    final data = {
      'work_start': s.workStartTime,
      'work_end': s.workEndTime,
      'grace_minutes': s.graceMinutes.toString(),
      'overtime_rate': s.overtimeRate.toString(),
      'weekend_days': s.weekendDays.join(','),
    };
    for (var e in data.entries) {
      await db.insert(
        'app_meta',
        {'key': '$_prefix${e.key}', 'value': e.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
