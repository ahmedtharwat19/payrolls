import 'package:flutter_test/flutter_test.dart';
import 'package:puresip_payrolls/services/insurance_service.dart';
import 'package:puresip_payrolls/services/payroll_calculation_service.dart';
import 'package:puresip_payrolls/services/tax_service.dart';

void main() {
  group('TaxService', () {
    test('income below exemption + zero bracket has no tax', () {
      final t = TaxService();
      expect(t.calculateMonthlyTax(3000), 0);
    });

    test('exemption and insurance deduction are applied', () {
      final t = TaxService();
      final ins = InsuranceService.calculateInsurance(basicSalary: 10000);
      final tax = t.calculateMonthlyTax(10000,
          monthlyInsurance: ins['employee_share']!);
      expect(tax, closeTo(592.500000, 0.01));
    });

    test('disabling insurance deduction increases tax', () {
      final a = TaxService()..deductInsuranceFromTaxBase = true;
      final b = TaxService()..deductInsuranceFromTaxBase = false;
      expect(b.calculateMonthlyTax(10000, monthlyInsurance: 1100),
          greaterThan(a.calculateMonthlyTax(10000, monthlyInsurance: 1100)));
    });

    test('integer-like brackets do not throw', () {
      final t = TaxService();
      t.taxBrackets = [
        {'from': 0, 'to': 40000, 'rate': 0},
        {'from': 40000, 'to': null, 'rate': 0.1},
      ];
      expect(() => t.calculateMonthlyTax(20000), returnsNormally);
    });
  });

  group('InsuranceService', () {
    test('applies min and max insurable wage', () {
      expect(InsuranceService.calculateInsurance(basicSalary: 500)['insurable_salary'], 2000);
      expect(InsuranceService.calculateInsurance(basicSalary: 50000)['insurable_salary'], 12600);
      expect(InsuranceService.calculateInsurance(basicSalary: 10000)['employee_share'], closeTo(1100.0000, 0.0001));
    });
  });

  group('PayrollCalculationService', () {
    test('gross: net = gross - tax - insurance', () {
      final r = PayrollCalculationService.calculateFromAmounts(
        basicSalary: 10000, variableSalary: 0, allowances: 0, deductions: 0,
        salaryType: 'gross', taxService: TaxService());
      expect(r.insuranceAmount, closeTo(1100.00, 0.01));
      expect(r.taxAmount, closeTo(592.50, 0.01));
      expect(r.netSalary, closeTo(8307.50, 0.02));
    });

    test('net: employee receives the agreed amount', () {
      final r = PayrollCalculationService.calculateFromAmounts(
        basicSalary: 10000, variableSalary: 0, allowances: 0, deductions: 0,
        salaryType: 'net', taxService: TaxService());
      expect(r.netSalary, 10000);
      expect(r.basicSalary, greaterThan(10000));
      expect(r.grossUpAmount, closeTo(r.taxAmount + r.insuranceAmount, 0.011));
    });

    test('allowances are not zeroed', () {
      final r = PayrollCalculationService.calculateFromAmounts(
        basicSalary: 8000, variableSalary: 0, allowances: 2000, deductions: 0,
        salaryType: 'gross', taxService: TaxService());
      expect(r.allowances, 2000);
      expect(r.totalEarned, 10000);
    });

    test('zero earnings produce no tax', () {
      final r = PayrollCalculationService.calculateFromAmounts(
        basicSalary: 0, variableSalary: 0, allowances: 0, deductions: 0,
        salaryType: 'gross', taxService: TaxService());
      expect(r.taxAmount, 0);
      expect(r.netSalary, 0);
    });
  });
}
