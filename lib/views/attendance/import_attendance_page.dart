// lib/views/attendance/import_attendance_page.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';

class ImportAttendancePage extends StatelessWidget {
  const ImportAttendancePage({super.key});

  Future<void> _importExcel(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) return;
      if(!context.mounted) return;
      final controller = Provider.of<EmployeeController>(context, listen: false);

      for (var row in sheet.rows.skip(1)) {
        final name = row[0]?.value.toString().trim();
        final overtime = double.tryParse(row[1]?.value.toString() ?? '0') ?? 0;
        final lateMinutes = double.tryParse(row[2]?.value.toString() ?? '0') ?? 0;

        controller.updateAttendanceByName(name!, overtime, lateMinutes);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('import_success'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('import_attendance'.tr())),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: Text('import_excel'.tr()),
          onPressed: () => _importExcel(context),
        ),
      ),
    );
  }
}
