// lib/services/compliance_pdf_service.dart

import 'dart:io';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../database/app_database.dart';

class CompliancePdfService {
  static String _fixArabic(String text) {
    if (text.isEmpty) return text;
    return ArabicReshaper().reshape(text);
  }

  static Future<String?> generateComplianceReport({
    required int month,
    required int year,
    required bool isArabic,
    required String reportType, // 'tax' or 'insurance'
  }) async {
    try {
      final arabicFontData =
          await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final arabicFont = pw.Font.ttf(arabicFontData);
      final pdf = pw.Document();

      final db = await AppDatabase.instance.database;
      final records = await db.query(
        'payroll_records',
        where: 'month = ? AND year = ?',
        whereArgs: [month, year],
      );

      if (records.isEmpty) throw Exception('لا توجد بيانات لهذا الشهر');

      // جلب بيانات الشركة
      final metaRows = await db.query('app_meta');
      String companyName = '';
      for (var r in metaRows) {
        if (r['key'] == (isArabic ? 'company_name_ar' : 'company_name_en')) {
          companyName = r['value'] as String;
        }
      }

      final reportTitle = reportType == 'tax'
          ? (isArabic
              ? 'نموذج إقرار ضريبة كسب العمل'
              : 'Payroll Tax Return Form')
          : (isArabic
              ? 'نموذج بيان التأمينات الاجتماعية'
              : 'Social Insurance Statement');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          theme: pw.ThemeData.withFont(base: arabicFont),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(isArabic ? _fixArabic(companyName) : companyName,
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800)),
                    pw.SizedBox(height: 8),
                    pw.Text(isArabic ? _fixArabic(reportTitle) : reportTitle,
                        style: pw.TextStyle(
                            fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        '${isArabic ? "عن شهر" : "For Month"} $month / $year',
                        style: const pw.TextStyle(
                            fontSize: 14, color: PdfColors.grey)),
                    pw.Divider(color: PdfColors.green800, thickness: 2),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // جدول البيانات
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.green700),
                    children: isArabic
                        ? [
                            _headerCell('الاسم', arabicFont),
                            _headerCell('الأساسي', arabicFont),
                            _headerCell('المتغير', arabicFont),
                            _headerCell('البدلات', arabicFont),
                            _headerCell(
                                reportType == 'tax'
                                    ? 'الوعاء الضريبي'
                                    : 'الأجر التأميني',
                                arabicFont),
                            _headerCell(
                                reportType == 'tax' ? 'الضريبة' : 'حصة الموظف',
                                arabicFont),
                          ]
                        : [
                            _headerCell('Name', arabicFont),
                            _headerCell('Basic', arabicFont),
                            _headerCell('Variable', arabicFont),
                            _headerCell('Allowances', arabicFont),
                            _headerCell(
                                reportType == 'tax' ? 'Taxable' : 'Insurable',
                                arabicFont),
                            _headerCell(
                                reportType == 'tax' ? 'Tax' : 'Employee Share',
                                arabicFont),
                          ],
                  ),
                  ...records.map((r) {
                    final basic = (r['basicSalary'] as num).toDouble();
                    final variable =
                        (r['variableSalary'] as num?)?.toDouble() ?? 0;
                    final allowances = (r['allowances'] as num).toDouble();
                    final tax = (r['taxAmount'] as num?)?.toDouble() ?? 0;
                    final insurance =
                        (r['insuranceAmount'] as num?)?.toDouble() ?? 0;

                    final name =
                        isArabic ? r['employeeNameAr'] : r['employeeNameEn'];

                    return pw.TableRow(
                      children: isArabic
                          ? [
                              _dataCell(_fixArabic(name as String), arabicFont),
                              _dataCell(basic.toStringAsFixed(2), arabicFont),
                              _dataCell(
                                  variable.toStringAsFixed(2), arabicFont),
                              _dataCell(
                                  allowances.toStringAsFixed(2), arabicFont),
                              _dataCell((basic + variable).toStringAsFixed(2),
                                  arabicFont),
                              _dataCell(
                                  reportType == 'tax'
                                      ? tax.toStringAsFixed(2)
                                      : insurance.toStringAsFixed(2),
                                  arabicFont),
                            ]
                          : [
                              _dataCell(name as String, arabicFont),
                              _dataCell(basic.toStringAsFixed(2), arabicFont),
                              _dataCell(
                                  variable.toStringAsFixed(2), arabicFont),
                              _dataCell(
                                  allowances.toStringAsFixed(2), arabicFont),
                              _dataCell((basic + variable).toStringAsFixed(2),
                                  arabicFont),
                              _dataCell(
                                  reportType == 'tax'
                                      ? tax.toStringAsFixed(2)
                                      : insurance.toStringAsFixed(2),
                                  arabicFont),
                            ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      isArabic
                          ? _fixArabic('توقيع المسؤول: _________________')
                          : 'Authorized Signature: _________________',
                      style: pw.TextStyle(font: arabicFont)),
                  pw.Text(
                      isArabic
                          ? _fixArabic(
                              'تاريخ الطباعة: ${DateTime.now().toString().substring(0, 10)}')
                          : 'Print Date: ${DateTime.now().toString().substring(0, 10)}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                ],
              ),
            ];
          },
        ),
      );

      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception('لا يمكن الوصول لمجلد التنزيلات');

      final fileName = '${reportType}_report_${month}_$year.pdf';
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(await pdf.save());
      await OpenFile.open(filePath);
      return filePath;
    } catch (e) {
      print('PDF Error: $e');
      rethrow;
    }
  }

  static pw.Widget _headerCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(
              font: font,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.white),
          textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _dataCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          style: pw.TextStyle(font: font, fontSize: 9),
          textAlign: pw.TextAlign.center),
    );
  }
}
