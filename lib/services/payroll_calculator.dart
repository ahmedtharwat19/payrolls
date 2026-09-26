// lib/services/payroll_calculator.dart
import 'tax_service.dart';
import 'insurance_service.dart';

/// نتيجة احتساب مرتب موظف واحد لشهر واحد.
class PayrollCalculationResult {
  final double basicSalary;
  final double variableSalary;
  final double allowances;
  final double deductions;
  final double totalEarned;
  final double taxAmount;
  final double insuranceAmount;
  final double totalDeducted;
  final double netSalary;

  const PayrollCalculationResult({
    required this.basicSalary,
    required this.variableSalary,
    required this.allowances,
    required this.deductions,
    required this.totalEarned,
    required this.taxAmount,
    required this.insuranceAmount,
    required this.totalDeducted,
    required this.netSalary,
  });
}

/// يحسب راتب الموظف مع مراعاة نوع الراتب (صافي/إجمالي)، عشان يبقى نفس
/// المنطق مستخدم في كل مكان (شاشة المرتبات، تصدير PDF، توليد المرتبات الشهري).
///
/// - **gross**: الضريبة والتأمين يُحسبان على الأساسي فقط، ويُخصمان من إجمالي
///   المستحق للوصول للصافي. (نفس السلوك الحالي، بدون تغيير).
/// - **net**: القيمة المدخلة (أساسي + متغير + بدلات) هي الراتب المتفق عليه
///   ويُفترض أن يصل فعليًا للموظف بالكامل. الشركة هي اللي بتتحمل الضريبة
///   والتأمين، فبيتم تلقائيًا "تصعيد" (gross-up) الراتب الأساسي بحيث بعد ما
///   تتحسب الضريبة والتأمين على القيمة المُصعّدة ويتم خصمهم، يوصل الصافي
///   لنفس القيمة المتفق عليها بالظبط (مع بقاء الخصومات العادية زي السلف تتخصم
///   من الصافي زي ما هي، لأنها مش جزء من اتفاق الراتب).
class PayrollCalculator {
  static PayrollCalculationResult calculate({
    required double basicSalary,
    required double variableSalary,
    required double allowances,
    required double deductions,
    required String salaryType,
    required TaxService taxService,
  }) {
    if (salaryType == 'net') {
      return _calculateNet(
        basicSalary: basicSalary,
        variableSalary: variableSalary,
        allowances: allowances,
        deductions: deductions,
        taxService: taxService,
      );
    }
    return _calculateGross(
      basicSalary: basicSalary,
      variableSalary: variableSalary,
      allowances: allowances,
      deductions: deductions,
      taxService: taxService,
    );
  }

  static PayrollCalculationResult _calculateGross({
    required double basicSalary,
    required double variableSalary,
    required double allowances,
    required double deductions,
    required TaxService taxService,
  }) {
    final totalEarned = basicSalary + variableSalary + allowances;
    const taxableIsBasic = true; // للتوضيح فقط
    final taxable = taxableIsBasic ? basicSalary : totalEarned;
    final tax = taxService.calculateMonthlyTax(taxable);
    final insurance = InsuranceService.calculateInsurance(
        basicSalary: taxable)['employee_share']!;
    final totalDeducted = deductions + tax + insurance;
    final net = totalEarned - totalDeducted;

    return PayrollCalculationResult(
      basicSalary: basicSalary,
      variableSalary: variableSalary,
      allowances: allowances,
      deductions: deductions,
      totalEarned: totalEarned,
      taxAmount: tax,
      insuranceAmount: insurance,
      totalDeducted: totalDeducted,
      netSalary: net,
    );
  }

  static PayrollCalculationResult _calculateNet({
    required double basicSalary,
    required double variableSalary,
    required double allowances,
    required double deductions,
    required TaxService taxService,
  }) {
    // الراتب المتفق عليه (اللي المفروض الموظف ياخده فعليًا قبل أي سلف/خصومات)
    final targetNet = basicSalary + variableSalary + allowances;

    double netFor(double candidateBasic) {
      final earnings = candidateBasic + variableSalary + allowances;
      final tax = taxService.calculateMonthlyTax(earnings);
      final insurance = InsuranceService.calculateInsurance(
          basicSalary: earnings)['employee_share']!;
      return earnings - tax - insurance;
    }

    // بحث ثنائي (bisection) لإيجاد الأساسي المُصعّد اللي بيخلي الصافي بعد
    // الضريبة والتأمين يساوي الراتب المتفق عليه. الدالة netFor تصاعدية دايمًا
    // (الضريبة والتأمين محدودين بحد أقصى)، فالبحث الثنائي مضمون يتقارب.
    double grossedUpBasic = basicSalary;
    if (targetNet > 0) {
      double lo = basicSalary;
      double hi = basicSalary <= 0 ? 1 : basicSalary * 2;
      int guard = 0;
      while (netFor(hi) < targetNet && guard < 100) {
        hi *= 2;
        guard++;
      }
      for (int i = 0; i < 60; i++) {
        final mid = (lo + hi) / 2;
        if (netFor(mid) < targetNet) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      grossedUpBasic = hi;
    }

    final totalEarned = grossedUpBasic + variableSalary + allowances;
    final taxable = totalEarned; // الضريبة/التأمين على القيمة المُصعّدة كاملة
    final tax = taxService.calculateMonthlyTax(taxable);
    final insurance = InsuranceService.calculateInsurance(
        basicSalary: taxable)['employee_share']!;
    final totalDeducted = deductions + tax + insurance;
    final net = totalEarned - totalDeducted; // = targetNet - deductions

    return PayrollCalculationResult(
      basicSalary: grossedUpBasic,
      variableSalary: variableSalary,
      allowances: allowances,
      deductions: deductions,
      totalEarned: totalEarned,
      taxAmount: tax,
      insuranceAmount: insurance,
      totalDeducted: totalDeducted,
      netSalary: net,
    );
  }
}
