// lib/services/insurance_service.dart

class InsuranceService {
  /// Egypt Social Insurance (2024)
  /// - Employee pays 11% (of total: basic + variable)
  /// - Company pays 18.75%

  static Map<String, double> calculateInsurance({
    required double basicSalary,
    double variableSalary = 0,
  }) {
    final totalSalary = basicSalary + variableSalary;
    final employeeShare = totalSalary * 0.11;
    final companyShare = totalSalary * 0.1875;

    return {
      'employee_share': employeeShare,
      'company_share': companyShare,
      'total': employeeShare + companyShare,
    };
  }
}
