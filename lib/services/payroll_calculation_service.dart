// lib/services/payroll_calculation_service.dart
import 'tax_service.dart';
import 'insurance_service.dart';

/// ناتج احتساب راتب شهري لموظف واحد.
///
/// - [basicSalary]: الأساسي الفعلي المستخدم في السجل. في حالة الراتب
///   "net" ده بيشمل الزيادة التلقائية (gross-up) اللي بتغطي الضريبة.
/// - [grossUpAmount]: قد تكون 0 دايمًا لو النوع "gross"، أو المبلغ اللي
///   اتضاف تلقائيًا على الأساسي في حالة "net" عشان تتحمله الشركة.
class PayrollCalculationResult {
  final double basicSalary;
  final double variableSalary;
  final double allowances;
  final double deductions;
  final double taxAmount;
  final double insuranceAmount;
  final double netSalary;
  final double grossUpAmount;

  const PayrollCalculationResult({
    required this.basicSalary,
    required this.variableSalary,
    required this.allowances,
    required this.deductions,
    required this.taxAmount,
    required this.insuranceAmount,
    required this.netSalary,
    this.grossUpAmount = 0,
  });

  double get totalEarned => basicSalary + variableSalary + allowances;
  double get totalDeducted => deductions + taxAmount + insuranceAmount;
}

/// مصدر واحد لحساب الضريبة والتأمينات والصافي، عشان نفس المنطق يتطبّق
/// في شاشة المرتبات وفي التصدير PDF وفي توليد سجلات الرواتب، بدل ما
/// يتكرر (ويختلف بالغلط) في أكتر من مكان.
class PayrollCalculationService {
  // أقصى عدد محاولات، وأقل فرق مقبول (بالجنيه) عشان نوقف "تنصيف المدى".
  static const int _maxIterations = 60;
  static const double _epsilon = 0.001;

  /// يحسب الضريبة/التأمينات/الصافي بناءً على القيم المُدخلة والنوع.
  ///
  /// - النوع "gross" (إجمالي): زي ما كان معمول بالظبط - الضريبة
  ///   والتأمينات بتتحسب على الأساسي فقط، والموظف هو اللي بيتحمّلها
  ///   (بتتخصم من راتبه).
  /// - النوع "net" (صافي): القيم المُدخلة (أساسي + متغيّر + بدلات) هي
  ///   المبلغ المتفق إن الموظف يستلمه فعليًا. الشركة هي اللي بتتحمّل
  ///   الضريبة، فبيتم "تجميع" (gross-up) الراتب تلقائيًا بحيث بعد خصم
  ///   الضريبة والتأمينات يوصل الموظف بالظبط للمبلغ المتفق عليه.
  static PayrollCalculationResult calculateFromAmounts({
    required double basicSalary,
    required double variableSalary,
    required double allowances,
    required double deductions,
    required String salaryType,
    required TaxService taxService,
  }) {
    final enteredTotal = basicSalary + variableSalary + allowances;

    if (salaryType == 'net') {
      final grossed = _grossUpForNetTarget(
        netTarget: enteredTotal,
        taxService: taxService,
      );

      // ✅ الزيادة التلقائية اللي هتتحملها الشركة عشان تغطي الضريبة
      final grossUpAmount = grossed.total - enteredTotal;

      return PayrollCalculationResult(
        basicSalary: basicSalary + grossUpAmount,
        variableSalary: variableSalary,
        allowances: allowances,
        deductions: deductions,
        taxAmount: grossed.tax,
        insuranceAmount: grossed.insurance,
        // الصافي = المبلغ المتفق عليه (enteredTotal) بعد خصم أي
        // استقطاعات إضافية (سلف/جزاءات...) مسجّلة على الموظف.
        netSalary: grossed.total - grossed.tax - grossed.insurance - deductions,
        grossUpAmount: grossUpAmount,
      );
    }

    // ---- النوع "gross": نفس المنطق المستخدم حاليًا في التطبيق ----
    final taxable = basicSalary;
    final tax = taxService.calculateMonthlyTax(taxable);
    final insurance = InsuranceService.calculateInsurance(
            basicSalary: taxable)['employee_share'] ??
        0;
    final grossAfterDeductions = enteredTotal - deductions;

    return PayrollCalculationResult(
      basicSalary: basicSalary,
      variableSalary: variableSalary,
      allowances: allowances,
      deductions: deductions,
      taxAmount: tax,
      insuranceAmount: insurance,
      netSalary: grossAfterDeductions - tax - insurance,
    );
  }

  /// بيحل معادلة: G - ضريبة(G) - تأمينات(G) = netTarget
  /// عن طريق "تنصيف المدى" (bisection) بدل معادلة مباشرة، لأن شرائح
  /// الضريبة والحد الأدنى/الأقصى للتأمينات بتخليها دالة غير خطية
  /// ومتغيّرة حسب إعدادات التطبيق.
  static _GrossUpResult _grossUpForNetTarget({
    required double netTarget,
    required TaxService taxService,
  }) {
    if (netTarget <= 0) {
      return const _GrossUpResult(total: 0, tax: 0, insurance: 0);
    }

    double netAt(double gross) {
      final tax = taxService.calculateMonthlyTax(gross);
      final insurance = InsuranceService.calculateInsurance(
              basicSalary: gross)['employee_share'] ??
          0;
      return gross - tax - insurance;
    }

    double low = netTarget;
    // حد أعلى آمن: الضريبة والتأمينات مش هتاخد كل الزيادة، فمضاعفة
    // الهدف + هامش كبير كفاية في كل الحالات الواقعية.
    double high = netTarget * 2 + 10000;

    var safety = 0;
    while (netAt(high) < netTarget && safety < 10) {
      high *= 2;
      safety++;
    }

    double mid = high;
    for (var i = 0; i < _maxIterations; i++) {
      mid = (low + high) / 2;
      final net = netAt(mid);
      if ((net - netTarget).abs() < _epsilon) break;
      if (net < netTarget) {
        low = mid;
      } else {
        high = mid;
      }
    }

    final tax = taxService.calculateMonthlyTax(mid);
    final insurance = InsuranceService.calculateInsurance(
            basicSalary: mid)['employee_share'] ??
        0;
    return _GrossUpResult(total: mid, tax: tax, insurance: insurance);
  }
}

class _GrossUpResult {
  final double total;
  final double tax;
  final double insurance;
  const _GrossUpResult({
    required this.total,
    required this.tax,
    required this.insurance,
  });
}
