// lib/services/bulk_import_service.dart

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../database/employee_storage.dart';
import '../models/employee_model.dart';


class BulkImportService {
  final _employeeStorage = EmployeeStorage();

  Future<BulkImportResult> importFromExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) {
        return BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: true,
          messageKey: 'import_cancelled',
        );
      }

      final file = result.files.single;
      
      // Asynchronously fetch file bytes using the new API
      final fileBytes = await file.readAsBytes();

      // Safe decoding using the fetched bytes
      final excel = Excel.decodeBytes(fileBytes);
      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null || sheet.maxRows < 2) {
        return BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: false,
          messageKey: 'import_error_no_data',
        );
      }

      int imported = 0;
      final errors = <ImportRowError>[];

      for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        final displayRow = rowIndex + 1;

        // تجاهل الصفوف الفارغة
        if (row.every((cell) =>
            cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        try {
          // دالة قراءة الخلية
          String cell(int i) {
            if (i >= row.length) return '';
            final value = row[i]?.value;
            if (value == null) return '';
            return value.toString().trim();
          }

          // دالة قراءة الأرقام مع تنظيف الفواصل والرموز
          double numCell(int i, [double fallback = 0]) {
            final v = cell(i);
            if (v.isEmpty) return fallback;
            // إزالة كل ما ليس رقماً أو نقطة عشرية
            final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
            return double.tryParse(cleaned) ?? fallback;
          }

          // دالة قراءة التاريخ مع دعم صيغ متعددة
          String dateCell(int i) {
            final v = cell(i);
            if (v.isEmpty) return '';
            // محاولة تحويل التواريخ الرقمية (مثل Excel serial date)
            if (double.tryParse(v) != null) {
              final serial = double.parse(v);
              // تحويل من Excel serial (تبدأ من 1899-12-30)
              final date =
                  DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
              return date.toIso8601String().split('T').first;
            }
            // قبول صيغ مختلفة: YYYY-MM-DD, DD/MM/YYYY, MM/DD/YYYY
            final patterns = [
              RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'), // YYYY-MM-DD
              RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'), // DD/MM/YYYY
              RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'), // DD-MM-YYYY
            ];
            for (var pattern in patterns) {
              final match = pattern.firstMatch(v);
              if (match != null) {
                try {
                  final y = int.parse(match.group(3)!);
                  final m = int.parse(match.group(2)!);
                  final d = int.parse(match.group(1)!);
                  return DateTime(y, m, d).toIso8601String().split('T').first;
                } catch (_) {}
              }
            }
            return v;
          }

          final name = cell(0);
          if (name.isEmpty) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_name_required',
              details: 'الاسم فارغ',
            ));
            continue;
          }

          final basicSalary = numCell(8);
          if (basicSalary <= 0) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_salary',
              details: 'الراتب الأساسي يجب أن يكون أكبر من 0',
            ));
            continue;
          }

          // معالجة القيم النصية (تحويل إلى lowercase)
          final salaryType = cell(11).toLowerCase();
          final paymentMethod = cell(12).toLowerCase();

          if (salaryType.isNotEmpty &&
              salaryType != 'net' &&
              salaryType != 'gross') {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_salary_type',
              details: 'يجب أن يكون net أو gross',
            ));
            continue;
          }

          if (paymentMethod.isNotEmpty &&
              paymentMethod != 'cash' &&
              paymentMethod != 'bank') {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_payment_method',
              details: 'يجب أن يكون cash أو bank',
            ));
            continue;
          }

          // قراءة التاريخ مع دعم صيغ متعددة
          final hireDate = dateCell(4);

          final employee = Employee(
            id: const Uuid().v4(),
            nameAr: cell(0),
            nameEn: cell(1),
            department: cell(2),
            jobTitle: cell(3),
            nationalId: cell(4),
            hireDate: hireDate,
            contractType: cell(6).isEmpty ? 'permanent' : cell(6).toLowerCase(),
            employeeType: cell(7).isEmpty ? 'full-time' : cell(7).toLowerCase(),
            insuranceCode: cell(8),
            insuranceFile: '',
            taxFile: '',
            basicSalary: basicSalary,
            allowances: numCell(10),
            deductions: numCell(11),
            salaryType: salaryType.isEmpty ? 'net' : salaryType,
            paymentMethod: paymentMethod.isEmpty ? 'cash' : paymentMethod,
            bankName: cell(14),
            bankAccount: cell(15),
            bankSwift: cell(16),
            bankIban: cell(17),
            isActive: !(cell(18).toLowerCase() == 'false' || cell(18) == '0'),
          );

          // ✅ طباعة بيانات الموظف للتأكد (للـ Debug)
          print(
              '✅ صف $displayRow: ${employee.nameAr} - الراتب: ${employee.basicSalary}');

          try {
            await _employeeStorage.insertEmployee(employee);
            imported++;
            print('✅ تم إدراج: ${employee.nameAr} في قاعدة البيانات');
          } catch (dbError) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_db',
              details: dbError.toString(),
            ));
          }
        } catch (e) {
          errors.add(ImportRowError(
            row: displayRow,
            messageKey: 'import_error_invalid_row',
            details: e.toString(),
          ));
        }
      }

      String messageKey;
      if (imported > 0 && errors.isEmpty) {
        messageKey = 'import_success';
      } else if (imported > 0 && errors.isNotEmpty) {
        messageKey = 'import_partial_success';
      } else {
        messageKey = 'import_failed';
      }

      return BulkImportResult(
        imported: imported,
        errors: errors,
        cancelled: false,
        messageKey: messageKey,
      );
    } catch (e) {
      return BulkImportResult(
        imported: 0,
        errors: [],
        cancelled: false,
        messageKey: 'import_error_general',
      );
    }
  }
}

