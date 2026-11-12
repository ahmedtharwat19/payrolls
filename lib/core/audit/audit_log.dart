// lib/core/audit/audit_log.dart
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

/// سجل تدقيق بسيط: مين عمل إيه ومتى. ممنوع تسجيل كلمات مرور أو بيانات
/// شخصية (رقم قومي/آيبان...) في [details].
class AuditLog {
  AuditLog._();

  static Future<void> record(
    String action, {
    String? username,
    String? details,
  }) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert('audit_log', {
        'at': DateTime.now().toIso8601String(),
        'username': username,
        'action': action,
        'details': details,
      });
    } catch (e) {
      // السجل ما يوقفش العملية الأصلية أبدًا.
      debugPrint('AuditLog.record failed: $e');
    }
  }

  static Future<List<Map<String, Object?>>> recent({int limit = 200}) async {
    final db = await AppDatabase.instance.database;
    return db.query('audit_log', orderBy: 'id DESC', limit: limit);
  }
}
