// lib/core/responsive/breakpoints.dart
//
// نقطة مركزية واحدة لتحديد شكل الشاشة (موبايل / تابلت / ديسكتوب)
// اعتمدنا على عرض الشاشة الفعلي (width) مش على نوع المنصة (Platform.isWindows...)
// لأن ده بيشتغل صح حتى لو المستخدم صغّر نافذة الويندوز، أو فتح التطبيق
// على تابلت أندرويد بعرض كبير.
//
// الاستخدام:
//   if (context.isDesktop) { ... }
//   final cols = context.responsiveColumns;

import 'package:flutter/material.dart';

/// فئات حجم الشاشة المستخدمة في كل أنحاء التطبيق.
enum ScreenSize { mobile, tablet, desktop }

class Breakpoints {
  Breakpoints._();

  /// أقل من كده = موبايل (هاتف عادي، Drawer، عمود واحد)
  static const double mobile = 600;

  /// من mobile لحد الرقم ده = تابلت (عمودين، Drawer برضو لكن ممكن يبقى واسع)
  static const double tablet = 1024;

  /// فوق الرقم ده = ديسكتوب/ويندوز (NavigationRail ثابت، شبكة فورمز)
  static const double desktop = 1024;

  /// أقصى عرض للمحتوى في الشاشات الكبيرة جدًا (منع الفورم من التمدد بشكل غير مريح)
  static const double maxContentWidth = 1100;

  static ScreenSize of(double width) {
    if (width >= desktop) return ScreenSize.desktop;
    if (width >= mobile) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }
}

extension ResponsiveContext on BuildContext {
  double get _width => MediaQuery.of(this).size.width;

  ScreenSize get screenSize => Breakpoints.of(_width);

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;

  /// موبايل = false، تابلت وديسكتوب = true.
  /// مفيدة لأي قرار بسيط زي "استخدم Row بدل Column".
  bool get isWideScreen => !isMobile;

  /// عدد الأعمدة المقترح لأي شبكة/فورم حسب حجم الشاشة الحالي.
  int get responsiveColumns {
    switch (screenSize) {
      case ScreenSize.desktop:
        return 3;
      case ScreenSize.tablet:
        return 2;
      case ScreenSize.mobile:
        return 1;
    }
  }

  /// Padding أفقي أكبر على الشاشات الواسعة عشان المحتوى ما يلزقش في الحواف.
  EdgeInsets get responsivePagePadding {
    switch (screenSize) {
      case ScreenSize.desktop:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
      case ScreenSize.tablet:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
      case ScreenSize.mobile:
        return const EdgeInsets.all(16);
    }
  }
}
