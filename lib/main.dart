// lib/main.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_payrolls/services/insurance_service.dart';
import 'controllers/employee_controller.dart';
import 'core/auth/auth_service.dart';
import 'views/employee/employee_page.dart';
import 'views/shared/app_scaffold.dart';
import 'views/auth/login_page.dart';
import 'views/license/license_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ معالجة الأخطاء العامة
  FlutterError.onError = (FlutterErrorDetails details) {
    print('❌ Flutter Error: ${details.exception}');
    // تجاهل أخطاء CanvasKit إذا كانت موجودة
    if (details.exception.toString().contains('_handledContextLostEvent')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  // ✅ معالجة الأخطاء غير المتوقعة
  PlatformDispatcher.instance.onError = (error, stack) {
    print('❌ Platform Error: $error');
    return true;
  };

  await EasyLocalization.ensureInitialized();

  // بيزرع الأدوار الافتراضية + أول مستخدم admin لو دي أول مرة يفتح فيها البرنامج.
  // شغالة بنفس الطريقة على كل المنصات (Android/iOS/Windows/macOS/Linux/Web).
  final authService = AuthService();
  await authService.bootstrap();

  final insuranceService = InsuranceService();
  await insuranceService.loadSettings();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      child: MyApp(authService: authService),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => EmployeeController()),
      ],
      child: MaterialApp(
        title: 'PureSip PayRolls',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          fontFamily: 'Cairo',
        ),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        // الترتيب: 1) فحص الترخيص (LicenseGate) → 2) تسجيل الدخول → 3) الشاشة الرئيسية
        home: const LicenseGate(
          child: LoginPage(
            homeAfterLogin: AppScaffold(body: EmployeePage()),
          ),
        ),
      ),
    );
  }
}
