// lib/services/tax_service.dart

class TaxService {
  /// Based on Egyptian income tax brackets (2024)
  /// - First 15,000 EGP: Exempt
  /// - 15,001–30,000 EGP: 2.5%
  /// - 30,001–45,000 EGP: 10%
  /// - 45,001–60,000 EGP: 15%
  /// - 60,001–200,000 EGP: 20%
  /// - 200,001–400,000 EGP: 22.5%
  /// - Above 400,000 EGP: 25%

  static double calculateMonthlyTax(double monthlySalary) {
    double annualSalary = monthlySalary * 12;
    double tax = 0;

    double taxable = annualSalary - 15000; // Personal exemption
    if (taxable <= 0) return 0;

    if (taxable <= 15000) {
      tax += taxable * 0.025;
    } else {
      tax += 15000 * 0.025;
      if (taxable <= 30000) {
        tax += (taxable - 15000) * 0.10;
      } else {
        tax += 15000 * 0.10;
        if (taxable <= 45000) {
          tax += (taxable - 30000) * 0.15;
        } else {
          tax += 15000 * 0.15;
          if (taxable <= 140000) {
            tax += (taxable - 45000) * 0.20;
          } else if (taxable <= 340000) {
            tax += (95000) * 0.20;
            tax += (taxable - 140000) * 0.225;
          } else {
            tax += (95000) * 0.20;
            tax += (200000) * 0.225;
            tax += (taxable - 340000) * 0.25;
          }
        }
      }
    }

    return tax / 12; // return monthly tax
  }
}
