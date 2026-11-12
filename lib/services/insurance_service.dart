// lib/services/insurance_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InsuranceService with ChangeNotifier {
  static const String _employeeRateKey = 'insurance_employee_rate';
  static const String _companyRateKey = 'insurance_company_rate';
  static const String _minInsuranceKey = 'insurance_min';
  static const String _maxInsuranceKey = 'insurance_max';

  static const double defaultEmployeeRate = 0.11; // 11%
  static const double defaultCompanyRate = 0.1875; // 18.75%
  static const double defaultMinInsurance = 2000.0;
  static const double defaultMaxInsurance = 12600.0;

  static double _activeEmployeeRate = defaultEmployeeRate;
  static double _activeCompanyRate = defaultCompanyRate;
  static double _activeMin = defaultMinInsurance;
  static double _activeMax = defaultMaxInsurance;

  double employeeRate = defaultEmployeeRate;
  double companyRate = defaultCompanyRate;
  double minInsurance = defaultMinInsurance;
  double maxInsurance = defaultMaxInsurance;

  void _syncActive() {
    _activeEmployeeRate = employeeRate;
    _activeCompanyRate = companyRate;
    _activeMin = minInsurance;
    _activeMax = maxInsurance;
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    employeeRate = prefs.getDouble(_employeeRateKey) ?? defaultEmployeeRate;
    companyRate = prefs.getDouble(_companyRateKey) ?? defaultCompanyRate;
    minInsurance = prefs.getDouble(_minInsuranceKey) ?? defaultMinInsurance;
    maxInsurance = prefs.getDouble(_maxInsuranceKey) ?? defaultMaxInsurance;
    _syncActive();
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_employeeRateKey, employeeRate);
    await prefs.setDouble(_companyRateKey, companyRate);
    await prefs.setDouble(_minInsuranceKey, minInsurance);
    await prefs.setDouble(_maxInsuranceKey, maxInsurance);
    _syncActive();
    notifyListeners();
  }

  /// الأجر التأميني بعد تطبيق الحدّين الأدنى والأقصى.
  static double insurableWage(double wage,
      {double? minInsurance, double? maxInsurance}) {
    final a = minInsurance ?? _activeMin;
    final b = maxInsurance ?? _activeMax;
    final lo = a < b ? a : b;
    final hi = a < b ? b : a;
    if (wage < lo) return lo;
    if (wage > hi) return hi;
    return wage;
  }

  /// حساب التأمينات على [basicSalary] (الأجر التأميني: الأساسي + المتغيّر).
  /// ✅ تم إضافة [fixedInsurance] للتعامل مع القيمة الثابتة.
  static Map<String, double> calculateInsurance({
    required double basicSalary,
    double fixedInsurance = 0.0, // ✅ القيمة الثابتة
    double? employeeRate,
    double? companyRate,
    double? minInsurance,
    double? maxInsurance,
  }) {
    // ✅ لو الموظف ليه تأمينات ثابتة، نرجعها فوراً ونتجاهل النسبة
    if (fixedInsurance > 0) {
      return {
        'employee_share': fixedInsurance,
        'company_share':
            0.0, // لو الشركة مش بتدفع حصة له، أو ممكن تتحسب كنسبة من الثابت
        'insurable_salary': basicSalary,
      };
    }

    // الحساب العادي بالنسبة المئوية
    final empRate = employeeRate ?? _activeEmployeeRate;
    final compRate = companyRate ?? _activeCompanyRate;

    final insurable = insurableWage(
      basicSalary,
      minInsurance: minInsurance,
      maxInsurance: maxInsurance,
    );

    return {
      'employee_share': insurable * empRate,
      'company_share': insurable * compRate,
      'insurable_salary': insurable,
    };
  }
}
