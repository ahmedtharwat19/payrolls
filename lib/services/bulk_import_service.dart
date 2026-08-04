// ignore_for_file: deprecated_member_use

/* /* // lib/services/bulk_import_service.dart

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
 */
// lib/services/bulk_import_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import '../database/employee_storage.dart';
import '../models/employee_model.dart';

class BulkImportService {
  final _employeeStorage = EmployeeStorage();

  // ============================================
  // 1. الاستيراد من ملف Excel
  // ============================================
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
      final fileBytes = await file.readAsBytes();

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

        if (row.every((cell) =>
            cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        try {
          String cell(int i) {
            if (i >= row.length) return '';
            final value = row[i]?.value;
            if (value == null) return '';
            return value.toString().trim();
          }

          double numCell(int i, [double fallback = 0]) {
            final v = cell(i);
            if (v.isEmpty) return fallback;
            final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
            return double.tryParse(cleaned) ?? fallback;
          }

          String dateCell(int i) {
            final v = cell(i);
            if (v.isEmpty) return '';
            if (double.tryParse(v) != null) {
              final serial = double.parse(v);
              final date =
                  DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
              return date.toIso8601String().split('T').first;
            }
            final patterns = [
              RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
              RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
              RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'),
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

          final nameAr = cell(0);
          if (nameAr.isEmpty) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_name_required',
              details: 'الاسم فارغ',
            ));
            continue;
          }

          final nameEn = cell(1);
          final department = cell(2);
          final jobTitle = cell(3);
          final hireDate = dateCell(4);
          final nationalId = cell(5);
          final contractType =
              cell(6).isEmpty ? 'permanent' : cell(6).toLowerCase();
          final employeeType =
              cell(7).isEmpty ? 'full-time' : cell(7).toLowerCase();

          final basicSalary = numCell(8);
          if (basicSalary <= 0) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_salary',
              details: 'الراتب الأساسي يجب أن يكون أكبر من 0',
            ));
            continue;
          }

          final allowances = numCell(9);
          final deductions = numCell(10);

          final salaryType = cell(11).toLowerCase();
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

          final paymentMethod = cell(12).toLowerCase();
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

          final bankName = cell(13);
          final bankAccount = cell(14);
          final bankSwift = cell(15);
          final bankIban = cell(16);

          if (paymentMethod == 'bank' &&
              (bankName.isEmpty || bankAccount.isEmpty)) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_bank_required',
              details: 'طريقة الدفع بنك تتطلب اسم البنك ورقم الحساب',
            ));
            continue;
          }

          final isActive =
              !(cell(17).toLowerCase() == 'false' || cell(17) == '0');

          final employee = Employee(
            id: const Uuid().v4(),
            nameAr: nameAr,
            nameEn: nameEn,
            department: department,
            jobTitle: jobTitle,
            nationalId: nationalId,
            hireDate: hireDate,
            contractType: contractType,
            employeeType: employeeType,
            insuranceCode: '',
            insuranceFile: '',
            taxFile: '',
            basicSalary: basicSalary,
            allowances: allowances,
            deductions: deductions,
            salaryType: salaryType.isEmpty ? 'net' : salaryType,
            paymentMethod: paymentMethod.isEmpty ? 'cash' : paymentMethod,
            bankName: bankName,
            bankAccount: bankAccount,
            bankSwift: bankSwift,
            bankIban: bankIban,
            isActive: isActive,
          );

          try {
            await _employeeStorage.insertEmployee(employee);
            imported++;
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

  // ============================================
  // 2. تصدير الموظفين إلى Excel (بدون FilePicker.saveFile)
  // ============================================
  Future<String?> exportEmployeesToExcel() async {
    try {
      final employees = await _employeeStorage.getAllEmployees();

      if (employees.isEmpty) {
        throw Exception('لا يوجد موظفين لتصديرهم');
      }

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Employees'];

      final headers = [
        'Name (Arabic)',
        'Name (English)',
        'Department',
        'Job Title',
        'Hire Date',
        'National ID',
        'Contract Type',
        'Employee Type',
        'Basic Salary',
        'Allowances',
        'Deductions',
        'Salary Type',
        'Payment Method',
        'Bank Name',
        'Bank Account',
        'Swift Code',
        'IBAN',
        'Active'
      ];

      sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

      for (var emp in employees) {
        sheetObject.appendRow([
          TextCellValue(emp.nameAr),
          TextCellValue(emp.nameEn),
          TextCellValue(emp.department),
          TextCellValue(emp.jobTitle),
          TextCellValue(emp.hireDate),
          TextCellValue(emp.nationalId),
          TextCellValue(emp.contractType),
          TextCellValue(emp.employeeType),
          DoubleCellValue(emp.basicSalary),
          DoubleCellValue(emp.allowances),
          DoubleCellValue(emp.deductions),
          TextCellValue(emp.salaryType),
          TextCellValue(emp.paymentMethod),
          TextCellValue(emp.bankName),
          TextCellValue(emp.bankAccount),
          TextCellValue(emp.bankSwift),
          TextCellValue(emp.bankIban),
          TextCellValue(emp.isActive ? 'true' : 'false'),
        ]);
      }

      final excelBytes = excel.encode();
      if (excelBytes == null) {
        throw Exception('فشل إنشاء ملف Excel');
      }

      // حفظ الملف في مجلد المستندات تلقائياً
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/employees_export_${DateTime.now().toIso8601String().split('T').first}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(excelBytes));

      // إرجاع مسار الملف لعرضه للمستخدم
      return filePath;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // 3. تحميل نموذج Excel (بدون SharePlus)
  // ============================================
  static Future<String?> downloadTemplate(BuildContext context) async {
    try {
      final isArabic = context.locale.languageCode == 'ar';

      final List<String> headers = isArabic
          ? [
              'الاسم بالعربية',
              'الاسم بالإنجليزية',
              'القسم',
              'المسمى الوظيفي',
              'تاريخ التعيين',
              'الرقم القومي',
              'نوع العقد',
              'نوع الموظف',
              'الراتب الأساسي',
              'البدلات',
              'الخصومات',
              'نوع الراتب',
              'طريقة الدفع',
              'اسم البنك',
              'رقم الحساب',
              'كود Swift',
              'IBAN',
              'نشط',
            ]
          : [
              'Name (Arabic)',
              'Name (English)',
              'Department',
              'Job Title',
              'Hire Date',
              'National ID',
              'Contract Type',
              'Employee Type',
              'Basic Salary',
              'Allowances',
              'Deductions',
              'Salary Type',
              'Payment Method',
              'Bank Name',
              'Bank Account',
              'Swift Code',
              'IBAN',
              'Active',
            ];

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];
      sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

      final sampleRow = isArabic
          ? [
              TextCellValue('أحمد محمد'),
              TextCellValue('Ahmed Mohamed'),
              TextCellValue('المبيعات'),
              TextCellValue('مدير مبيعات'),
              TextCellValue('2023-01-15'),
              TextCellValue('12345678901234'),
              TextCellValue('permanent'),
              TextCellValue('full-time'),
              DoubleCellValue(15000),
              DoubleCellValue(2000),
              DoubleCellValue(500),
              TextCellValue('net'),
              TextCellValue('bank'),
              TextCellValue('البنك الأهلي'),
              TextCellValue('123456789'),
              TextCellValue('AHBLEG'),
              TextCellValue('EG123456789'),
              TextCellValue('true'),
            ]
          : [
              TextCellValue('Ahmed Mohamed'),
              TextCellValue('Ahmed Mohamed'),
              TextCellValue('Sales'),
              TextCellValue('Sales Manager'),
              TextCellValue('2023-01-15'),
              TextCellValue('12345678901234'),
              TextCellValue('permanent'),
              TextCellValue('full-time'),
              DoubleCellValue(15000),
              DoubleCellValue(2000),
              DoubleCellValue(500),
              TextCellValue('net'),
              TextCellValue('bank'),
              TextCellValue('National Bank'),
              TextCellValue('123456789'),
              TextCellValue('AHBLEG'),
              TextCellValue('EG123456789'),
              TextCellValue('true'),
            ];

      sheetObject.appendRow(sampleRow);

      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('فشل إنشاء ملف النموذج');
      }

      // حفظ الملف في مجلد المستندات
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/employee_import_template.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(bytes));

      // إرجاع المسار
      return filePath;
    } catch (e) {
      rethrow;
    }
  }
}

