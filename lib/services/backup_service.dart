import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
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
  Future<String?> exportBackup() async {
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

    final String? savedPath = await FilePicker.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية',
      fileName: fileName,
      bytes: bytes,
    );

    return savedPath;
  }

  /// بيسيب المستخدم يختار ملف نسخة احتياطية ويرجّع بياناته للبرنامج.
  /// [merge] = true: يضيف فوق الموجود (لو فيه تعارض ID بيستبدل).
  /// [merge] = false: يمسح الجداول الأربعة الأول قبل ما يرجّع البيانات
  /// (استرجاع كامل من الصفر).
/*   Future<BackupRestoreResult> restoreBackup({bool merge = true}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
     // withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return BackupRestoreResult(success: false, message: 'backup_cancelled');
    }

    try {
      final jsonString = utf8.decode(result.files.single.bytes!);
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;
      final tables = backup['tables'] as Map<String, dynamic>;

      final db = await AppDatabase.instance.database;

      await db.transaction((txn) async {
        for (final table in _tablesToBackup) {
          if (!tables.containsKey(table)) continue;

          if (!merge) {
            await txn.delete(table);
          }

          final rows = (tables[table] as List).cast<Map<String, dynamic>>();
          for (final row in rows) {
            await txn.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });

      return BackupRestoreResult(success: true, message: 'backup_restored_ok');
    } catch (e) {
      return BackupRestoreResult(
          success: false, message: 'backup_restore_failed');
    }
  }
 */
Future<BackupRestoreResult> restoreBackup({bool merge = true}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) {
      return BackupRestoreResult(success: false, message: 'backup_cancelled');
    }

    try {
      final file = result.files.single;
      // Asynchronously fetch file bytes using the new API
      final fileBytes = await file.readAsBytes();

      // Decode the JSON safely using the fileBytes variable
      final jsonString = utf8.decode(fileBytes);
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;
      final tables = backup['tables'] as Map<String, dynamic>;

      final db = await AppDatabase.instance.database;

      await db.transaction((txn) async {
        for (final table in _tablesToBackup) {
          if (!tables.containsKey(table)) continue;

          if (!merge) {
            await txn.delete(table);
          }

          final rows = (tables[table] as List).cast<Map<String, dynamic>>();
          for (final row in rows) {
            await txn.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });

      return BackupRestoreResult(success: true, message: 'backup_restored_ok');
    } catch (e) {
      return BackupRestoreResult(
          success: false, message: 'backup_restore_failed');
    }
  }

}

class BackupRestoreResult {
  final bool success;
  final String message; // مفتاح ترجمة
  const BackupRestoreResult({required this.success, required this.message});
}
