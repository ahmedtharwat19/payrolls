// lib/main.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ أضف هذا للـ kIsWeb
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // ✅ أضف
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // ✅ أضف

import 'services/tax_service.dart'; // ✅ أضف
import 'services/insurance_service.dart';
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
    if (details.exception.toString().contains('_handledContextLostEvent')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    print('❌ Platform Error: $error');
    return true;
  };

  await EasyLocalization.ensureInitialized();

  // ✅ تهيئة قاعدة البيانات للـ Web
  if (kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ✅ تهيئة AuthService
  final authService = AuthService();
  await authService.bootstrap();

  // ✅ تهيئة TaxService و InsuranceService
  final taxService = TaxService();
  await taxService.loadSettings();

  final insuranceService = InsuranceService();
  await insuranceService.loadSettings();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang', // ✅ تصحيح المسار
      fallbackLocale: const Locale('en'),
      useFallbackTranslations: true,
      child: MyApp(
        authService: authService,
        taxService: taxService,
        insuranceService: insuranceService,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final TaxService taxService;
  final InsuranceService insuranceService;

  const MyApp({
    super.key,
    required this.authService,
    required this.taxService,
    required this.insuranceService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ✅ AuthService
        ChangeNotifierProvider.value(value: authService),
        
        // ✅ EmployeeController
        ChangeNotifierProvider(create: (_) => EmployeeController()),
        
        // ✅ TaxService و InsuranceService
        Provider<TaxService>.value(value: taxService),
        Provider<InsuranceService>.value(value: insuranceService),
      ],
      child: MaterialApp(
        title: 'PureSip PayRolls',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          fontFamily: 'Cairo',
          useMaterial3: true,
        ),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        localeResolutionCallback: (locale, supportedLocales) {
          if (locale == null) return const Locale('en');
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
          return const Locale('en');
        },
        home: const LicenseGate(
          child: LoginPage(
            homeAfterLogin: AppScaffold(body: EmployeePage()),
          ),
        ),
      ),
    );
  }
}