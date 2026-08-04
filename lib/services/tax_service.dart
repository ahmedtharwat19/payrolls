// lib/services/tax_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaxService extends ChangeNotifier {
  static const String _taxRateKey = 'tax_rate';
  static const String _overtimeRateKey = 'overtime_rate';
  static const String _latePenaltyKey = 'late_penalty';
  static const String _taxBracketsKey = 'tax_brackets';
  static const String _bankNameKey = 'bank_name';
  static const String _bankAccountKey = 'bank_account';
  static const String _bankSwiftKey = 'bank_swift';
  static const String _bankIbanKey = 'bank_iban';

  double taxRate = 0.0;
  double overtimeRate = 1.5;
  double latePenalty = 50.0;
  List<Map<String, dynamic>> taxBrackets = [];
  String bankName = '';
  String bankAccount = '';
  String bankSwift = '';
  String bankIban = '';
  List<Map<String, dynamic>> bonuses = [];
  List<Map<String, dynamic>> deductions = [];

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    taxRate = prefs.getDouble(_taxRateKey) ?? 0.0;
    overtimeRate = prefs.getDouble(_overtimeRateKey) ?? 1.5;
    latePenalty = prefs.getDouble(_latePenaltyKey) ?? 50.0;
    bankName = prefs.getString(_bankNameKey) ?? '';
    bankAccount = prefs.getString(_bankAccountKey) ?? '';
    bankSwift = prefs.getString(_bankSwiftKey) ?? '';
    bankIban = prefs.getString(_bankIbanKey) ?? '';

    final bracketsJson = prefs.getString(_taxBracketsKey);
    if (bracketsJson != null && bracketsJson.isNotEmpty) {
      taxBrackets = bracketsJson.split('|').where((e) => e.isNotEmpty).map((e) {
        final parts = e.split(',');
        return {
          'from': double.parse(parts[0]),
          'to': parts[1] == 'null' ? null : double.parse(parts[1]),
          'rate': double.parse(parts[2]),
        };
      }).toList();
    } else {
      // الشرائح الضريبية المصرية الصحيحة (حسب آخر تعديل 2024)
      taxBrackets = [
        {'from': 0, 'to': 40000, 'rate': 0.0}, // 0% (إعفاء)
        {'from': 40000, 'to': 55000, 'rate': 0.10}, // 10%
        {'from': 55000, 'to': 70000, 'rate': 0.15}, // 15%
        {'from': 70000, 'to': 200000, 'rate': 0.20}, // 20%
        {'from': 200000, 'to': 400000, 'rate': 0.225}, // 22.5%
        {'from': 400000, 'to': 1200000, 'rate': 0.25}, // 25%
        {'from': 1200000, 'to': null, 'rate': 0.275}, // 27.5%
      ];
    }
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_taxRateKey, taxRate);
    await prefs.setDouble(_overtimeRateKey, overtimeRate);
    await prefs.setDouble(_latePenaltyKey, latePenalty);
    await prefs.setString(_bankNameKey, bankName);
    await prefs.setString(_bankAccountKey, bankAccount);
    await prefs.setString(_bankSwiftKey, bankSwift);
    await prefs.setString(_bankIbanKey, bankIban);

    final bracketsStr = taxBrackets.map((b) {
      return '${b['from']},${b['to'] ?? 'null'},${b['rate']}';
    }).join('|');
    await prefs.setString(_taxBracketsKey, bracketsStr);
    notifyListeners();
    // يمكن إضافة حفظ المكافآت والخصومات لاحقاً
  }

  /// حساب الضريبة الشهرية على أساس الدخل الشهري
  double calculateMonthlyTax(double monthlyIncome) {
    final annualIncome = monthlyIncome * 12;
    double annualTax = 0;
    double previousLimit = 0;

    for (var bracket in taxBrackets) {
      final limit = bracket['to'] as double? ?? double.infinity;
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

    return annualTax / 12;
  }

  /// حساب قيمة الساعات الإضافية
  double calculateOvertime(double basicSalary, int hours) {
    final hourlyRate = basicSalary / (30 * 8);
    return hourlyRate * hours * overtimeRate;
  }

  /// حساب غرامة التأخير عن الأيام المتأخرة
  double calculateLatePenalty(int lateDays) {
    return lateDays * latePenalty;
  }

  /// إعادة تعيين الشرائح إلى القيم المصرية الافتراضية
  Future<void> resetToEgyptianBrackets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taxBracketsKey);
    await loadSettings(); // إعادة تحميل القيم الافتراضية
    notifyListeners();
  }
}