/* 
class BulkImportService {
  final _employeeStorage = EmployeeStorage();

  Future<BulkImportResult> importFromExcel() async {
    try {
      // ignore: deprecated_member_use
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
       // withData: true,
      );

      if (result == null) {
        return BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: true,
          messageKey: 'import_cancelled',
        );
      }

      final file = result.files.single;
      if (file.bytes == null) {
        return BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: false,
          messageKey: 'import_error_empty_file',
        );
      }

      final excel = Excel.decodeBytes(file.bytes!);
      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null || sheet.maxRows < 2) {
        return BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: false,
          messageKey: 'import_error_no_data',
        );
      }

      int imported = 0;
      final errors = <ImportRowError>[];

      for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        final displayRow = rowIndex + 1;

        // تجاهل الصفوف الفارغة
        if (row.every((cell) =>
            cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        try {
          // دالة قراءة الخلية
          String cell(int i) {
            if (i >= row.length) return '';
            final value = row[i]?.value;
            if (value == null) return '';
            return value.toString().trim();
          }

          // دالة قراءة الأرقام مع تنظيف الفواصل والرموز
          double numCell(int i, [double fallback = 0]) {
            final v = cell(i);
            if (v.isEmpty) return fallback;
            // إزالة كل ما ليس رقماً أو نقطة عشرية
            final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
            return double.tryParse(cleaned) ?? fallback;
          }

          // دالة قراءة التاريخ مع دعم صيغ متعددة
          String dateCell(int i) {
            final v = cell(i);
            if (v.isEmpty) return '';
            // محاولة تحويل التواريخ الرقمية (مثل Excel serial date)
            if (double.tryParse(v) != null) {
              final serial = double.parse(v);
              // تحويل من Excel serial (تبدأ من 1899-12-30)
              final date =
                  DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
              return date.toIso8601String().split('T').first;
            }
            // قبول صيغ مختلفة: YYYY-MM-DD, DD/MM/YYYY, MM/DD/YYYY
            final patterns = [
              RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'), // YYYY-MM-DD
              RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'), // DD/MM/YYYY
              RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'), // DD-MM-YYYY
            ];
            for (var pattern in patterns) {
              final match = pattern.firstMatch(v);
              if (match != null) {
                try {
                  final y = int.parse(match.group(3)!);
                  final m = int.parse(match.group(2)!);
                  final d = int.parse(match.group(1)!);
                  return DateTime(y, m, d).toIso8601String().split('T').first;
                } catch (_) {}
              }
            }
            return v;
          }

          final name = cell(0);
          if (name.isEmpty) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_name_required',
              details: 'الاسم فارغ',
            ));
            continue;
          }

          final basicSalary = numCell(8);
          if (basicSalary <= 0) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_salary',
              details: 'الراتب الأساسي يجب أن يكون أكبر من 0',
            ));
            continue;
          }

          // معالجة القيم النصية (تحويل إلى lowercase)
          final salaryType = cell(11).toLowerCase();
          final paymentMethod = cell(12).toLowerCase();

          if (salaryType.isNotEmpty &&
              salaryType != 'net' &&
              salaryType != 'gross') {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_salary_type',
              details: 'يجب أن يكون net أو gross',
            ));
            continue;
          }

          if (paymentMethod.isNotEmpty &&
              paymentMethod != 'cash' &&
              paymentMethod != 'bank') {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_payment_method',
              details: 'يجب أن يكون cash أو bank',
            ));
            continue;
          }

          // قراءة التاريخ مع دعم صيغ متعددة
          final hireDate = dateCell(4);

          final employee = Employee(
            id: const Uuid().v4(),
            nameAr: cell(0),
            nameEn: cell(1),
            department: cell(2),
            jobTitle: cell(3),
            nationalId: cell(4),
            hireDate: hireDate,
            contractType: cell(6).isEmpty ? 'permanent' : cell(6).toLowerCase(),
            employeeType: cell(7).isEmpty ? 'full-time' : cell(7).toLowerCase(),
            insuranceCode: cell(8),
            insuranceFile: '',
            taxFile: '',
            basicSalary: basicSalary,
            allowances: numCell(10),
            deductions: numCell(11),
            salaryType: salaryType.isEmpty ? 'net' : salaryType,
            paymentMethod: paymentMethod.isEmpty ? 'cash' : paymentMethod,
            bankName: cell(14),
            bankAccount: cell(15),
            bankSwift: cell(16),
            bankIban: cell(17),
            isActive: !(cell(18).toLowerCase() == 'false' || cell(18) == '0'),
          );

          // ✅ طباعة بيانات الموظف للتأكد (للـ Debug)
          print(
              '✅ صف $displayRow: ${employee.nameAr} - الراتب: ${employee.basicSalary}');

          try {
            await _employeeStorage.insertEmployee(employee);
            imported++;
            print('✅ تم إدراج: ${employee.nameAr} في قاعدة البيانات');
          } catch (dbError) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_db',
              details: dbError.toString(),
            ));
          }
        } catch (e) {
          errors.add(ImportRowError(
            row: displayRow,
            messageKey: 'import_error_invalid_row',
            details: e.toString(),
          ));
        }
      }

      String messageKey;
      if (imported > 0 && errors.isEmpty) {
        messageKey = 'import_success';
      } else if (imported > 0 && errors.isNotEmpty) {
        messageKey = 'import_partial_success';
      } else {
        messageKey = 'import_failed';
      }

      return BulkImportResult(
        imported: imported,
        errors: errors,
        cancelled: false,
        messageKey: messageKey,
      );
    } catch (e) {
      return BulkImportResult(
        imported: 0,
        errors: [],
        cancelled: false,
        messageKey: 'import_error_general',
      );
    }
  }
}
 */
class ImportRowError {
  final int row;
  final String messageKey;
  final String details;
  const ImportRowError({
    required this.row,
    required this.messageKey,
    this.details = '',
  });
}

class BulkImportResult {
  final int imported;
  final List<ImportRowError> errors;
  final bool cancelled;
  final String messageKey;

  const BulkImportResult({
    required this.imported,
    required this.errors,
    required this.cancelled,
    required this.messageKey,
  });
}
