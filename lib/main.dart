



// lib/main.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'services/tax_service.dart';
import 'services/insurance_service.dart';
import 'core/theme/theme_controller.dart';
import 'controllers/employee_controller.dart';
import 'core/auth/auth_service.dart';
import 'views/employee/employee_page.dart';
import 'views/shared/app_scaffold.dart';
import 'views/auth/login_page.dart';
import 'views/license/license_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('❌ Flutter Error: ${details.exception}');
    if (details.exception.toString().contains('_handledContextLostEvent')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ Platform Error: $error');
    return true;
  };

  await EasyLocalization.ensureInitialized();

  // تهيئة Sqflite حسب المنصة
  if (kIsWeb) {
    // ⚠️ نسخة الويب: قاعدة البيانات مش مشفّرة والترخيص أضعف، فالتشغيل
    // متوقف افتراضيًا. للتجربة فقط: --dart-define=ALLOW_WEB=true
    const allowWeb = bool.fromEnvironment('ALLOW_WEB');
    if (!allowWeb) {
      runApp(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Web build is disabled: data is not encrypted in the browser. '
                'Please use the desktop or Android app.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ));
      return;
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final authService = AuthService();
  await authService.bootstrap();

  final taxService = TaxService();
  await taxService.loadSettings();

  final insuranceService = InsuranceService();
  await insuranceService.loadSettings();

  final themeController = ThemeController();
  await themeController.load();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      useFallbackTranslations: true,
      child: MyApp(
        authService: authService,
        taxService: taxService,
        insuranceService: insuranceService,
        themeController: themeController,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final TaxService taxService;
  final InsuranceService insuranceService;
  final ThemeController themeController;

  const MyApp({
    super.key,
    required this.authService,
    required this.taxService,
    required this.insuranceService,
    required this.themeController,
  });

  // ✅ ثيم فاتح (زي ما كان بالظبط)
  ThemeData _lightTheme() => ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        fontFamily: 'Cairo-Regular',
        brightness: Brightness.light,
      );

  // ✅ ثيم غامق حقيقي - نفس هوية الأخضر بس بألوان مناسبة للوضع الليلي
  ThemeData _darkTheme() => ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo-Regular',
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B1B1B),
          foregroundColor: Colors.white,
        ),
        cardColor: const Color(0xFF1E1E1E),
        dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1E1E)),
      );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => EmployeeController()),
        ChangeNotifierProvider<TaxService>.value(value: taxService),
        ChangeNotifierProvider<InsuranceService>.value(value: insuranceService),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'PureSip PayRolls',
            debugShowCheckedModeBanner: false,
            themeMode: theme.mode,
            theme: _lightTheme(),
            darkTheme: _darkTheme(),
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
          );
        },
      ),
    );
  }
}
