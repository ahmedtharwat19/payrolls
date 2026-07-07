# دليل الدمج - المرتبات الشهرية + الصرف الجزئي + النسخ الاحتياطي + الاستيراد الجماعي

## ⚠️ 0) إصلاح حرج أولاً - قاعدة بيانات مزدوجة
لقيت في مشروعك ملفين بيفتحوا نفس قاعدة البيانات (`payrolls.db`) بمخططين
مختلفين:
- `lib/core/database/app_database.dart`
- `lib/database/app_database.dart`

ده بيسبب تعارض: أنهي واحد فيهم بيفتح الأول هو اللي بيحدد شكل الجداول
الفعلي، والتاني ممكن يفشل أو ينقصه جداول. **استبدل الملفين بالنسختين
المرفقتين هنا بالظبط**:
- `lib/core/database/app_database.dart` → المصدر الحقيقي الوحيد (فيه كل
  الجداول: users, roles, license, employees, attendance, payroll_records,
  salary_payments...)
- `lib/database/app_database.dart` → بقى مجرد `export` للملف التاني، عشان
  `employee_storage.dart` و`attendance_storage.dart` يفضلوا شغالين من غير
  ما تعدّل فيهم حاجة.

قاعدة البيانات بقت version 3 - الترقية من أي نسخة قديمة (1 أو 2) بتحصل
تلقائيًا (`onUpgrade`)، مفيش داعي تمسح بيانات موجودة.

## 1) الملفات الجديدة
```
lib/models/payroll_record_model.dart     → راتب شهر واحد لموظف واحد
lib/models/salary_payment_model.dart     → دفعة صرف (جزئية/كاش-بنك)
lib/database/payroll_storage.dart        → توليد واسترجاع المرتبات الشهرية
lib/database/payment_storage.dart        → تسجيل الدفعات + حساب المتبقي + تقارير
lib/services/backup_service.dart         → تصدير/استرجاع نسخة احتياطية كاملة
lib/services/bulk_import_service.dart    → استيراد موظفين من Excel دفعة واحدة
lib/views/payroll/record_payment_dialog.dart  → نافذة تسجيل دفعة صرف
lib/views/backup/data_tools_page.dart    → شاشة تجمع النسخ الاحتياطي + الاستيراد
assets/lang/ar.json, en.json             → نسخة مدمجة (مفاتيحك القديمة + الجديدة)
```

## 2) توليد راتب الشهر لكل الموظفين
في `payroll_page.dart` بتاعك (أو زرار جديد)، استخدم `PayrollStorage`:
```dart
final storage = PayrollStorage();
final records = await storage.generateMonthlyPayroll(
  employees: controller.employees,
  month: 7,
  year: 2026,
  calculateTax: (e) => _taxService.calculateMonthlyTax(e.basicSalary + e.allowances - e.deductions),
  calculateInsurance: (e) => InsuranceService.calculateInsurance(basicSalary: e.basicSalary)['employee_share']!,
);
```
لو الشهر ده اتولّد قبل كده، هيرجعلك السجلات الموجودة من غير ما يكررها
(إلا لو مرّرت `overwrite: true`).

## 3) تسجيل دفعة صرف (نص راتب / كاش + بنك)
```dart
final remaining = await PaymentStorage().getRemainingBalance(record.id, record.netSalary);

final saved = await showDialog<bool>(
  context: context,
  builder: (_) => RecordPaymentDialog(record: record, remainingBalance: remaining),
);
```
تقدر تنادي `RecordPaymentDialog` أكتر من مرة على نفس الراتب - كل مرة
بتسجل دفعة جديدة، والمتبقي بيتحدث تلقائيًا.

## 4) تقرير الكاش مقابل البنك في شهر معيّن
```dart
final totals = await PaymentStorage().getMonthlyPaymentTotals(7, 2026);
// totals['cash'] , totals['bank']
```
اربطها في `reports_page.dart` بدل البيانات الوهمية الموجودة.

## 5) النسخ الاحتياطي والاستيراد الجماعي
أضف زرار في `settings_page.dart` يودّي لـ `DataToolsPage`:
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => const DataToolsPage()));
```
فيها 3 حاجات جاهزة: تصدير نسخة احتياطية، استرجاع (دمج أو استبدال كامل)،
واستيراد موظفين من Excel.

⚠️ **ملحوظة أمان مهمة**: النسخة الاحتياطية بتشمل الموظفين والمرتبات
والدفعات والحضور - **مش بتشمل الترخيص ولا المستخدمين وكلمات السر** عمدًا،
عشان محدش ياخد نسخة احتياطية من جهاز مرخّص ويستخدمها كترخيص على جهاز تاني.

## 6) قالب ملف الاستيراد الجماعي (Excel)
أول صف Header، والأعمدة بالترتيب ده بالظبط:
```
name | department | jobTitle | nationalId | hireDate | contractType |
employeeType | insuranceCode | basicSalary | allowances | deductions |
salaryType | paymentMethod | bankName | bankAccount | bankSwift | bankIban
```
`name` بس إلزامي - أي عمود تاني فاضي هياخد قيمة افتراضية.

## 7) مكتبات إضافية مطلوبة
كله موجود بالفعل في `pubspec.yaml` بتاعك (`excel`, `file_picker`, `uuid`) -
مفيش مكتبات جديدة محتاجة تتضاف.
