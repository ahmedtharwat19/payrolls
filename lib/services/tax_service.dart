// lib/services/tax_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaxService extends ChangeNotifier {
  static const String _taxRateKey = 'tax_rate';
  static const String _overtimeRateKey = 'overtime_rate';
  static const String _latePenaltyKey = 'late_penalty';
  static const String _taxBracketsKey = 'tax_brackets';
  static const String _personalExemptionKey = 'personal_exemption_annual';
  static const String _deductInsuranceKey = 'deduct_insurance_from_tax_base';
  static const String _bankNameKey = 'bank_name';
  static const String _bankAccountKey = 'bank_account';
  static const String _bankSwiftKey = 'bank_swift';
  static const String _bankIbanKey = 'bank_iban';

  /// الإعفاء الشخصي السنوي (جنيه). القيمة الافتراضية 20,000 حسب ما هو
  /// منشور لعام 2026 - راجع محاسبك القانوني وعدّلها من إعدادات الضرائب
  /// لو تغيّرت.
  static const double defaultPersonalExemption = 20000.0;

  double taxRate = 0.0;
  double overtimeRate = 1.5;
  double latePenalty = 50.0;
  List<Map<String, dynamic>> taxBrackets = defaultBrackets();

  /// الإعفاء الشخصي السنوي - بيتخصم من الدخل السنوي قبل تطبيق الشرائح.
  double personalExemption = defaultPersonalExemption;

  /// لو true: حصة الموظف في التأمينات بتتخصم من وعاء الضريبة قبل تطبيق
  /// الشرائح. راجع محاسبك لتأكيد التطبيق على حالتكم.
  bool deductInsuranceFromTaxBase = true;

  String bankName = '';
  String bankAccount = '';
  String bankSwift = '';
  String bankIban = '';
  List<Map<String, dynamic>> bonuses = [];
  List<Map<String, dynamic>> deductions = [];

  /// الشرائح الضريبية المصرية (دخل سنوي بعد الإعفاء الشخصي).
  /// ⚠️ كلها double عمدًا: الأرقام الصحيحة كانت بتسبب خطأ cast في الحساب.
  static List<Map<String, dynamic>> defaultBrackets() => [
        {'from': 0.0, 'to': 40000.0, 'rate': 0.0},
        {'from': 40000.0, 'to': 55000.0, 'rate': 0.10},
        {'from': 55000.0, 'to': 70000.0, 'rate': 0.15},
        {'from': 70000.0, 'to': 200000.0, 'rate': 0.20},
        {'from': 200000.0, 'to': 400000.0, 'rate': 0.225},
        {'from': 400000.0, 'to': 1200000.0, 'rate': 0.25},
        {'from': 1200000.0, 'to': null, 'rate': 0.275},
      ];

  static double? _asDouble(dynamic v) => v is num ? v.toDouble() : null;

  static List<Map<String, dynamic>>? _parseBrackets(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final result = raw.split('|').where((e) => e.isNotEmpty).map((e) {
        final parts = e.split(',');
        if (parts.length != 3) throw const FormatException('bad bracket');
        return <String, dynamic>{
          'from': double.parse(parts[0]),
          'to': parts[1] == 'null' ? null : double.parse(parts[1]),
          'rate': double.parse(parts[2]),
        };
      }).toList();
      return result.isEmpty ? null : result;
    } catch (_) {
      // قيمة تالفة في الإعدادات - نرجع للشرائح الافتراضية بدل ما نوقف الحساب.
      return null;
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    taxRate = prefs.getDouble(_taxRateKey) ?? 0.0;
    overtimeRate = prefs.getDouble(_overtimeRateKey) ?? 1.5;
    latePenalty = prefs.getDouble(_latePenaltyKey) ?? 50.0;
    personalExemption =
        prefs.getDouble(_personalExemptionKey) ?? defaultPersonalExemption;
    deductInsuranceFromTaxBase = prefs.getBool(_deductInsuranceKey) ?? true;
    bankName = prefs.getString(_bankNameKey) ?? '';
    bankAccount = prefs.getString(_bankAccountKey) ?? '';
    bankSwift = prefs.getString(_bankSwiftKey) ?? '';
    bankIban = prefs.getString(_bankIbanKey) ?? '';

    taxBrackets =
        _parseBrackets(prefs.getString(_taxBracketsKey)) ?? defaultBrackets();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_taxRateKey, taxRate);
    await prefs.setDouble(_overtimeRateKey, overtimeRate);
    await prefs.setDouble(_latePenaltyKey, latePenalty);
    await prefs.setDouble(_personalExemptionKey, personalExemption);
    await prefs.setBool(_deductInsuranceKey, deductInsuranceFromTaxBase);
    await prefs.setString(_bankNameKey, bankName);
    await prefs.setString(_bankAccountKey, bankAccount);
    await prefs.setString(_bankSwiftKey, bankSwift);
    await prefs.setString(_bankIbanKey, bankIban);

    final bracketsStr = taxBrackets.map((b) {
      return '${b['from']},${b['to'] ?? 'null'},${b['rate']}';
    }).join('|');
    await prefs.setString(_taxBracketsKey, bracketsStr);
    notifyListeners();
  }

  /// حساب الضريبة الشهرية على أساس الدخل الشهري.
  ///
  /// [monthlyIncome]: إجمالي المستحقات الشهرية الخاضعة للضريبة.
  /// [monthlyInsurance]: حصة الموظف الشهرية في التأمينات (بتتخصم من الوعاء
  /// لو [deductInsuranceFromTaxBase] مفعّل).
  ///
  /// الوعاء السنوي = (الدخل - التأمينات) × 12 - الإعفاء الشخصي، وتُطبّق
  /// الشرائح على الجزء الواقع داخل كل شريحة (من/إلى) بغض النظر عن ترتيبها.
  double calculateMonthlyTax(double monthlyIncome,
      {double monthlyInsurance = 0}) {
    final base = monthlyIncome -
        (deductInsuranceFromTaxBase ? monthlyInsurance : 0.0);
    final annualTaxable = base * 12 - personalExemption;
    if (annualTaxable <= 0) return 0;

    double annualTax = 0;
    for (final bracket in taxBrackets) {
      final from = _asDouble(bracket['from']) ?? 0.0;
      final to = _asDouble(bracket['to']) ?? double.infinity;
      final rate = _asDouble(bracket['rate']) ?? 0.0;

      if (annualTaxable <= from) continue;
      final upper = annualTaxable < to ? annualTaxable : to;
      if (upper > from) annualTax += (upper - from) * rate;
    }

    return annualTax / 12;
  }

  /// حساب قيمة الساعات الإضافية
  double calculateOvertime(double basicSalary, double hours) {
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
    await prefs.remove(_personalExemptionKey);
    await prefs.remove(_deductInsuranceKey);
    await loadSettings();
    notifyListeners();
  }
}
