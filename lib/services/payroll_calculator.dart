// lib/services/payroll_calculator.dart

import 'tax_service.dart';
import 'insurance_service.dart';

/// نتيجة حساب الضريبة والتأمينات لموظف واحد في شهر واحد.
class PayrollCalculationResult {
  /// الوعاء اللي حُسبت عليه الضريبة والتأمين.
  /// - في حالة "gross": هو نفس الراتب الأساسي المدخل.
  /// - في حالة "net": هو الراتب المُصعَّد (gross-up) اللي لو خصمنا منه
  ///   الضريبة والتأمين، هنوصل لصافي = المرتب المتفق عليه بالظبط.
  final double taxableBase;
  final double tax;
  final double insuranceEmployee;
  final double insuranceCompany;

  /// الصافي بعد الضريبة والتأمين فقط (قبل أي خصومات/سلف شخصية أخرى).
  final double netAfterTaxAndInsurance;

  const PayrollCalculationResult({
    required this.taxableBase,
    required this.tax,
    required this.insuranceEmployee,
    required this.insuranceCompany,
    required this.netAfterTaxAndInsurance,
  });
}

/// يحسب الضريبة والتأمينات بشكل صحيح حسب نوع الراتب المتفق عليه مع الموظف:
///
/// - **gross (إجمالي)**: الراتب المدخل هو الوعاء الضريبي، وبيتم خصم الضريبة
///   والتأمين منه عادي، فيقل صافي الموظف عن الرقم المتفق عليه.
///
/// - **net (صافي)**: الراتب المدخل هو المبلغ اللي المفروض يوصل للموظف *بعد*
///   خصم الضريبة والتأمين. الشركة هنا هي اللي بتتحمل عبء الضريبة، فالنظام
///   بيرفع (يُصعِّد) الراتب تلقائياً لحد ما بعد خصم الضريبة والتأمين من
///   الراتب المُصعَّد، يوصل الصافي بالظبط للرقم المتفق عليه.
class PayrollCalculator {
  /// حساب الضريبة والتأمين لموظف "gross": الوعاء = الأساسي نفسه.
  static PayrollCalculationResult calculateGross({
    required double taxableSalary,
    required TaxService taxService,
  }) {
    final tax = taxService.calculateMonthlyTax(taxableSalary);
    final ins = InsuranceService.calculateInsurance(basicSalary: taxableSalary);
    final insEmployee = ins['employee_share']!;
    return PayrollCalculationResult(
      taxableBase: taxableSalary,
      tax: tax,
      insuranceEmployee: insEmployee,
      insuranceCompany: ins['company_share']!,
      netAfterTaxAndInsurance: taxableSalary - tax - insEmployee,
    );
  }

  /// حساب "تصعيد" الراتب (net-to-gross) لموظف "net": بيدور بالبحث الثنائي
  /// (binary search) على وعاء ضريبي بحيث net(taxableBase) == targetNet
  /// بالظبط. الدالة net(x) = x - tax(x) - insurance(x) متزايدة دايماً مع x
  /// (لأن أعلى شريحة ضريبية + التأمين مجتمعين أقل من 100%)، فالبحث الثنائي
  /// مضمون يوصل لنتيجة دقيقة جداً.
  static PayrollCalculationResult calculateNetToGross({
    required double targetNet,
    required TaxService taxService,
  }) {
    if (targetNet <= 0) {
      return const PayrollCalculationResult(
        taxableBase: 0,
        tax: 0,
        insuranceEmployee: 0,
        insuranceCompany: 0,
        netAfterTaxAndInsurance: 0,
      );
    }

    double low = targetNet;
    // هامش أمان كبير يغطي حتى أعلى شرائح الضريبة المصرية (27.5%) + التأمين
    double high = targetNet * 2 + 20000;

    double net(double gross) {
      final tax = taxService.calculateMonthlyTax(gross);
      final ins = InsuranceService.calculateInsurance(basicSalary: gross);
      return gross - tax - ins['employee_share']!;
    }

    // تأكيد إن الحد الأعلى كافي (net دايماً متزايدة مع gross)
    while (net(high) < targetNet) {
      high *= 2;
    }

    for (int i = 0; i < 60; i++) {
      final mid = (low + high) / 2;
      if (net(mid) < targetNet) {
        low = mid;
      } else {
        high = mid;
      }
    }

    final gross = high;
    final tax = taxService.calculateMonthlyTax(gross);
    final ins = InsuranceService.calculateInsurance(basicSalary: gross);
    final insEmployee = ins['employee_share']!;

    return PayrollCalculationResult(
      taxableBase: gross,
      tax: tax,
      insuranceEmployee: insEmployee,
      insuranceCompany: ins['company_share']!,
      netAfterTaxAndInsurance: gross - tax - insEmployee,
    );
  }

  /// نقطة الدخول الموحّدة: بتحدد تلقائياً تستخدم gross ولا net-to-gross
  /// حسب [salaryType] ('net' أو 'gross').
  ///
  /// [taxableSalary] هو الوعاء المستخدم لحالة gross (عادة basicSalary).
  /// [targetNet] هو الصافي المتفق عليه المستخدم لحالة net (عادة
  /// basicSalary + variableSalary + allowances، أي إجمالي المستحق قبل
  /// الخصومات الشخصية).
  static PayrollCalculationResult calculate({
    required String salaryType,
    required double taxableSalary,
    required double targetNet,
    required TaxService taxService,
  }) {
    if (salaryType == 'net') {
      return calculateNetToGross(
        targetNet: targetNet,
        taxService: taxService,
      );
    }
    return calculateGross(
      taxableSalary: taxableSalary,
      taxService: taxService,
    );
  }
}
