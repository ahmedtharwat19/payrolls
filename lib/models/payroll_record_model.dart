import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// راتب موظف واحد في شهر واحد - بيتولّد مرة واحدة لكل موظف/شهر (فريد).
class PayrollRecord {
  final String id;
  final String employeeId;
  final String employeeNameAr;
  final String employeeNameEn;
  final int month; // 1-12
  final int year;
  final double basicSalary;
  final double variableSalary;
  final double allowances;
  final double deductions;
  final double taxAmount;
  final double insuranceAmount;
  final double netSalary;
  final DateTime generatedAt;
  final String notes;

  const PayrollRecord({
    required this.id,
    required this.employeeId,
    required this.employeeNameAr,
    required this.employeeNameEn,
    required this.month,
    required this.year,
    required this.basicSalary,
    this.variableSalary = 0,
    required this.allowances,
    required this.deductions,
    required this.taxAmount,
    required this.insuranceAmount,
    required this.netSalary,
    required this.generatedAt,
    this.notes = '',
  });

  /// إجمالي المستحق = الأساسي + المتغيّر + البدلات (قبل أي خصم)
  double get totalEarned => basicSalary + variableSalary + allowances;

  /// إجمالي المستقطع = الخصومات العامة + الضريبة + التأمينات
  double get totalDeducted => deductions + taxAmount + insuranceAmount;

  String getDisplayName(BuildContext context) {
    final locale = EasyLocalization.of(context)?.locale;
    if (locale?.languageCode == 'ar') {
      return employeeNameAr.isNotEmpty ? employeeNameAr : employeeNameEn;
    } else {
      return employeeNameEn.isNotEmpty ? employeeNameEn : employeeNameAr;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeId': employeeId,
        'employeeNameAr': employeeNameAr,
        'employeeNameEn': employeeNameEn,
        'month': month,
        'year': year,
        'basicSalary': basicSalary,
        'variableSalary': variableSalary,
        'allowances': allowances,
        'deductions': deductions,
        'taxAmount': taxAmount,
        'insuranceAmount': insuranceAmount,
        'netSalary': netSalary,
        'generatedAt': generatedAt.toIso8601String(),
        'notes': notes,
      };

  factory PayrollRecord.fromMap(Map<String, dynamic> map) => PayrollRecord(
        id: map['id'] as String,
        employeeId: map['employeeId'] as String,
        employeeNameAr: map['employeeNameAr'] as String? ?? '',
        employeeNameEn: map['employeeNameEn'] as String? ?? '',
        month: map['month'] as int,
        year: map['year'] as int,
        basicSalary: (map['basicSalary'] as num).toDouble(),
        variableSalary: (map['variableSalary'] as num?)?.toDouble() ?? 0,
        allowances: (map['allowances'] as num).toDouble(),
        deductions: (map['deductions'] as num).toDouble(),
        taxAmount: (map['taxAmount'] as num).toDouble(),
        insuranceAmount: (map['insuranceAmount'] as num).toDouble(),
        netSalary: (map['netSalary'] as num).toDouble(),
        generatedAt: DateTime.parse(map['generatedAt'] as String),
        notes: map['notes'] as String? ?? '',
      );
}
