// lib/services/tax_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class TaxService {
  static const String _taxRateKey = 'tax_rate';
  static const String _overtimeRateKey = 'overtime_rate';
  static const String _latePenaltyKey = 'late_penalty';

  double taxRate = 0.0;
  double overtimeRate = 1.5;
  double latePenalty = 50.0;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    taxRate = prefs.getDouble(_taxRateKey) ?? 0.0;
    overtimeRate = prefs.getDouble(_overtimeRateKey) ?? 1.5;
    latePenalty = prefs.getDouble(_latePenaltyKey) ?? 50.0;
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_taxRateKey, taxRate);
    await prefs.setDouble(_overtimeRateKey, overtimeRate);
    await prefs.setDouble(_latePenaltyKey, latePenalty);
  }

  // حساب الضريبة الشهرية حسب شرائح مصر
  static double calculateMonthlyTax(double monthlyIncome) {
    // الشرائح السنوية
    final brackets = [
      {'limit': 15000, 'rate': 0.0},
      {'limit': 30000, 'rate': 0.025},
      {'limit': 45000, 'rate': 0.10},
      {'limit': 60000, 'rate': 0.15},
      {'limit': 200000, 'rate': 0.20},
      {'limit': 400000, 'rate': 0.225},
      {'limit': 600000, 'rate': 0.25},
      {'limit': double.infinity, 'rate': 0.275},
    ];

    final annualIncome = monthlyIncome * 12;
    double annualTax = 0;
    double previousLimit = 0;

    for (var bracket in brackets) {
      final limit = bracket['limit'] as double;
      final rate = bracket['rate'] as double;
      
      if (annualIncome > previousLimit) {
        final taxableAmount = (annualIncome > limit) 
            ? limit - previousLimit 
            : annualIncome - previousLimit;
        annualTax += taxableAmount * rate;
      }
      previousLimit = limit;
      if (annualIncome <= limit) break;
    }

    return annualTax / 12; // ضريبة شهرية
  }

  // حساب الـ Overtime
  double calculateOvertime(double basicSalary, int hours) {
    final hourlyRate = basicSalary / (30 * 8); // 30 يوم * 8 ساعات
    return hourlyRate * hours * overtimeRate;
  }

  // حساب خصم التأخير
  double calculateLatePenalty(int lateDays) {
    return lateDays * latePenalty;
  }
}