// ============================================
// نماذج البيانات المساعدة
// ============================================
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
 */
// lib/services/bulk_import_service.dart
/* 
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import '../database/employee_storage.dart';
import '../models/employee_model.dart';

class BulkImportService {
  final _employeeStorage = EmployeeStorage();

  // ============================================
  // 1. الاستيراد من ملف Excel
  // ============================================
  Future<BulkImportResult> importFromExcel() async {
    try {
      // ⚠️ مهم جدًا مع file_picker 11+/12-beta: withData بقت افتراضيًا false
      // (withReadStream: true بدلها) - لازم نصرح withData: true صراحةً
      // عشان .bytes يترجع فعليًا، وإلا هيرجع null دايمًا.
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null) {
        return const BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: true,
          messageKey: 'import_cancelled',
        );
      }

      final file = result.files.single;
      final fileBytes = file.bytes;

      if (fileBytes == null) {
        return const BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: false,
          messageKey: 'import_error_empty_file',
        );
      }

      final excel = Excel.decodeBytes(fileBytes);
      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null || sheet.maxRows < 2) {
        return const BulkImportResult(
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

        if (row.every((cell) =>
            cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        try {
          String cell(int i) {
            if (i >= row.length) return '';
            final value = row[i]?.value;
            if (value == null) return '';
            return value.toString().trim();
          }

          double numCell(int i, [double fallback = 0]) {
            final v = cell(i);
            if (v.isEmpty) return fallback;
            final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
            return double.tryParse(cleaned) ?? fallback;
          }

          String dateCell(int i) {
            final v = cell(i);
            if (v.isEmpty) return '';
            if (double.tryParse(v) != null) {
              final serial = double.parse(v);
              final date =
                  DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
              return date.toIso8601String().split('T').first;
            }
            final patterns = [
              RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
              RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
              RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'),
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

          final nameAr = cell(0);
          if (nameAr.isEmpty) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_name_required',
              details: 'الاسم فارغ',
            ));
            continue;
          }

          final nameEn = cell(1);
          final department = cell(2);
          final jobTitle = cell(3);
          final hireDate = dateCell(4);
          final nationalId = cell(5);
          final contractType =
              cell(6).isEmpty ? 'permanent' : cell(6).toLowerCase();
          final employeeType =
              cell(7).isEmpty ? 'full-time' : cell(7).toLowerCase();

          final basicSalary = numCell(8);
          if (basicSalary <= 0) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_salary',
              details: 'الراتب الأساسي يجب أن يكون أكبر من 0',
            ));
            continue;
          }

          final allowances = numCell(9);
          final deductions = numCell(10);

          final salaryType = cell(11).toLowerCase();
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

          final paymentMethod = cell(12).toLowerCase();
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

          final bankName = cell(13);
          final bankAccount = cell(14);
          final bankSwift = cell(15);
          final bankIban = cell(16);

          if (paymentMethod == 'bank' &&
              (bankName.isEmpty || bankAccount.isEmpty)) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_bank_required',
              details: 'طريقة الدفع بنك تتطلب اسم البنك ورقم الحساب',
            ));
            continue;
          }

          final isActive =
              !(cell(17).toLowerCase() == 'false' || cell(17) == '0');

          final employee = Employee(
            id: const Uuid().v4(),
            nameAr: nameAr,
            nameEn: nameEn,
            department: department,
            jobTitle: jobTitle,
            nationalId: nationalId,
            hireDate: hireDate,
            contractType: contractType,
            employeeType: employeeType,
            insuranceCode: '',
            insuranceFile: '',
            taxFile: '',
            basicSalary: basicSalary,
            allowances: allowances,
            deductions: deductions,
            salaryType: salaryType.isEmpty ? 'net' : salaryType,
            paymentMethod: paymentMethod.isEmpty ? 'cash' : paymentMethod,
            bankName: bankName,
            bankAccount: bankAccount,
            bankSwift: bankSwift,
            bankIban: bankIban,
            isActive: isActive,
          );

          try {
            await _employeeStorage.insertEmployee(employee);
            imported++;
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
      return const BulkImportResult(
        imported: 0,
        errors: [],
        cancelled: false,
        messageKey: 'import_error_general',
      );
    }
  }

  // ============================================
  // 2. تصدير الموظفين إلى Excel
  // ============================================
  Future<String?> exportEmployeesToExcel() async {
    final employees = await _employeeStorage.getAllEmployees();

    if (employees.isEmpty) {
      throw Exception('لا يوجد موظفين لتصديرهم');
    }

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Employees'];

    final headers = [
      'Name (Arabic)',
      'Name (English)',
      'Department',
      'Job Title',
      'Hire Date',
      'National ID',
      'Contract Type',
      'Employee Type',
      'Basic Salary',
      'Allowances',
      'Deductions',
      'Salary Type',
      'Payment Method',
      'Bank Name',
      'Bank Account',
      'Swift Code',
      'IBAN',
      'Active',
    ];

    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    for (var emp in employees) {
      sheetObject.appendRow([
        TextCellValue(emp.nameAr),
        TextCellValue(emp.nameEn),
        TextCellValue(emp.department),
        TextCellValue(emp.jobTitle),
        TextCellValue(emp.hireDate),
        TextCellValue(emp.nationalId),
        TextCellValue(emp.contractType),
        TextCellValue(emp.employeeType),
        DoubleCellValue(emp.basicSalary),
        DoubleCellValue(emp.allowances),
        DoubleCellValue(emp.deductions),
        TextCellValue(emp.salaryType),
        TextCellValue(emp.paymentMethod),
        TextCellValue(emp.bankName),
        TextCellValue(emp.bankAccount),
        TextCellValue(emp.bankSwift),
        TextCellValue(emp.bankIban),
        TextCellValue(emp.isActive ? 'true' : 'false'),
      ]);
    }

    final excelBytes = excel.encode();
    if (excelBytes == null) {
      throw Exception('فشل إنشاء ملف Excel');
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath =
        '${dir.path}/employees_export_${DateTime.now().toIso8601String().split('T').first}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(Uint8List.fromList(excelBytes));

    return filePath;
  }

  // ============================================
  // 3. تحميل نموذج Excel
  // ============================================
  static Future<String?> downloadTemplate(BuildContext context) async {
    final isArabic = context.locale.languageCode == 'ar';

    final List<String> headers = isArabic
        ? [
            'الاسم بالعربية',
            'الاسم بالإنجليزية',
            'القسم',
            'المسمى الوظيفي',
            'تاريخ التعيين',
            'الرقم القومي',
            'نوع العقد',
            'نوع الموظف',
            'الراتب الأساسي',
            'البدلات',
            'الخصومات',
            'نوع الراتب',
            'طريقة الدفع',
            'اسم البنك',
            'رقم الحساب',
            'كود Swift',
            'IBAN',
            'نشط'
          ]
        : [
            'Name (Arabic)',
            'Name (English)',
            'Department',
            'Job Title',
            'Hire Date',
            'National ID',
            'Contract Type',
            'Employee Type',
            'Basic Salary',
            'Allowances',
            'Deductions',
            'Salary Type',
            'Payment Method',
            'Bank Name',
            'Bank Account',
            'Swift Code',
            'IBAN',
            'Active'
          ];

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    final sampleRow = isArabic
        ? [
            TextCellValue('أحمد محمد'),
            TextCellValue('Ahmed Mohamed'),
            TextCellValue('المبيعات'),
            TextCellValue('مدير مبيعات'),
            TextCellValue('2023-01-15'),
            TextCellValue('12345678901234'),
            TextCellValue('permanent'),
            TextCellValue('full-time'),
            DoubleCellValue(15000),
            DoubleCellValue(2000),
            DoubleCellValue(500),
            TextCellValue('net'),
            TextCellValue('bank'),
            TextCellValue('البنك الأهلي'),
            TextCellValue('123456789'),
            TextCellValue('AHBLEG'),
            TextCellValue('EG123456789'),
            TextCellValue('true'),
          ]
        : [
            TextCellValue('Ahmed Mohamed'),
            TextCellValue('Ahmed Mohamed'),
            TextCellValue('Sales'),
            TextCellValue('Sales Manager'),
            TextCellValue('2023-01-15'),
            TextCellValue('12345678901234'),
            TextCellValue('permanent'),
            TextCellValue('full-time'),
            DoubleCellValue(15000),
            DoubleCellValue(2000),
            DoubleCellValue(500),
            TextCellValue('net'),
            TextCellValue('bank'),
            TextCellValue('National Bank'),
            TextCellValue('123456789'),
            TextCellValue('AHBLEG'),
            TextCellValue('EG123456789'),
            TextCellValue('true'),
          ];

    sheetObject.appendRow(sampleRow);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('فشل إنشاء ملف النموذج');
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/employee_import_template.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(Uint8List.fromList(bytes));

    return filePath;
  }
}

// ============================================
// نماذج البيانات المساعدة
// ============================================
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
 */

