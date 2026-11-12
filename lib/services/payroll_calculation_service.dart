// lib/services/payroll_calculation_service.dart
import 'tax_service.dart';
import 'insurance_service.dart';

/// ناتج احتساب راتب شهري لموظف واحد.
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
  });

  double get totalEarned => basicSalary + variableSalary + allowances;
  double get totalDeducted => deductions + taxAmount + insuranceAmount;
}

/// مصدر واحد لحساب الضريبة والتأمينات والصافي في كل التطبيق.
class PayrollCalculationService {
  static const int _maxIterations = 100;
  static const double _epsilon = 0.000001;

  /// تقريب لأقرب قرش.
  static double round2(double v) => (v * 100).roundToDouble() / 100;

  static PayrollBreakdown calculateFromAmounts({
    required double basicSalary,
    required double variableSalary,
    required double allowances,
    required double deductions,
    required String salaryType,
    required TaxService taxService,
    double fixedInsurance = 0.0, // ✅ تمت إضافة التأمينات الثابتة هنا
  }) {
    final entered = basicSalary + variableSalary + allowances;

    if (entered <= 0) {
      return PayrollBreakdown(
        basicSalary: basicSalary,
        variableSalary: variableSalary,
        allowances: allowances,
        deductions: deductions,
        taxAmount: 0,
        insuranceAmount: 0,
        netSalary: round2(entered - deductions),
      );
    }

    if (salaryType == 'net') {
      return _calculateNet(
        basicSalary: basicSalary,
        variableSalary: variableSalary,
        allowances: allowances,
        deductions: deductions,
        entered: entered,
        taxService: taxService,
        fixedInsurance: fixedInsurance, // ✅ تمرير القيمة
      );
    }

    // ---- النوع "gross" ----
    final s = _statutory(
      insurableWage: basicSalary + variableSalary,
      totalEarnings: entered,
      taxService: taxService,
      fixedInsurance: fixedInsurance, // ✅ تمرير القيمة
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
      netSalary: round2(entered - deductions - tax - ins),
    );
  }

  static PayrollBreakdown _calculateNet({
    required double basicSalary,
    required double variableSalary,
    required double allowances,
    required double deductions,
    required double entered,
    required TaxService taxService,
    required double fixedInsurance, // ✅ إضافة البارامتر
  }) {
    // الصافي بعد الضريبة والتأمين لو رفعنا الأساسي بمقدار x.
    double netAfterStatutory(double x) {
      final s = _statutory(
        insurableWage: basicSalary + variableSalary + x,
        totalEarnings: entered + x,
        taxService: taxService,
        fixedInsurance: fixedInsurance, // ✅ تمرير القيمة
      );
      return (entered + x) - s.tax - s.employeeInsurance;
    }

    double low = 0;
    double high = entered * 0.5 + 5000;
    var guard = 0;
    while (netAfterStatutory(high) < entered && guard < 30) {
      high *= 2;
      guard++;
    }

    for (var i = 0; i < _maxIterations && (high - low) > _epsilon; i++) {
      final mid = (low + high) / 2;
      if (netAfterStatutory(mid) < entered) {
        low = mid;
      } else {
        high = mid;
      }
    }

    final x = high;
    final s = _statutory(
      insurableWage: basicSalary + variableSalary + x,
      totalEarnings: entered + x,
      taxService: taxService,
      fixedInsurance: fixedInsurance, // ✅ تمرير القيمة
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
      // الموظف يستلم المبلغ المتفق عليه بالظبط بعد أي استقطاعات شخصية.
      netSalary: round2(entered - deductions),
    );
  }

  static _Statutory _statutory({
    required double insurableWage,
    required double totalEarnings,
    required TaxService taxService,
    required double fixedInsurance, // ✅ إضافة البارامتر هنا
  }) {
    final ins = InsuranceService.calculateInsurance(
      basicSalary: insurableWage,
      fixedInsurance: fixedInsurance, // ✅ تمرير القيمة لدالة التأمينات
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
