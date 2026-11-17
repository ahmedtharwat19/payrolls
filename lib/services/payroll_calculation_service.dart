// lib/services/payroll_calculation_service.dart (النسخة المحدثة)

import 'tax_service.dart';
import 'insurance_service.dart';

class PayrollBreakdown {
  final double basicSalary;
  final double variableSalary;
  final double allowances;
  final double deductions;
  final double taxAmount;
  final double insuranceAmount;
  final double companyInsuranceAmount;
  final double netSalary;
  final double grossUpAmount;
  final double attendanceDeduction;
  final double overtimeEarnings;
  final double unpaidLeaveDeduction; // ✅ جديد
  final double penaltyDeduction; // ✅ جديد

  const PayrollBreakdown({
    required this.basicSalary,
    required this.variableSalary,
    required this.allowances,
    required this.deductions,
    required this.taxAmount,
    required this.insuranceAmount,
    required this.netSalary,
    this.companyInsuranceAmount = 0,
    this.grossUpAmount = 0,
    this.attendanceDeduction = 0,
    this.overtimeEarnings = 0,
    this.unpaidLeaveDeduction = 0,
    this.penaltyDeduction = 0,
  });

  double get totalEarned =>
      basicSalary + variableSalary + allowances + overtimeEarnings;
  double get totalDeducted =>
      deductions +
      taxAmount +
      insuranceAmount +
      attendanceDeduction +
      unpaidLeaveDeduction +
      penaltyDeduction;
}

class PayrollCalculationService {
  static const int _maxIterations = 100;
  static const double _epsilon = 0.000001;

  static double round2(double v) => (v * 100).roundToDouble() / 100;

  static PayrollBreakdown calculateFromAmounts({
    required double basicSalary,
    required double variableSalary,
    required double allowances,
    required double deductions,
    required String salaryType,
    required TaxService taxService,
    double fixedInsurance = 0.0,
    bool isInsured = true,
    int lateMinutes = 0,
    int overtimeMinutes = 0,
    int unpaidLeaveDays = 0, // ✅ جديد
    double penaltyAmount = 0.0, // ✅ جديد
  }) {
    final minuteRate = basicSalary / 30 / 8 / 60;
    final lateDeduction = round2(lateMinutes * minuteRate);
    final overtimeEarnings = round2(overtimeMinutes * minuteRate * 1.5);

    // ✅ حساب خصم الإجازة بدون راتب (أجر اليوم = الأساسي / 30)
    final dailyWage = basicSalary / 30;
    final unpaidLeaveDeduction = round2(unpaidLeaveDays * dailyWage);

    // ✅ إجمالي الجزاءات (المالية)
    final penaltyDeduction = round2(penaltyAmount);

    final totalEntered =
        basicSalary + variableSalary + allowances + overtimeEarnings;
    final totalDeductions =
        deductions + lateDeduction + unpaidLeaveDeduction + penaltyDeduction;

    if (totalEntered <= 0) {
      return PayrollBreakdown(
        basicSalary: basicSalary,
        variableSalary: variableSalary,
        allowances: allowances,
        deductions: totalDeductions,
        taxAmount: 0,
        insuranceAmount: 0,
        netSalary: round2(totalEntered - totalDeductions),
        attendanceDeduction: lateDeduction,
        overtimeEarnings: overtimeEarnings,
        unpaidLeaveDeduction: unpaidLeaveDeduction,
        penaltyDeduction: penaltyDeduction,
      );
    }

    if (salaryType == 'net') {
      return _calculateNet(
        basicSalary: basicSalary,
        variableSalary: variableSalary,
        allowances: allowances,
        deductions: deductions,
        totalEntered: totalEntered,
        taxService: taxService,
        fixedInsurance: fixedInsurance,
        isInsured: isInsured,
        lateDeduction: lateDeduction,
        overtimeEarnings: overtimeEarnings,
        unpaidLeaveDeduction: unpaidLeaveDeduction,
        penaltyDeduction: penaltyDeduction,
      );
    }

    final s = _statutory(
      insurableWage: basicSalary + variableSalary,
      totalEarnings: totalEntered,
      taxService: taxService,
      fixedInsurance: fixedInsurance,
      isInsured: isInsured,
    );
    final tax = round2(s.tax);
    final ins = round2(s.employeeInsurance);

    return PayrollBreakdown(
      basicSalary: basicSalary,
      variableSalary: variableSalary,
      allowances: allowances,
      deductions: deductions,
      taxAmount: tax,
      insuranceAmount: ins,
      companyInsuranceAmount: round2(s.companyInsurance),
      netSalary: round2(totalEntered - totalDeductions - tax - ins),
      attendanceDeduction: lateDeduction,
      overtimeEarnings: overtimeEarnings,
      unpaidLeaveDeduction: unpaidLeaveDeduction,
      penaltyDeduction: penaltyDeduction,
    );
  }

