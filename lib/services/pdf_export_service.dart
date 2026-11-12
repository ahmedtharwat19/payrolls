// lib/services/pdf_export_service.dart

import 'dart:io';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class PdfExportService {
  static String _fixArabic(String text) {
    if (text.isEmpty) {
      return text;
    }
    return ArabicReshaper().reshape(text);
  }

  static Future<String?> exportPayrollReport(
    List<Map<String, dynamic>> employees, {
    String? title,
    bool isArabic = false,
    bool isBankTransfer = false,
    String? companyNameAr,
    String? companyNameEn,
    String? companyAddressAr,
    String? companyAddressEn,
    String? companyPhone,
  }) async {
    try {
      if (employees.isEmpty) {
        throw Exception('لا توجد بيانات لعمل التقرير');
      }

      final arabicFontData =
          await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final arabicFont = pw.Font.ttf(arabicFontData);

      final pdf = pw.Document();
      final reportTitle =
          title ?? (isArabic ? 'كشف المرتبات' : 'Payroll Report');

      // ✅ 1. حساب نسبة الصرف الإجمالية
      final totalNet = employees.fold(
          0.0, (sum, e) => sum + ((e['netSalary'] as num?) ?? 0.0));
      final totalPaid =
          employees.fold(0.0, (sum, e) => sum + ((e['paid'] as num?) ?? 0.0));
      final paidPercent = totalNet > 0 ? (totalPaid / totalNet) * 100 : 0.0;

      // لو النسبة 99.9% أو أكتر، نعتبرها مدفوعة بالكامل
      final isFullyPaid = paidPercent >= 99.9;
      // لو فيه أي مبلغ مدفوع، نعتبره كشف صرف
      final isPaymentReceipt = paidPercent > 0.01;

      // ✅ 2. تجهيز نص حالة الدفع للهيدر
      String paymentStatusText = '';
      if (isFullyPaid) {
        paymentStatusText =
            isArabic ? 'تم صرف الرواتب بالكامل (100%)' : 'Fully Paid (100%)';
      } else if (isPaymentReceipt) {
        final formattedPercent =
            paidPercent.toStringAsFixed(1).replaceAll('.0', '');
        paymentStatusText = isArabic
            ? 'تم صرف نسبة $formattedPercent% من إجمالي الرواتب'
            : 'Paid $formattedPercent% of total salaries';
      }

      final finalCompanyName = isArabic ? companyNameAr : companyNameEn;
      final finalCompanyAddress =
          isArabic ? companyAddressAr : companyAddressEn;

      String finalAddressLine = finalCompanyAddress ?? '';
      if (companyPhone != null && companyPhone.isNotEmpty) {
        finalAddressLine +=
            finalAddressLine.isNotEmpty ? ' | $companyPhone' : companyPhone;
      }

      // ✅ 3. تجهيز الأعمدة
      List<String> headers;
      if (isBankTransfer) {
        headers = isArabic
            ? ['القيمة', 'IBAN', 'رقم الحساب', 'اسم البنك', 'الاسم']
            : ['Amount', 'IBAN', 'Account Number', 'Bank Name', 'Name'];
      } else {
        if (isArabic) {
          headers = [
            'المدفوع',
            'الصافي',
            'التأمين',
            'الضريبة',
            'الخصومات',
            'البدلات',
            'الأساسي',
            'القسم',
            'الاسم'
          ];
          // إخفاء المتبقي لو هو إيصال صرف
          if (!isPaymentReceipt) headers.insert(0, 'المتبقي');
        } else {
          headers = [
            'Name',
            'Department',
            'Basic Salary',
            'Allowance',
            'Deduction',
            'Tax',
            'Insurance',
            'Net Salary',
            'Paid'
          ];
          if (!isPaymentReceipt) headers.add('Remaining');
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          theme: pw.ThemeData.withFont(base: arabicFont),
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (finalCompanyName != null &&
                          finalCompanyName.isNotEmpty) ...[
                        pw.Text(
                          isArabic
                              ? _fixArabic(finalCompanyName)
                              : finalCompanyName,
                          style: pw.TextStyle(
                              font: arabicFont,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800),
                        ),
                      ],
                      if (finalAddressLine.isNotEmpty) ...[
                        pw.Text(
                          isArabic
                              ? _fixArabic(finalAddressLine)
                              : finalAddressLine,
                          style: pw.TextStyle(
                              font: arabicFont,
                              fontSize: 10,
                              color: PdfColors.grey700),
                        ),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        isArabic ? _fixArabic(reportTitle) : reportTitle,
                        style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),

                      // ✅ عرض حالة الدفع في الهيدر
                      if (paymentStatusText.isNotEmpty) ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: isFullyPaid
                                ? PdfColors.green100
                                : PdfColors.amber100,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            isArabic
                                ? _fixArabic(paymentStatusText)
                                : paymentStatusText,
                            style: pw.TextStyle(
                              font: arabicFont,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: isFullyPaid
                                  ? PdfColors.green800
                                  : PdfColors.orange800,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                      ],

                      pw.Text(
                        'Generated: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                        style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 10,
                            color: PdfColors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.green800, thickness: 2),
              pw.SizedBox(height: 10),

              // ✅ 4. بناء الجدول
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.green700),
                    children: headers
                        .map((h) => _buildHeaderCell(h, arabicFont, isArabic))
                        .toList(),
                  ),
                  ...employees.map((emp) {
                    List<String> rowData;

                    if (isBankTransfer) {
                      rowData = isArabic
                          ? [
                              _formatNum(emp['netSalary']),
                              emp['bankIban']?.toString() ?? '',
                              emp['bankAccount']?.toString() ?? '',
                              _fixArabic(emp['bankName']?.toString() ?? ''),
                              _fixArabic(emp['name']?.toString() ?? ''),
                            ]
                          : [
                              emp['name']?.toString() ?? '',
                              emp['bankName']?.toString() ?? '',
                              emp['bankAccount']?.toString() ?? '',
                              emp['bankIban']?.toString() ?? '',
                              _formatNum(emp['netSalary']),
                            ];
                    } else {
                      if (isArabic) {
                        rowData = [
                          _formatNum(emp['paid']),
                          _formatNum(emp['netSalary']),
                          _formatNum(emp['insurance']),
                          _formatNum(emp['tax']),
                          _formatNum(emp['deductions']),
                          _formatNum(emp['allowances']),
                          _formatNum(emp['basicSalary']),
                          _fixArabic(emp['department']?.toString() ?? ''),
                          _fixArabic(emp['name']?.toString() ?? ''),
                        ];
                        if (!isPaymentReceipt) {
                          rowData.insert(0, _formatNum(emp['remaining']));
                        }
                      } else {
                        rowData = [
                          emp['name']?.toString() ?? '',
                          emp['department']?.toString() ?? '',
                          _formatNum(emp['basicSalary']),
                          _formatNum(emp['allowances']),
                          _formatNum(emp['deductions']),
                          _formatNum(emp['tax']),
                          _formatNum(emp['insurance']),
                          _formatNum(emp['netSalary']),
                          _formatNum(emp['paid']),
                        ];
                        if (!isPaymentReceipt) {
                          rowData.add(_formatNum(emp['remaining']));
                        }
                      }
                    }

                    return pw.TableRow(
                      children: rowData
                          .map((data) =>
                              _buildDataCell(data, arabicFont, isArabic))
                          .toList(),
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // ✅ 5. الإجماليات
              pw.Container(
                alignment: isArabic
                    ? pw.Alignment.centerLeft
                    : pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: isArabic
                      ? pw.CrossAxisAlignment.start
                      : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      isArabic
                          ? _fixArabic('إجمالي الموظفين: ${employees.length}')
                          : 'Total Employees: ${employees.length}',
                      style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      isArabic
                          ? _fixArabic(
                              'إجمالي الصافي: ${totalNet.toStringAsFixed(2)} EGP')
                          : 'Total Net: ${totalNet.toStringAsFixed(2)} EGP',
                      style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    if (isPaymentReceipt)
                      pw.Text(
                        isArabic
                            ? _fixArabic(
                                'إجمالي المدفوع: ${totalPaid.toStringAsFixed(2)} EGP')
                            : 'Total Paid: ${totalPaid.toStringAsFixed(2)} EGP',
                        style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800),
                      ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('لا يمكن الوصول إلى مجلد التنزيلات');
      }

      final fileName =
          'payroll_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(filePath);
      return filePath;
    } catch (e) {
      print('PDF Export Error: $e');
      rethrow;
    }
  }

  static String _formatNum(dynamic value) {
    if (value == null) return '0.00';
    if (value is num) return value.toStringAsFixed(2);
    final parsed = double.tryParse(value.toString());
    return parsed != null ? parsed.toStringAsFixed(2) : '0.00';
  }

  static pw.Widget _buildHeaderCell(String text, pw.Font font, bool isArabic) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        isArabic ? _fixArabic(text) : text,
        style: pw.TextStyle(
            font: font,
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
            color: PdfColors.white),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildDataCell(String text, pw.Font font, bool isArabic) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
