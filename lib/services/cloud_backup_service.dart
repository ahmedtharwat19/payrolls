// lib/services/cloud_backup_service.dart

import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../database/app_database.dart';

class CloudBackupService {
  /// إنشاء نسخة احتياطية مضغوطة وتصديرها لمجلد يختاره المستخدم.
  static Future<String?> exportEncryptedBackup() async {
    try {
      final db = await AppDatabase.instance.database;
      
      // بنعمل Checkpoint عشان نضمن إن كل البيانات متسجلة في الملف
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');

      // تحديد مسار الداتابيز الحالي
      final dbPath = p.join(
        p.dirname(Platform.resolvedExecutable),
        AppDatabase.instance.getDbFileName(), // هنضيف الدالة دي في AppDatabase
      );

      final dbFile = File(dbPath);
      if (!await dbFile.exists()) throw Exception('ملف قاعدة البيانات غير موجود');

      // اختيار مجلد الحفظ
      final outputPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'اختر مجلد النسخ الاحتياطي (يفضل OneDrive)',
      );
      if (outputPath == null) return null; // المستخدم لغى

      // ضغط الملف
      final timestamp = DateTime.now().toIso8601String().split('T').first;
      final zipPath = p.join(outputPath, 'payroll_backup_$timestamp.zip');
      
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addFile(dbFile, 'database.db');
      encoder.close();

      return zipPath;
    } catch (e) {
      print('Backup Error: $e');
      return null;
    }
  }

  /// استعادة نسخة احتياطية من ملف ZIP.
  static Future<bool> restoreEncryptedBackup() async {
    try {
      // اختيار الملف المضغوط
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null) return false;

      final bytes = await result.readAsBytes();
      
      final db = await AppDatabase.instance.database;
      await db.close(); // لازم نقفل الداتابيز قبل الاستبدال

      // فك الضغط والكتابة فوق الملف الأصلي
      final archive = ZipDecoder().decodeBytes(bytes);
      final dbPath = p.join(
        p.dirname(Platform.resolvedExecutable),
        AppDatabase.instance.getDbFileName(),
      );

      for (final file in archive) {
        if (file.name == 'database.db') {
          final data = file.content as List<int>;
          await File(dbPath).writeAsBytes(data);
          break;
        }
      }

      return true;
    } catch (e) {
      print('Restore Error: $e');
      return false;
    }
  }
}