// lib/core/theme/theme_controller.dart
//
// ✅ تحكم مركزي في الوضع الليلي/النهاري لكل التطبيق، مع حفظ الاختيار
// محليًا (SharedPreferences) عشان يفضل نفس الاختيار بعد ما تقفل التطبيق.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _prefKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// بيتنادى مرة واحدة عند بدء التطبيق عشان يحمّل آخر اختيار محفوظ.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      _mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {
      // لو حصل أي خطأ في القراءة، نفضل على الوضع النهاري الافتراضي.
    }
  }

  Future<void> toggle() => setDark(!isDark);

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, dark ? 'dark' : 'light');
    } catch (_) {
      // تجاهل فشل الحفظ - الاختيار هيفضل شغال في الجلسة الحالية بس.
    }
  }
}