// lib/services/bulk_import_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import '../database/employee_storage.dart';
import '../models/employee_model.dart';

class BulkImportService {
  final _employeeStorage = EmployeeStorage();

  // ============================================
  // 1. الاستيراد من ملف Excel
  // ============================================
  Future<BulkImportResult> importFromExcel() async {
    try {
      // ⚠️ مهم جدًا مع file_picker 11+/12-beta: withData بقت افتراضيًا false
      // (withReadStream: true بدلها) - لازم نصرح withData: true صراحةً
      // عشان .bytes يترجع فعليًا، وإلا هيرجع null دايمًا.
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null) {
        return const BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: true,
          messageKey: 'import_cancelled',
        );
      }

      final file = result.files.single;
      final fileBytes = file.bytes;

      if (fileBytes == null) {
        return const BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: false,
          messageKey: 'import_error_empty_file',
        );
      }

      final excel = Excel.decodeBytes(fileBytes);
      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null || sheet.maxRows < 2) {
        return const BulkImportResult(
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

        if (row.every((cell) =>
            cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        try {
          String cell(int i) {
            if (i >= row.length) return '';
            final value = row[i]?.value;
            if (value == null) return '';
            return value.toString().trim();
          }

          double numCell(int i, [double fallback = 0]) {
            final v = cell(i);
            if (v.isEmpty) return fallback;
            final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
            return double.tryParse(cleaned) ?? fallback;
          }

          String dateCell(int i) {
            final v = cell(i);
            if (v.isEmpty) return '';
            if (double.tryParse(v) != null) {
              final serial = double.parse(v);
              final date =
                  DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
              return date.toIso8601String().split('T').first;
            }
            final patterns = [
              RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
              RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
              RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'),
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

          final nameAr = cell(0);
          if (nameAr.isEmpty) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_name_required',
              details: 'الاسم فارغ',
            ));
            continue;
          }

          final nameEn = cell(1);
          final department = cell(2);
          final jobTitle = cell(3);
          final hireDate = dateCell(4);
          final nationalId = cell(5);
          final contractType =
              cell(6).isEmpty ? 'permanent' : cell(6).toLowerCase();
          final employeeType =
              cell(7).isEmpty ? 'full-time' : cell(7).toLowerCase();

          final basicSalary = numCell(8);
          if (basicSalary <= 0) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_salary',
              details: 'الراتب الأساسي يجب أن يكون أكبر من 0',
            ));
            continue;
          }

          final allowances = numCell(9);
          final deductions = numCell(10);

          final salaryType = cell(11).toLowerCase();
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

          final paymentMethod = cell(12).toLowerCase();
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

          final bankName = cell(13);
          final bankAccount = cell(14);
          final bankSwift = cell(15);
          final bankIban = cell(16);

          if (paymentMethod == 'bank' &&
              (bankName.isEmpty || bankAccount.isEmpty)) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_bank_required',
              details: 'طريقة الدفع بنك تتطلب اسم البنك ورقم الحساب',
            ));
            continue;
          }

          final isActive =
              !(cell(17).toLowerCase() == 'false' || cell(17) == '0');

          final employee = Employee(
            id: const Uuid().v4(),
            nameAr: nameAr,
            nameEn: nameEn,
            department: department,
            jobTitle: jobTitle,
            nationalId: nationalId,
            hireDate: hireDate,
            contractType: contractType,
            employeeType: employeeType,
            insuranceCode: '',
            insuranceFile: '',
            taxFile: '',
            basicSalary: basicSalary,
            allowances: allowances,
            deductions: deductions,
            salaryType: salaryType.isEmpty ? 'net' : salaryType,
            paymentMethod: paymentMethod.isEmpty ? 'cash' : paymentMethod,
            bankName: bankName,
            bankAccount: bankAccount,
            bankSwift: bankSwift,
            bankIban: bankIban,
            isActive: isActive,
          );

          try {
            await _employeeStorage.insertEmployee(employee);
            imported++;
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
      return const BulkImportResult(
        imported: 0,
        errors: [],
        cancelled: false,
        messageKey: 'import_error_general',
      );
    }
  }

  // ============================================
  // 2. تصدير الموظفين إلى Excel
  // ============================================
  Future<String?> exportEmployeesToExcel() async {
    final employees = await _employeeStorage.getAllEmployees();

    if (employees.isEmpty) {
      throw Exception('لا يوجد موظفين لتصديرهم');
    }

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Employees'];

    final headers = [
      'Name (Arabic)',
      'Name (English)',
      'Department',
      'Job Title',
      'Hire Date',
      'National ID',
      'Contract Type',
      'Employee Type',
      'Basic Salary',
      'Allowances',
      'Deductions',
      'Salary Type',
      'Payment Method',
      'Bank Name',
      'Bank Account',
      'Swift Code',
      'IBAN',
      'Active',
    ];

    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    for (var emp in employees) {
      sheetObject.appendRow([
        TextCellValue(emp.nameAr),
        TextCellValue(emp.nameEn),
        TextCellValue(emp.department),
        TextCellValue(emp.jobTitle),
        TextCellValue(emp.hireDate),
        TextCellValue(emp.nationalId),
        TextCellValue(emp.contractType),
        TextCellValue(emp.employeeType),
        DoubleCellValue(emp.basicSalary),
        DoubleCellValue(emp.allowances),
        DoubleCellValue(emp.deductions),
        TextCellValue(emp.salaryType),
        TextCellValue(emp.paymentMethod),
        TextCellValue(emp.bankName),
        TextCellValue(emp.bankAccount),
        TextCellValue(emp.bankSwift),
        TextCellValue(emp.bankIban),
        TextCellValue(emp.isActive ? 'true' : 'false'),
      ]);
    }

    final excelBytes = excel.encode();
    if (excelBytes == null) {
      throw Exception('فشل إنشاء ملف Excel');
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath =
        '${dir.path}/employees_export_${DateTime.now().toIso8601String().split('T').first}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(Uint8List.fromList(excelBytes));

    return filePath;
  }

  // ============================================
  // 3. تحميل نموذج Excel
  // ============================================
  static Future<String?> downloadTemplate(BuildContext context) async {
    final isArabic = context.locale.languageCode == 'ar';

    final List<String> headers = isArabic
        ? [
            'الاسم بالعربية',
            'الاسم بالإنجليزية',
            'القسم',
            'المسمى الوظيفي',
            'تاريخ التعيين',
            'الرقم القومي',
            'نوع العقد',
            'نوع الموظف',
            'الراتب الأساسي',
            'البدلات',
            'الخصومات',
            'نوع الراتب',
            'طريقة الدفع',
            'اسم البنك',
            'رقم الحساب',
            'كود Swift',
            'IBAN',
            'نشط'
          ]
        : [
            'Name (Arabic)',
            'Name (English)',
            'Department',
            'Job Title',
            'Hire Date',
            'National ID',
            'Contract Type',
            'Employee Type',
            'Basic Salary',
            'Allowances',
            'Deductions',
            'Salary Type',
            'Payment Method',
            'Bank Name',
            'Bank Account',
            'Swift Code',
            'IBAN',
            'Active'
          ];

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    final sampleRow = isArabic
        ? [
            TextCellValue('أحمد محمد'),
            TextCellValue('Ahmed Mohamed'),
            TextCellValue('المبيعات'),
            TextCellValue('مدير مبيعات'),
            TextCellValue('2023-01-15'),
            TextCellValue('12345678901234'),
            TextCellValue('permanent'),
            TextCellValue('full-time'),
            DoubleCellValue(15000),
            DoubleCellValue(2000),
            DoubleCellValue(500),
            TextCellValue('net'),
            TextCellValue('bank'),
            TextCellValue('البنك الأهلي'),
            TextCellValue('123456789'),
            TextCellValue('AHBLEG'),
            TextCellValue('EG123456789'),
            TextCellValue('true'),
          ]
        : [
            TextCellValue('Ahmed Mohamed'),
            TextCellValue('Ahmed Mohamed'),
            TextCellValue('Sales'),
            TextCellValue('Sales Manager'),
            TextCellValue('2023-01-15'),
            TextCellValue('12345678901234'),
            TextCellValue('permanent'),
            TextCellValue('full-time'),
            DoubleCellValue(15000),
            DoubleCellValue(2000),
            DoubleCellValue(500),
            TextCellValue('net'),
            TextCellValue('bank'),
            TextCellValue('National Bank'),
            TextCellValue('123456789'),
            TextCellValue('AHBLEG'),
            TextCellValue('EG123456789'),
            TextCellValue('true'),
          ];

    sheetObject.appendRow(sampleRow);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('فشل إنشاء ملف النموذج');
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/employee_import_template.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(Uint8List.fromList(bytes));

    return filePath;
  }
}

// ============================================
// نماذج البيانات المساعدة
// ============================================
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
