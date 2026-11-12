import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../core/audit/audit_log.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/permission.dart';
import '../core/database/app_database.dart';

/// نظام نسخ احتياطي كامل - بيصدّر كل جداول قاعدة البيانات (الموظفين،
/// المرتبات، الدفعات، الحضور...) لملف JSON واحد، والعكس (استرجاع).
///
/// ⚠️ ملحوظة مهمة: النسخة الاحتياطية بتشمل بيانات الشركة (موظفين، مرتبات)
/// لكن **مش** بتشمل بيانات الترخيص أو المستخدمين (عمدًا) - عشان محدش
/// يقدر ياخد نسخة احتياطية من جهاز ويستخدمها كترخيص على جهاز تاني.
/// لو عايز تشمل المستخدمين كمان قولّي.
class BackupService {
  static const _tablesToBackup = [
    'employees',
    'payroll_records',
    'salary_payments',
    'attendance',
  ];

  static const _backupVersion = 1;

  /// بيصدّر البيانات ويسيب المستخدم يختار مكان الحفظ (USB، جوجل درايف
  /// المتزامن محليًا، أي فولدر تاني بره فولدر التطبيق).
  Future<Uri?> exportBackup(AuthService auth) async {
    if (!auth.can(Permission.manageData)) return null;
    final db = await AppDatabase.instance.database;
    final data = <String, dynamic>{};

    for (final table in _tablesToBackup) {
      data[table] = await db.query(table);
    }

    final backup = {
      'backupVersion': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': data,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
    final bytes = utf8.encode(jsonString);

    final fileName =
        'payrolls_backup_${DateTime.now().toIso8601String().split('T').first}.json';

    final Uri? savedPath = await FilePicker.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية',
      fileName: fileName,
      bytes: bytes,
    );

    if (savedPath != null) {
      await AuditLog.record('backup_export',
          username: auth.currentUser?.username);
    }
    return savedPath;
  }

  /// بيسيب المستخدم يختار ملف نسخة احتياطية ويرجّع بياناته للبرنامج.
  /// [merge] = true: يضيف فوق الموجود (لو فيه تعارض ID بيستبدل).
  /// [merge] = false: يمسح الجداول الأربعة الأول قبل ما يرجّع البيانات
  /// (استرجاع كامل من الصفر).
  ///
  /// الملف بيتم فحصه بالكامل قبل أي تعديل، والتنفيذ كله داخل transaction
  /// واحدة: لو أي صف فيه مشكلة بيتم التراجع ومفيش بيانات بتضيع.
  Future<BackupRestoreResult> restoreBackup(AuthService auth,
      {bool merge = true}) async {
    if (!auth.can(Permission.manageData)) {
      return const BackupRestoreResult(
          success: false, message: 'auth_error_forbidden');
    }

    // file_picker v12: pickFile بترجع null لو المستخدم لغى الاختيار.
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null) {
      return const BackupRestoreResult(
          success: false, message: 'backup_restore_cancelled');
    }

    try {
      final Uint8List fileBytes = await picked.readAsBytes();
      final backup = jsonDecode(utf8.decode(fileBytes));
      final tables = _validate(backup);

      final db = await AppDatabase.instance.database;

      // أعمدة كل جدول الحقيقية - أي عمود غريب في الملف يُرفض (حماية من
      // ملف نسخة احتياطية مُعدَّل يدويًا).
      final allowedColumns = <String, Set<String>>{};
      for (final table in _tablesToBackup) {
        final info = await db.rawQuery('PRAGMA table_info($table)');
        allowedColumns[table] = info.map((r) => r['name'] as String).toSet();
      }
      for (final table in _tablesToBackup) {
        final rows = tables[table];
        if (rows == null) continue;
        for (final row in rows) {
          if (!allowedColumns[table]!.containsAll(row.keys)) {
            throw const FormatException('unknown column in backup');
          }
        }
      }

      var restored = 0;
      await db.transaction((txn) async {
        for (final table in _tablesToBackup) {
          final rows = tables[table];
          if (rows == null) continue;
          if (!merge) await txn.delete(table);
          for (final row in rows) {
            await txn.insert(table, row,
                conflictAlgorithm: ConflictAlgorithm.replace);
            restored++;
          }
        }
      });

      await AuditLog.record(
        merge ? 'backup_restore_merge' : 'backup_restore_overwrite',
        username: auth.currentUser?.username,
        details: '$restored rows',
      );
      return const BackupRestoreResult(
          success: true, message: 'backup_restored_ok');
    } catch (_) {
      return const BackupRestoreResult(
          success: false, message: 'backup_restore_failed');
    }
  }

  /// فحص هيكل ملف النسخة الاحتياطية. بيرمي استثناء لو الشكل غلط.
  static Map<String, List<Map<String, dynamic>>> _validate(dynamic backup) {
    if (backup is! Map) throw const FormatException('root must be object');
    final version = backup['backupVersion'];
    if (version is! int || version > _backupVersion) {
      throw const FormatException('unsupported backup version');
    }
    final tables = backup['tables'];
    if (tables is! Map) throw const FormatException('tables missing');

    final out = <String, List<Map<String, dynamic>>>{};
    for (final table in _tablesToBackup) {
      final rows = tables[table];
      if (rows == null) continue;
      if (rows is! List) throw FormatException('$table must be a list');
      out[table] = rows.map((r) {
        if (r is! Map) throw FormatException('bad row in $table');
        return Map<String, dynamic>.from(r);
      }).toList();
    }
    if (out.isEmpty) throw const FormatException('no known tables');
    return out;
  }
}

class BackupRestoreResult {
  final bool success;
  final String message; // مفتاح ترجمة
  const BackupRestoreResult({required this.success, required this.message});
}
