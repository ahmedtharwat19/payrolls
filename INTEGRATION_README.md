# دليل الدمج - نظام الصلاحيات والتراخيص

## 1) الملفات
انسخ المجلدات دي كما هي جوه مشروعك (نفس المسارات):
```
lib/core/auth/          → permission.dart, role.dart, user_model.dart, auth_service.dart
lib/core/database/      → app_database.dart
lib/core/license/       → license_model.dart, device_fingerprint.dart, license_service.dart
lib/views/auth/         → login_page.dart
lib/views/shared/       → permission_gate.dart
tools/                  → license_generator.dart (ده عندك انت بس، متسيبوش يترفع مع نسخة العميل)
```

## 2) المكتبات
ضيف المحتوى الموجود في `pubspec_additions.yaml` لملف `pubspec.yaml` بتاعك، وبعدين:
```
flutter pub get
```

## 3) توليد مفاتيح التوقيع (مرة واحدة بس، أول ما تبدأ)
```
dart run tools/license_generator.dart keys
```
هيديك Private Key (سيبه عندك في مكان آمن، **متحطوش في Git**) و Public Key.
انسخ الـ Public Key وحطه في:
```dart
// lib/core/license/license_service.dart
static const String _publicKeyBase64 = '...الصق هنا...';
```

أضف `license_keys.txt` في `.gitignore` فورًا.

## 4) تعديل main.dart
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final authService = AuthService();
  await authService.bootstrap(); // بيزرع الأدوار + أول مستخدم admin

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authService),
        ChangeNotifierProvider(create: (_) => EmployeeController()),
      ],
      child: const MyApp(),
    ),
  );
}
```
وخلي `home:` في MaterialApp يبقى `LoginPage(homeAfterLogin: AppScaffold(body: EmployeePage()))`.

## 5) تفعيل ترخيص عميل جديد (السيناريو الكامل)
1. العميل بيفتح البرنامج → يشوف شاشة "غير مُفعّل" (لازم تضيفها - فيها حقل لصق كود الترخيص).
2. البرنامج بيوريله بصمة جهازه (استخدم `LicenseService.instance.currentDeviceFingerprint()`).
3. العميل يبعتلك: اسم الشركة + بصمة الجهاز.
4. انت شغّل:
   ```
   dart run tools/license_generator.dart license "شركة كذا" 5 3 2026-12-31
   ```
   ابعتله الكود الناتج، يدخله في شاشة "تفعيل الترخيص" → `LicenseService.instance.activateLicense(code)`.
5. بعدين شغّل:
   ```
   dart run tools/license_generator.dart device <بصمة الجهاز> 1
   ```
   ابعتله كود التفعيل، يدخله → `LicenseService.instance.activateDevice(code)`.
6. لما يحب يفتح البرنامج على جهاز تاني، يكرر خطوة 2 و5 بس (رقم سلوت مختلف: 2، 3...) لحد ما يوصل `maxDevices`.

## 6) استخدام الصلاحيات في الشاشات
```dart
PermissionGate(
  permission: Permission.deleteEmployee,
  child: IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
)
```
أو تحقق مباشر:
```dart
if (context.read<AuthService>().can(Permission.runPayroll)) { ... }
```

## ملاحظات مهمة
- ده نظام أوفلاين حقيقي - مفيش أي اتصال إنترنت مطلوب في أي خطوة من خطوات التطبيق نفسه.
- الحماية الوحيدة اللي فيها نقطة ضعف نظرية: لو حد نسخ ملف الـ `payrolls.db` بتاع جهاز مفعّل على جهاز تاني بنفس المواصفات، ممكن يستخدمه (لأن الفحص بيعتمد على بصمة الجهاز اللي المفروض تتغير، لكن مش كل بصمات الأجهزة قوية 100%). لو محتاج حماية أقوى من كده، الخطوة الجاية المنطقية هي طبقة تحقق سحابية بسيطة (Firebase مجانية) وقت التفعيل بس - ده احنا قدرنا نضيفه بسهولة فوق نفس البنية دي وقتها.
- غيّر باسورد الـ admin الافتراضي (admin/admin123) أول حاجة بعد أول تشغيل.
