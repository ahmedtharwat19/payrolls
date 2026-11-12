/* // ignore_for_file: deprecated_member_use


// lib/services/bulk_import_service.dart


// lib/services/bulk_import_service.dart

// lib/services/bulk_import_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import '../database/app_database.dart';
import '../database/employee_storage.dart';
import '../models/employee_model.dart';
import '../models/payroll_record_model.dart';
import '../services/tax_service.dart';
import '../services/payroll_calculation_service.dart';

class BulkImportService {
  final _employeeStorage = EmployeeStorage();
  final _uuid = const Uuid();
  TaxService? _taxService;

  // ============================================
  // 1. الاستيراد من ملف Excel (مع إنشاء سجلات مرتبات)
  // ============================================
  Future<BulkImportResult> importFromExcel() async {
    try {
      // file_picker v12: pickFile بترجع null لو المستخدم لغى الاختيار،
      // ومفيش withData - القراءة بـ readAsBytes() على كل المنصات.
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (file == null) {
        return const BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: true,
          messageKey: 'import_cancelled',
        );
      }

      final fileBytes = await file.readAsBytes();

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

      // قراءة صف العناوين
      final headerRow = sheet.row(0);
      if (headerRow.isEmpty) {
        return const BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: false,
          messageKey: 'import_error_no_headers',
        );
      }

      // بناء خريطة: اسم العمود -> الفهرس
      final Map<String, int> columnIndex = {};
      for (int i = 0; i < headerRow.length; i++) {
        final cell = headerRow[i];
        final value = cell?.value?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          columnIndex[value] = i;
        }
      }

      // دوال مساعدة لقراءة البيانات
      String getString(List<Data?> row, String colName) {
        final idx = columnIndex[colName];
        if (idx == null || idx >= row.length) return '';
        final cell = row[idx];
        return cell?.value?.toString().trim() ?? '';
      }

      double getDouble(List<Data?> row, String colName, {double fallback = 0}) {
        final str = getString(row, colName);
        if (str.isEmpty) return fallback;
        final cleaned = str.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(cleaned) ?? fallback;
      }

      bool getBool(List<Data?> row, String colName, {bool fallback = true}) {
        final str = getString(row, colName).toLowerCase();
        if (str.isEmpty) return fallback;
        return str == 'true' || str == '1' || str == 'نعم' || str == 'نشط';
      }

      String parseDate(String str) {
        if (str.isEmpty) return '';
        if (double.tryParse(str) != null) {
          final serial = double.parse(str);
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
          final match = pattern.firstMatch(str);
          if (match != null) {
            try {
              final y = int.parse(match.group(3)!);
              final m = int.parse(match.group(2)!);
              final d = int.parse(match.group(1)!);
              return DateTime(y, m, d).toIso8601String().split('T').first;
            } catch (_) {}
          }
        }
        return str;
      }

      final db = await AppDatabase.instance.database;

      int imported = 0;
      final errors = <ImportRowError>[];

      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        final displayRow = rowIndex + 1;

        if (row.every((cell) =>
            cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        try {
          final nameAr = getString(row, 'الاسم بالعربية');
          final nameEn = getString(row, 'الاسم بالإنجليزية');

          if (nameAr.isEmpty) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_name_required',
              details: 'الاسم بالعربية فارغ',
            ));
            continue;
          }

          final department = getString(row, 'القسم');
          final jobTitle = getString(row, 'المسمى الوظيفي');
          final hireDateRaw = getString(row, 'تاريخ التعيين');
          final hireDate = parseDate(hireDateRaw);
          final nationalId = getString(row, 'الرقم القومي');
          final contractType = getString(row, 'نوع العقد');
          final employeeType = getString(row, 'نوع الموظف');

          double basicSalary = getDouble(row, 'الراتب الأساسي');
          final variableSalary = getDouble(row, 'المتغير');
          double allowances = getDouble(row, 'البدلات');
          final deductions = getDouble(row, 'الخصومات');
          final expenses = getDouble(row, 'المصروفات');

          // لو الأساسي صفر والبدلات موجودة: ننقل المبلغ للأساسي بدل ما ننسخه
          // (النسخ كان بيكرر نفس المبلغ في الأساسي والبدلات ويتحسب مرتين).
          if (basicSalary == 0 && allowances > 0) {
            basicSalary = allowances;
            allowances = 0;
          }

          final salaryType = getString(row, 'نوع الراتب').toLowerCase();
          final paymentMethod = getString(row, 'طريقة الدفع').toLowerCase();

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

          final bankName = getString(row, 'اسم البنك');
          final bankAccount = getString(row, 'رقم الحساب');
          final bankSwift = getString(row, 'كود Swift');
          final bankIban = getString(row, 'IBAN');

          if (paymentMethod == 'bank' &&
              (bankName.isEmpty || bankAccount.isEmpty)) {
            errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_bank_required',
              details: 'طريقة الدفع بنك تتطلب اسم البنك ورقم الحساب',
            ));
            continue;
          }

          final isActive = getBool(row, 'نشط', fallback: true);
          final taxAmount = getDouble(row, 'اجمالي ضريبة كسب العمل');
          final insuranceAmount = getDouble(row, 'مبلغ التامين');
          final netAmount = getDouble(row, 'Net_Amount');

          String monthYearStr = getString(row, 'mo');
          int month = 4;
          int year = 2023;
          if (monthYearStr.isNotEmpty && monthYearStr.contains('/')) {
            final parts = monthYearStr.split('/');
            if (parts.length == 2) {
              month = int.tryParse(parts[0]) ?? 4;
              year = int.tryParse(parts[1]) ?? 2023;
            }
          }

          final employee = Employee(
            id: _uuid.v4(),
            nameAr: nameAr,
            nameEn: nameEn.isNotEmpty ? nameEn : nameAr,
            department: department,
            jobTitle: jobTitle,
            nationalId: nationalId,
            hireDate: hireDate.isNotEmpty
                ? hireDate
                : DateTime.now().toIso8601String().split('T').first,
            contractType: contractType.isNotEmpty ? contractType : 'permanent',
            employeeType: employeeType.isNotEmpty ? employeeType : 'full-time',
            insuranceCode: '',
            insuranceFile: '',
            taxFile: '',
            basicSalary: basicSalary,
            variableSalary: variableSalary,
            allowances: allowances,
            deductions: deductions,
            expenses: expenses,
            salaryType: salaryType.isNotEmpty ? salaryType : 'net',
            paymentMethod: paymentMethod.isNotEmpty ? paymentMethod : 'cash',
            bankName: bankName,
            bankAccount: bankAccount,
            bankSwift: bankSwift,
            bankIban: bankIban,
            isActive: isActive,
          );

          await _employeeStorage.insertEmployee(employee);

          double netSalary = netAmount;
          if (netSalary == 0) {
            netSalary = basicSalary +
                variableSalary +
                allowances -
                deductions -
                expenses -
                taxAmount -
                insuranceAmount;
          }

          final payrollRecord = PayrollRecord(
            id: _uuid.v4(),
            employeeId: employee.id,
            employeeNameAr: employee.nameAr,
            employeeNameEn: employee.nameEn,
            month: month,
            year: year,
            basicSalary: basicSalary,
            variableSalary: variableSalary,
            allowances: allowances,
            deductions: deductions,
            taxAmount: taxAmount,
            insuranceAmount: insuranceAmount,
            netSalary: netSalary,
            generatedAt: DateTime.now(),
            notes: 'تم الاستيراد من ملف Excel',
          );

          await db.insert('payroll_records', payrollRecord.toMap());
          imported++;
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
        errors: [
          ImportRowError(
              row: 0, messageKey: 'import_error_general', details: e.toString())
        ],
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

    final db = await AppDatabase.instance.database;
    final List<Map<String, dynamic>> payrollMaps = await db.query(
      'payroll_records',
      orderBy: 'year DESC, month DESC',
    );

    final Map<String, PayrollRecord> payrollMap = {};
    for (var map in payrollMaps) {
      final record = PayrollRecord.fromMap(map);
      if (!payrollMap.containsKey(record.employeeId)) {
        payrollMap[record.employeeId] = record;
      }
    }

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Employees & Payroll'];

    final headers = [
      'الاسم بالعربية',
      'الاسم بالإنجليزية',
      'القسم',
      'المسمى الوظيفي',
      'تاريخ التعيين',
      'الرقم القومي',
      'الراتب الأساسي',
      'المتغير',
      'البدلات',
      'الخصومات',
      'المصروفات',
      'الضريبة',
      'التأمين',
      'صافي الراتب',
      'الشهر',
      'السنة',
      'طريقة الدفع',
      'اسم البنك',
      'رقم الحساب',
      'نشط'
    ];

    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    for (var emp in employees) {
      final payroll = payrollMap[emp.id];
      final month = payroll?.month ?? 0;
      final year = payroll?.year ?? 0;
      final netSalary = payroll?.netSalary ?? 0;
      final tax = payroll?.taxAmount ?? 0;
      final insurance = payroll?.insuranceAmount ?? 0;

      sheetObject.appendRow([
        TextCellValue(emp.nameAr),
        TextCellValue(emp.nameEn),
        TextCellValue(emp.department),
        TextCellValue(emp.jobTitle),
        TextCellValue(emp.hireDate),
        TextCellValue(emp.nationalId),
        DoubleCellValue(emp.basicSalary),
        DoubleCellValue(emp.variableSalary),
        DoubleCellValue(emp.allowances),
        DoubleCellValue(emp.deductions),
        DoubleCellValue(emp.expenses),
        DoubleCellValue(tax),
        DoubleCellValue(insurance),
        DoubleCellValue(netSalary),
        IntCellValue(month),
        IntCellValue(year),
        TextCellValue(emp.paymentMethod),
        TextCellValue(emp.bankName),
        TextCellValue(emp.bankAccount),
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
            'المتغير',
            'البدلات',
            'الخصومات',
            'المصروفات',
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
            'Variable Salary',
            'Allowances',
            'Deductions',
            'Expenses',
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
            DoubleCellValue(3000),
            DoubleCellValue(500),
            DoubleCellValue(100),
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
            DoubleCellValue(3000),
            DoubleCellValue(500),
            DoubleCellValue(100),
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

  // ============================================
  // 4. إنشاء سجلات رواتب للموظفين الموجودين
  // ============================================
  Future<int> generatePayrollRecordsFromEmployees({
    int month = 4,
    int year = 2023,
  }) async {
    final employees = await _employeeStorage.getAllEmployees();
    if (employees.isEmpty) {
      throw Exception('لا يوجد موظفين لإنشاء سجلات رواتب لهم');
    }

    // تهيئة TaxService إذا لم يكن موجوداً
    _taxService ??= TaxService();
    await _taxService!.loadSettings();

    final db = await AppDatabase.instance.database;
    int created = 0;

    for (var e in employees) {
      // التحقق من وجود سجل
      final existing = await db.query(
        'payroll_records',
        where: 'employeeId = ? AND month = ? AND year = ?',
        whereArgs: [e.id, month, year],
      );
      if (existing.isNotEmpty) continue;

      // موظف بلا أي مستحقات: لا ننشئ له سجلًا (كان بيتم تعيين أساسي وهمي = 1).
      final basic = e.basicSalary;
      if (basic + e.variableSalary + e.allowances <= 0) continue;

      // ✅ الضريبة والتأمينات والصافي بيتحسبوا بمنطق موحّد (نفس المنطق
      // المستخدم في شاشة المرتبات): لو الموظف "net" بيتم تجميع
      // (gross-up) راتبه تلقائيًا بحيث الشركة هي اللي تتحمّل الضريبة
      // ويوصل الموظف فعليًا للمبلغ المتفق عليه.
      final calc = PayrollCalculationService.calculateFromAmounts(
        basicSalary: basic,
        variableSalary: e.variableSalary,
        allowances: e.allowances,
        deductions: e.deductions,
        salaryType: e.salaryType,
        taxService: _taxService!,
      );

      final record = PayrollRecord(
        id: _uuid.v4(),
        employeeId: e.id,
        employeeNameAr: e.nameAr,
        employeeNameEn: e.nameEn,
        month: month,
        year: year,
        basicSalary: calc.basicSalary,
        variableSalary: calc.variableSalary,
        allowances: calc.allowances,
        deductions: calc.deductions,
        taxAmount: calc.taxAmount,
        insuranceAmount: calc.insuranceAmount,
        netSalary: calc.netSalary,
        generatedAt: DateTime.now(),
        notes: 'تم إنشاؤه تلقائياً من الموظفين الموجودين',
      );

      await db.insert('payroll_records', record.toMap());
      created++;
    }

    return created;
  }
  // lib/services/bulk_import_service.dart

// ... داخل BulkImportService

  /// مسح جميع بيانات الموظفين والرواتب والحضور (بدون حذف الجداول)
  /// يحتفظ بجداول النظام: users, roles, license, activated_devices, app_meta
  Future<int> clearAllData() async {
    final db = await AppDatabase.instance.database;
    int totalDeleted = 0;

    // قائمة الجداول المراد مسحها (مع مراعاة الترتيب بسبب المفاتيح الخارجية)
    final tables = [
      'salary_payments', // يعتمد على payroll_records
      'payroll_records', // يعتمد على employees
      'attendance', // يعتمد على employees
      'employees', // الجدول الرئيسي
    ];

    for (var table in tables) {
      try {
        // حذف جميع الصفوف من الجدول
        final count = await db.delete(table);
        totalDeleted += count;
        debugPrint('✅ تم حذف $count سجل من جدول $table');
      } catch (e) {
        debugPrint('❌ خطأ في حذف جدول $table: $e');
        // إذا فشل الحذف بسبب المفاتيح الخارجية، حاول تعطيل القيود مؤقتاً
        if (e.toString().contains('FOREIGN KEY')) {
          await db.execute('PRAGMA foreign_keys = OFF');
          await db.delete(table);
          await db.execute('PRAGMA foreign_keys = ON');
          debugPrint('✅ تم حذف جدول $table (مع تعطيل المفاتيح الخارجية)');
        }
      }
    }

    // إعادة تعيين الـ auto-increment (إذا كان مستخدماً)
    // SQLite لا يدعم AUTO_INCREMENT مباشرة، لكن يمكن إعادة تعيين الـ sequence
    // ولكننا نستخدم UUID لذا لا حاجة.

    return totalDeleted;
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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import '../database/app_database.dart';
import '../database/employee_storage.dart';
import '../models/employee_model.dart';
import '../models/payroll_record_model.dart';
import '../services/tax_service.dart';
import '../services/payroll_calculation_service.dart';

class BulkImportService {
  final _employeeStorage = EmployeeStorage();
  final _uuid = const Uuid();
  TaxService? _taxService;

  // ============================================
  // 1. الاستيراد من ملف Excel
  // ============================================
  Future<BulkImportResult> importFromExcel() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (file == null) {
        return const BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: true,
          messageKey: 'import_cancelled',
        );
      }

      final fileBytes = await file.readAsBytes();
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

      final headerRow = sheet.row(0);
      if (headerRow.isEmpty) {
        return const BulkImportResult(
          imported: 0,
          errors: [],
          cancelled: false,
          messageKey: 'import_error_no_headers',
        );
      }

      final Map<String, int> columnIndex = {};
      for (int i = 0; i < headerRow.length; i++) {
        final cell = headerRow[i];
        final value = cell?.value?.toString().trim() ?? '';
        if (value.isNotEmpty) columnIndex[value] = i;
      }

      // دوال مساعدة لقراءة البيانات
      String getString(List<Data?> row, String colName) {
        final idx = columnIndex[colName];
        if (idx == null || idx >= row.length) return '';
        final cell = row[idx];
        return cell?.value?.toString().trim() ?? '';
      }

      double getDouble(List<Data?> row, String colName, {double fallback = 0}) {
        final str = getString(row, colName);
        if (str.isEmpty) return fallback;
        final cleaned = str.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(cleaned) ?? fallback;
      }

      bool getBool(List<Data?> row, String colName, {bool fallback = true}) {
        final str = getString(row, colName).toLowerCase();
        if (str.isEmpty) return fallback;
        return str == 'true' || str == '1' || str == 'نعم' || str == 'نشط';
      }

      // ✅ تم إصلاح دالة قراءة التاريخ لتكون آمنة تماماً
      String parseDate(String str) {
        if (str.isEmpty) {
          return DateTime.now().toIso8601String().split('T').first;
        }

        // 1. محاولة القراءة المباشرة (ISO 8601) زي 2023-01-15
        final parsed = DateTime.tryParse(str);
        if (parsed != null) return parsed.toIso8601String().split('T').first;

        // 2. قراءة أرقام الإكسيل التسلسلية (Excel Serial)
        if (double.tryParse(str) != null) {
          final serial = double.parse(str);
          final date =
              DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
          return date.toIso8601String().split('T').first;
        }

        // 3. محاولة القراءة بالـ Regex للصيغ الشائعة
        final patterns = [
          RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$'), // YYYY-MM-DD
          RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$'), // DD/MM/YYYY
        ];

        for (var pattern in patterns) {
          final match = pattern.firstMatch(str);
          if (match != null) {
            try {
              if (pattern.pattern.contains(r'(\d{4})')) {
                final y = int.parse(match.group(1)!);
                final m = int.parse(match.group(2)!);
                final d = int.parse(match.group(3)!);
                return DateTime(y, m, d).toIso8601String().split('T').first;
              } else {
                final d = int.parse(match.group(1)!);
                final m = int.parse(match.group(2)!);
                final y = int.parse(match.group(3)!);
                return DateTime(y, m, d).toIso8601String().split('T').first;
              }
            } catch (_) {}
          }
        }

        // لو كله فشل، نرجع تاريخ النهاردة كـ Fallback
        return DateTime.now().toIso8601String().split('T').first;
      }

      final db = await AppDatabase.instance.database;
      int imported = 0;
      final errors = <ImportRowError>[];

      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        final displayRow = rowIndex + 1;

        if (row.every((cell) =>
            cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        try {
          final nameAr = getString(row, 'الاسم بالعربية');
          final nameEn = getString(row, 'الاسم بالإنجليزية');

          if (nameAr.isEmpty) {
            errors.add(ImportRowError(
                row: displayRow,
                messageKey: 'import_error_name_required',
                details: 'الاسم بالعربية فارغ'));
            continue;
          }

          final department = getString(row, 'القسم');
          final jobTitle = getString(row, 'المسمى الوظيفي');
          final hireDateRaw = getString(row, 'تاريخ التعيين');
          final hireDate =
              parseDate(hireDateRaw); // ✅ هنا بيتم استخدام الدالة الآمنة

          final nationalId = getString(row, 'الرقم القومي');
          final contractType = getString(row, 'نوع العقد');
          final employeeType = getString(row, 'نوع الموظف');

          double basicSalary = getDouble(row, 'الراتب الأساسي');
          final variableSalary = getDouble(row, 'المتغير');
          double allowances = getDouble(row, 'البدلات');
          final deductions = getDouble(row, 'الخصومات');
          final expenses = getDouble(row, 'المصروفات');
          final fixedInsurance =
              getDouble(row, 'تأمينات ثابتة'); // ✅ دعم الحقل الجديد

          if (basicSalary == 0 && allowances > 0) {
            basicSalary = allowances;
            allowances = 0;
          }

          final salaryType = getString(row, 'نوع الراتب').toLowerCase();
          final paymentMethod = getString(row, 'طريقة الدفع').toLowerCase();

          if (salaryType.isNotEmpty &&
              salaryType != 'net' &&
              salaryType != 'gross') {
            errors.add(ImportRowError(
                row: displayRow,
                messageKey: 'import_error_invalid_salary_type',
                details: 'يجب أن يكون net أو gross'));
            continue;
          }

          if (paymentMethod.isNotEmpty &&
              paymentMethod != 'cash' &&
              paymentMethod != 'bank') {
            errors.add(ImportRowError(
                row: displayRow,
                messageKey: 'import_error_invalid_payment_method',
                details: 'يجب أن يكون cash أو bank'));
            continue;
          }

          final bankName = getString(row, 'اسم البنك');
          final bankAccount = getString(row, 'رقم الحساب');
          final bankSwift = getString(row, 'كود Swift');
          final bankIban = getString(row, 'IBAN');

          if (paymentMethod == 'bank' &&
              (bankName.isEmpty || bankAccount.isEmpty)) {
            errors.add(ImportRowError(
                row: displayRow,
                messageKey: 'import_error_bank_required',
                details: 'طريقة الدفع بنك تتطلب اسم البنك ورقم الحساب'));
            continue;
          }

          final isActive = getBool(row, 'نشط', fallback: true);
          final taxAmount = getDouble(row, 'اجمالي ضريبة كسب العمل');
          final insuranceAmount = getDouble(row, 'مبلغ التامين');
          final netAmount = getDouble(row, 'Net_Amount');

          String monthYearStr = getString(row, 'mo');
          int month = 4;
          int year = 2023;
          if (monthYearStr.isNotEmpty && monthYearStr.contains('/')) {
            final parts = monthYearStr.split('/');
            if (parts.length == 2) {
              month = int.tryParse(parts[0]) ?? 4;
              year = int.tryParse(parts[1]) ?? 2023;
            }
          }

          final employee = Employee(
            id: _uuid.v4(),
            nameAr: nameAr,
            nameEn: nameEn.isNotEmpty ? nameEn : nameAr,
            department: department,
            jobTitle: jobTitle,
            nationalId: nationalId,
            hireDate: hireDate,
            contractType: contractType.isNotEmpty ? contractType : 'permanent',
            employeeType: employeeType.isNotEmpty ? employeeType : 'full-time',
            insuranceCode: '',
            insuranceFile: '',
            taxFile: '',
            basicSalary: basicSalary,
            variableSalary: variableSalary,
            allowances: allowances,
            deductions: deductions,
            expenses: expenses,
            fixedInsurance: fixedInsurance, // ✅ تمرير الحقل الجديد
            salaryType: salaryType.isNotEmpty ? salaryType : 'net',
            paymentMethod: paymentMethod.isNotEmpty ? paymentMethod : 'cash',
            bankName: bankName,
            bankAccount: bankAccount,
            bankSwift: bankSwift,
            bankIban: bankIban,
            isActive: isActive,
          );

          await _employeeStorage.insertEmployee(employee);

          double netSalary = netAmount;
          if (netSalary == 0) {
            netSalary = basicSalary +
                variableSalary +
                allowances -
                deductions -
                expenses -
                taxAmount -
                insuranceAmount;
          }

          final payrollRecord = PayrollRecord(
            id: _uuid.v4(),
            employeeId: employee.id,
            employeeNameAr: employee.nameAr,
            employeeNameEn: employee.nameEn,
            month: month,
            year: year,
            basicSalary: basicSalary,
            variableSalary: variableSalary,
            allowances: allowances,
            deductions: deductions,
            taxAmount: taxAmount,
            insuranceAmount: insuranceAmount,
            netSalary: netSalary,
            generatedAt: DateTime.now(),
            notes: 'تم الاستيراد من ملف Excel',
          );

          await db.insert('payroll_records', payrollRecord.toMap());
          imported++;
        } catch (e) {
          errors.add(ImportRowError(
              row: displayRow,
              messageKey: 'import_error_invalid_row',
              details: e.toString()));
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
          messageKey: messageKey);
    } catch (e) {
      return BulkImportResult(
        imported: 0,
        errors: [
          ImportRowError(
              row: 0, messageKey: 'import_error_general', details: e.toString())
        ],
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

    final db = await AppDatabase.instance.database;
    final List<Map<String, dynamic>> payrollMaps =
        await db.query('payroll_records', orderBy: 'year DESC, month DESC');

    final Map<String, PayrollRecord> payrollMap = {};
    for (var map in payrollMaps) {
      final record = PayrollRecord.fromMap(map);
      if (!payrollMap.containsKey(record.employeeId)) {
        payrollMap[record.employeeId] = record;
      }
    }

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Employees & Payroll'];

    final headers = [
      'الاسم بالعربية',
      'الاسم بالإنجليزية',
      'القسم',
      'المسمى الوظيفي',
      'تاريخ التعيين',
      'الرقم القومي',
      'الراتب الأساسي',
      'المتغير',
      'البدلات',
      'الخصومات',
      'المصروفات',
      'الضريبة',
      'التأمين',
      'صافي الراتب',
      'الشهر',
      'السنة',
      'طريقة الدفع',
      'اسم البنك',
      'رقم الحساب',
      'نشط'
    ];

    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    for (var emp in employees) {
      final payroll = payrollMap[emp.id];
      final month = payroll?.month ?? 0;
      final year = payroll?.year ?? 0;
      final netSalary = payroll?.netSalary ?? 0;
      final tax = payroll?.taxAmount ?? 0;
      final insurance = payroll?.insuranceAmount ?? 0;

      sheetObject.appendRow([
        TextCellValue(emp.nameAr),
        TextCellValue(emp.nameEn),
        TextCellValue(emp.department),
        TextCellValue(emp.jobTitle),
        TextCellValue(emp.hireDate),
        TextCellValue(emp.nationalId),
        DoubleCellValue(emp.basicSalary),
        DoubleCellValue(emp.variableSalary),
        DoubleCellValue(emp.allowances),
        DoubleCellValue(emp.deductions),
        DoubleCellValue(emp.expenses),
        DoubleCellValue(tax),
        DoubleCellValue(insurance),
        DoubleCellValue(netSalary),
        IntCellValue(month),
        IntCellValue(year),
        TextCellValue(emp.paymentMethod),
        TextCellValue(emp.bankName),
        TextCellValue(emp.bankAccount),
        TextCellValue(emp.isActive ? 'true' : 'false'),
      ]);
    }

    final excelBytes = excel.encode();
    if (excelBytes == null) throw Exception('فشل إنشاء ملف Excel');

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
            'المتغير',
            'البدلات',
            'الخصومات',
            'المصروفات',
            'تأمينات ثابتة',
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
            'Variable Salary',
            'Allowances',
            'Deductions',
            'Expenses',
            'Fixed Insurance',
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
            'أحمد محمد',
            'Ahmed Mohamed',
            'المبيعات',
            'مدير مبيعات',
            '2023-01-15',
            '12345678901234',
            'permanent',
            'full-time',
            '15000',
            '2000',
            '3000',
            '500',
            '100',
            '0',
            'net',
            'bank',
            'البنك الأهلي',
            '123456789',
            'AHBLEG',
            'EG123456789',
            'true'
          ].map((e) => TextCellValue(e)).toList()
        : [
            'Ahmed Mohamed',
            'Ahmed Mohamed',
            'Sales',
            'Sales Manager',
            '2023-01-15',
            '12345678901234',
            'permanent',
            'full-time',
            '15000',
            '2000',
            '3000',
            '500',
            '100',
            '0',
            'net',
            'bank',
            'National Bank',
            '123456789',
            'AHBLEG',
            'EG123456789',
            'true'
          ].map((e) => TextCellValue(e)).toList();

    sheetObject.appendRow(sampleRow);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('فشل إنشاء ملف النموذج');

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/employee_import_template.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(Uint8List.fromList(bytes));

    return filePath;
  }

  // ============================================
  // 4. إنشاء سجلات رواتب للموظفين الموجودين
  // ============================================
  // ============================================
  // 4. إنشاء أو تحديث سجلات رواتب للموظفين الموجودين
  // ============================================
  Future<int> generatePayrollRecordsFromEmployees({
    int month = 4,
    int year = 2023,
  }) async {
    final employees = await _employeeStorage.getAllEmployees();
    if (employees.isEmpty) {
      throw Exception('لا يوجد موظفين لإنشاء سجلات رواتب لهم');
    }

    _taxService ??= TaxService();
    await _taxService!.loadSettings();

    final db = await AppDatabase.instance.database;
    int processedCount = 0;

    for (var e in employees) {
      final basic = e.basicSalary;
      if (basic + e.variableSalary + e.allowances <= 0) continue;

      // ✅ 1. حساب المرتب مع تمرير fixedInsurance
      final calc = PayrollCalculationService.calculateFromAmounts(
        basicSalary: basic,
        variableSalary: e.variableSalary,
        allowances: e.allowances,
        deductions: e.deductions,
        fixedInsurance: e.fixedInsurance, // 👈 السطر ده كان ناقص
        salaryType: e.salaryType,
        taxService: _taxService!,
      );

      // ✅ 2. نشوف لو فيه سجل قديم عشان نحافظ على الـ ID بتاعه
      final existing = await db.query(
        'payroll_records',
        where: 'employeeId = ? AND month = ? AND year = ?',
        whereArgs: [e.id, month, year],
      );

      final String recordId =
          existing.isNotEmpty ? existing.first['id'] as String : _uuid.v4();

      final record = PayrollRecord(
        id: recordId,
        employeeId: e.id,
        employeeNameAr: e.nameAr,
        employeeNameEn: e.nameEn,
        month: month,
        year: year,
        basicSalary: calc.basicSalary,
        variableSalary: calc.variableSalary,
        allowances: calc.allowances,
        deductions: calc.deductions,
        taxAmount: calc.taxAmount,
        insuranceAmount: calc.insuranceAmount,
        netSalary: calc.netSalary,
        generatedAt: DateTime.now(),
        notes: existing.isNotEmpty
            ? 'تم التحديث التلقائي بناءً على بيانات الموظف'
            : 'تم الإنشاء التلقائي من بيانات الموظف',
      );

      // ✅ 3. السطر السحري: الاستبدال (لو موجود يتحدث، لو مش موجود يتضاف)
      await db.insert(
        'payroll_records',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      processedCount++;
    }

    return processedCount;
  }

  Future<int> clearAllData() async {
    final db = await AppDatabase.instance.database;
    int totalDeleted = 0;
    final tables = [
      'salary_payments',
      'payroll_records',
      'attendance',
      'employees'
    ];

    for (var table in tables) {
      try {
        final count = await db.delete(table);
        totalDeleted += count;
        debugPrint('✅ تم حذف $count سجل من جدول $table');
      } catch (e) {
        debugPrint('❌ خطأ في حذف جدول $table: $e');
        if (e.toString().contains('FOREIGN KEY')) {
          await db.execute('PRAGMA foreign_keys = OFF');
          await db.delete(table);
          await db.execute('PRAGMA foreign_keys = ON');
        }
      }
    }
    return totalDeleted;
  }
}

class ImportRowError {
  final int row;
  final String messageKey;
  final String details;
  const ImportRowError(
      {required this.row, required this.messageKey, this.details = ''});
}

class BulkImportResult {
  final int imported;
  final List<ImportRowError> errors;
  final bool cancelled;
  final String messageKey;

  const BulkImportResult(
      {required this.imported,
      required this.errors,
      required this.cancelled,
      required this.messageKey});
}
