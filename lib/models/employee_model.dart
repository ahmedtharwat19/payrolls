// lib/models/employee_model.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';


class Employee {
  final String id;
  final String nameAr;
  final String nameEn;
  final String department;
  final String jobTitle;
  final String nationalId;
  final String hireDate;
  final String? resignationDate; // ✅ تاريخ ترك الوظيفة (اختياري)
  final String contractType;
  final String employeeType;
  final String insuranceCode;
  final String insuranceFile;
  final String taxFile;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final String salaryType; // 'net' or 'gross'
  final String paymentMethod; // 'cash' or 'bank'
  final bool isActive;

  final String bankName;
  final String bankAccount;
  final String bankSwift;
  final String bankIban;

  Employee({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.department,
    required this.jobTitle,
    required this.nationalId,
    required this.hireDate,
    this.resignationDate,
    required this.contractType,
    required this.employeeType,
    required this.insuranceCode,
    required this.insuranceFile,
    required this.taxFile,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.salaryType,
    required this.paymentMethod,
    this.isActive = true,
    this.bankName = '',
    this.bankAccount = '',
    this.bankSwift = '',
    this.bankIban = '',
  });

  String getDisplayName(BuildContext context) {
    final locale = EasyLocalization.of(context)?.locale;
    if (locale?.languageCode == 'ar') {
      return nameAr.isNotEmpty ? nameAr : nameEn;
    } else {
      return nameEn.isNotEmpty ? nameEn : nameAr;
    }
  }
  
  
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      nameAr: map['nameAr'] as String,
      nameEn: map['nameEn'] as String,
      department: map['department'] as String,
      jobTitle: map['jobTitle'] as String,
      nationalId: map['nationalId'] as String,
      hireDate: map['hireDate'] as String,
      resignationDate: map['resignationDate'] as String?,
      contractType: map['contractType'] as String,
      employeeType: map['employeeType'] as String,
      insuranceCode: map['insuranceCode'] as String,
      insuranceFile: map['insuranceFile'] as String,
      taxFile: map['taxFile'] as String,
      basicSalary: (map['basicSalary'] as num).toDouble(),
      allowances: (map['allowances'] as num).toDouble(),
      deductions: (map['deductions'] as num).toDouble(),
      salaryType: map['salaryType'] as String,
      paymentMethod: map['paymentMethod'] as String,
      isActive: (map['isActive'] as int) == 1,
      bankName: map['bankName'] as String? ?? '',
      bankAccount: map['bankAccount'] as String? ?? '',
      bankSwift: map['bankSwift'] as String? ?? '',
      bankIban: map['bankIban'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'department': department,
      'jobTitle': jobTitle,
      'nationalId': nationalId,
      'hireDate': hireDate,
      'resignationDate': resignationDate,
      'contractType': contractType,
      'employeeType': employeeType,
      'insuranceCode': insuranceCode,
      'insuranceFile': insuranceFile,
      'taxFile': taxFile,
      'basicSalary': basicSalary,
      'allowances': allowances,
      'deductions': deductions,
      'salaryType': salaryType,
      'paymentMethod': paymentMethod,
      'isActive': isActive ? 1 : 0,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'bankSwift': bankSwift,
      'bankIban': bankIban,
    };
  }

  Employee copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? department,
    String? jobTitle,
    String? nationalId,
    String? hireDate,     
    String? resignationDate,
    String? contractType,
    String? employeeType,
    String? insuranceCode,
    String? insuranceFile,
    String? taxFile,
    double? basicSalary,
    double? allowances,
    double? deductions,
    String? salaryType,
    String? paymentMethod,
    bool? isActive,
    String? bankName,
    String? bankAccount,
    String? bankSwift,
    String? bankIban,
  }) {
    return Employee(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      nationalId: nationalId ?? this.nationalId,
      hireDate: hireDate ?? this.hireDate,
      resignationDate: resignationDate ?? this.resignationDate,
      contractType: contractType ?? this.contractType,
      employeeType: employeeType ?? this.employeeType,
      insuranceCode: insuranceCode ?? this.insuranceCode,
      insuranceFile: insuranceFile ?? this.insuranceFile,
      taxFile: taxFile ?? this.taxFile,
      basicSalary: basicSalary ?? this.basicSalary,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      salaryType: salaryType ?? this.salaryType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isActive: isActive ?? this.isActive,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      bankSwift: bankSwift ?? this.bankSwift,
      bankIban: bankIban ?? this.bankIban,
    );
  }
}
