/* // lib/services/pdf_export_service.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  static Future<void> exportPayrollReport(
    List<Map<String, dynamic>> employees, {
    String title = 'Payroll Report',
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // العنوان
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey,
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // ✅ الجدول
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 1,
                  ),
                  children: [
                    // ✅ رأس الجدول - بدون headerDecoration
                    pw.TableRow(
                      children: [
                        _buildHeaderCell('Name'),
                        _buildHeaderCell('Department'),
                        _buildHeaderCell('Basic Salary'),
                        _buildHeaderCell('Allowance'),
                        _buildHeaderCell('Deduction'),
                        _buildHeaderCell('Tax'),
                        _buildHeaderCell('Insurance'),
                        _buildHeaderCell('Net Salary'),
                      ],
                    ),
                    // ✅ صفوف البيانات
                    ...employees.map((emp) {
                      return pw.TableRow(
                        children: [
                          _buildDataCell(emp['name'] ?? ''),
                          _buildDataCell(emp['department'] ?? ''),
                          _buildDataCell(emp['basicSalary']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(emp['allowances']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(emp['deductions']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(emp['tax']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(emp['insurance']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(emp['netSalary']?.toStringAsFixed(2) ?? '0.00'),
                        ],
                      );
                    }),
                  ],
                ),
                
                pw.SizedBox(height: 20),
                
                // ✅ الإجماليات
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Employees: ${employees.length}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Total Salary: ${_calculateTotal(employees, 'netSalary').toStringAsFixed(2)} EGP',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'payroll_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      color: PdfColors.green,
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          color: PdfColors.white,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildDataCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static double _calculateTotal(List<Map<String, dynamic>> employees, String key) {
    double total = 0;
    for (var emp in employees) {
      total += (emp[key] as double?) ?? 0;
    }
    return total;
  }
} */
// lib/services/pdf_export_service.dart
/* 
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class PdfExportService {
  static Future<String?> exportPayrollReport(
    List<Map<String, dynamic>> employees, {
    String title = 'Payroll Report',
  }) async {
    try {
      if (employees.isEmpty) {
        throw Exception('لا توجد بيانات لعمل التقرير');
      }

      // تحميل الخط العربي
      final arabicFontData =
          await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final arabicFont = pw.Font.ttf(arabicFontData);

      // تحميل خط لاتيني كاحتياطي
      final latinFontData =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final latinFont = pw.Font.ttf(latinFontData);

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: arabicFont,
            fontFallback: [latinFont],
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // العنوان
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey,
                  ),
                ),
                pw.SizedBox(height: 20),

                // ✅ الجدول
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 1,
                  ),
                  children: [
                    // رأس الجدول
                    pw.TableRow(
                      children: [
                        _buildHeaderCell('Name'),
                        _buildHeaderCell('Department'),
                        _buildHeaderCell('Basic Salary'),
                        _buildHeaderCell('Allowance'),
                        _buildHeaderCell('Deduction'),
                        _buildHeaderCell('Tax'),
                        _buildHeaderCell('Insurance'),
                        _buildHeaderCell('Net Salary'),
                      ],
                    ),
                    // صفوف البيانات
                    ...employees.map((emp) {
                      return pw.TableRow(
                        children: [
                          _buildDataCell(emp['name'] ?? ''),
                          _buildDataCell(emp['department'] ?? ''),
                          _buildDataCell(
                              emp['basicSalary']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['allowances']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['deductions']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['tax']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['insurance']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['netSalary']?.toStringAsFixed(2) ?? '0.00'),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 20),

                // الإجماليات
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Employees: ${employees.length}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Total Salary: ${_calculateTotal(employees, 'netSalary').toStringAsFixed(2)} EGP',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // حفظ الملف في Downloads
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('لا يمكن الوصول إلى مجلد Downloads');
      }

      final fileName =
          'payroll_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // فتح الملف
      await OpenFile.open(filePath);

      return filePath;
    } catch (e) {
      rethrow;
    }
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      color: PdfColors.green,
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          color: PdfColors.white,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildDataCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static double _calculateTotal(
      List<Map<String, dynamic>> employees, String key) {
    double total = 0;
    for (var emp in employees) {
      total += (emp[key] as double?) ?? 0;
    }
    return total;
  }
}
 */
// lib/services/pdf_export_service.dart

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class PdfExportService {
  static Future<String?> exportPayrollReport(
    List<Map<String, dynamic>> employees, {
    String title = 'Payroll Report',
  }) async {
    try {
      if (employees.isEmpty) {
        throw Exception('لا توجد بيانات لعمل التقرير');
      }

      // تحميل الخط العربي
      final arabicFontData =
          await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final arabicFont = pw.Font.ttf(arabicFontData);

      // تحميل خط لاتيني كاحتياطي
      final latinFontData =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final latinFont = pw.Font.ttf(latinFontData);

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: arabicFont,
            fontFallback: [latinFont],
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey300, width: 1),
                  children: [
                    pw.TableRow(
                      children: [
                        _buildHeaderCell('Name'),
                        _buildHeaderCell('Department'),
                        _buildHeaderCell('Basic Salary'),
                        _buildHeaderCell('Allowance'),
                        _buildHeaderCell('Deduction'),
                        _buildHeaderCell('Tax'),
                        _buildHeaderCell('Insurance'),
                        _buildHeaderCell('Net Salary'),
                      ],
                    ),
                    ...employees.map((emp) {
                      return pw.TableRow(
                        children: [
                          _buildDataCell(emp['name'] ?? ''),
                          _buildDataCell(emp['department'] ?? ''),
                          _buildDataCell(
                              emp['basicSalary']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['allowances']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['deductions']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['tax']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['insurance']?.toStringAsFixed(2) ?? '0.00'),
                          _buildDataCell(
                              emp['netSalary']?.toStringAsFixed(2) ?? '0.00'),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Employees: ${employees.length}',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Total Salary: ${_calculateTotal(employees, 'netSalary').toStringAsFixed(2)} EGP',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('لا يمكن الوصول إلى مجلد Downloads');
      }

      final fileName =
          'payroll_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      await OpenFile.open(filePath);

      return filePath;
    } catch (e) {
      rethrow;
    }
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      color: PdfColors.green,
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
            color: PdfColors.white),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildDataCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static double _calculateTotal(
      List<Map<String, dynamic>> employees, String key) {
    double total = 0;
    for (var emp in employees) {
      total += (emp[key] as double?) ?? 0;
    }
    return total;
  }
}