  static PayrollBreakdown _calculateNet({
    required double basicSalary,
    required double variableSalary,
    required double allowances,
    required double deductions,
    required double totalEntered,
    required TaxService taxService,
    required double fixedInsurance,
    required bool isInsured,
    required double lateDeduction,
    required double overtimeEarnings,
    required double unpaidLeaveDeduction,
    required double penaltyDeduction,
  }) {
    double netAfterStatutory(double x) {
      final s = _statutory(
        insurableWage: basicSalary + variableSalary + x,
        totalEarnings: totalEntered + x,
        taxService: taxService,
        fixedInsurance: fixedInsurance,
        isInsured: isInsured,
      );
      return (totalEntered + x) - s.tax - s.employeeInsurance;
    }

    double low = 0;
    double high = totalEntered * 0.5 + 5000;
    var guard = 0;
    while (netAfterStatutory(high) < totalEntered && guard < 30) {
      high *= 2;
      guard++;
    }

    for (var i = 0; i < _maxIterations && (high - low) > _epsilon; i++) {
      final mid = (low + high) / 2;
      if (netAfterStatutory(mid) < totalEntered) {
        low = mid;
      } else {
        high = mid;
      }
    }

    final x = high;
    final s = _statutory(
      insurableWage: basicSalary + variableSalary + x,
      totalEarnings: totalEntered + x,
      taxService: taxService,
      fixedInsurance: fixedInsurance,
      isInsured: isInsured,
    );
    final tax = round2(s.tax);
    final ins = round2(s.employeeInsurance);
    final grossUp = round2(tax + ins);

    return PayrollBreakdown(
      basicSalary: basicSalary + grossUp,
      variableSalary: variableSalary,
      allowances: allowances,
      deductions: deductions,
      taxAmount: tax,
      insuranceAmount: ins,
      companyInsuranceAmount: round2(s.companyInsurance),
      grossUpAmount: grossUp,
      netSalary: round2(totalEntered -
          deductions -
          lateDeduction -
          unpaidLeaveDeduction -
          penaltyDeduction),
      attendanceDeduction: lateDeduction,
      overtimeEarnings: overtimeEarnings,
      unpaidLeaveDeduction: unpaidLeaveDeduction,
      penaltyDeduction: penaltyDeduction,
    );
  }

  static _Statutory _statutory({
    required double insurableWage,
    required double totalEarnings,
    required TaxService taxService,
    required double fixedInsurance,
    required bool isInsured,
  }) {
    final ins = InsuranceService.calculateInsurance(
      basicSalary: insurableWage,
      fixedInsurance: fixedInsurance,
      isInsured: isInsured,
    );
    final employeeIns = ins['employee_share'] ?? 0;
    final tax = taxService.calculateMonthlyTax(
      totalEarnings,
      monthlyInsurance: employeeIns,
    );
    return _Statutory(
      tax: tax,
      employeeInsurance: employeeIns,
      companyInsurance: ins['company_share'] ?? 0,
    );
  }
}

class _Statutory {
  final double tax;
  final double employeeInsurance;
  final double companyInsurance;
  const _Statutory({
    required this.tax,
    required this.employeeInsurance,
    required this.companyInsurance,
  });
}
