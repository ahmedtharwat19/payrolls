// lib/services/insurance_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class InsuranceService {
  static const String _employeeRateKey = 'insurance_employee_rate';
  static const String _companyRateKey = 'insurance_company_rate';
  static const String _minInsuranceKey = 'insurance_min';
  static const String _maxInsuranceKey = 'insurance_max';

  double employeeRate = 0.11;   // 11%
  double companyRate = 0.12;    // 12%
  double minInsurance = 1000.0; // 1,000 EGP
  double maxInsurance = 10000.0;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    employeeRate = prefs.getDouble(_employeeRateKey) ?? 0.11;
    companyRate = prefs.getDouble(_companyRateKey) ?? 0.12;
    minInsurance = prefs.getDouble(_minInsuranceKey) ?? 1000.0;
    maxInsurance = prefs.getDouble(_maxInsuranceKey) ?? 10000.0;
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_employeeRateKey, employeeRate);
    await prefs.setDouble(_companyRateKey, companyRate);
    await prefs.setDouble(_minInsuranceKey, minInsurance);
    await prefs.setDouble(_maxInsuranceKey, maxInsurance);
  }

  // حساب التأمينات
  static Map<String, double> calculateInsurance({
    required double basicSalary,
    double? employeeRate,
    double? companyRate,
    double? minInsurance,
    double? maxInsurance,
  }) {
    // استخدام القيم الافتراضية أو القيم المدخلة
    final empRate = employeeRate ?? 0.11;
    final compRate = companyRate ?? 0.12;
    final minIns = minInsurance ?? 1000.0;
    final maxIns = maxInsurance ?? 10000.0;

    // التأمين يحسب على الأجر الأساسي بحدود دنيا وقصوى
    double insurableSalary = basicSalary.clamp(minIns, maxIns);
    
    return {
      'employee_share': insurableSalary * empRate,
      'company_share': insurableSalary * compRate,
      'insurable_salary': insurableSalary,
    };
  }
}