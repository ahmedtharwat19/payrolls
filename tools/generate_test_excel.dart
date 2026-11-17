// tools/generate_50_employees.dart
//
// يولّد ملف test_employees_50.xlsx فيه 50 موظف عشوائي.
// التشغيل: dart run tools/generate_50_employees.dart

import 'dart:io';
import 'dart:math';
import 'package:excel/excel.dart';

void main() {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];

  // ============================================================
  // العناوين
  // ============================================================
  final headers = [
    'الاسم بالعربية',
    'الاسم بالإنجليزية',
    'القسم',
    'المسمى الوظيفي',
    'تاريخ التعيين',
    'الرقم القومي',
    'نوع العقد',
    'نوع الموظف',
    'الراتب الأساسي',
    'المتغير',
    'البدلات',
    'الخصومات',
    'المصروفات',
    'تأمينات ثابتة',
    'نوع الراتب',
    'طريقة الدفع',
    'اسم البنك',
    'رقم الحساب',
    'كود Swift',
    'IBAN',
    'نشط'
  ];
  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

  // ============================================================
  // قوائم الأسماء (20 ذكور + 20 إناث = 40 اسم أول)
  // ============================================================
  final maleFirstAr = [
    'أحمد',
    'محمد',
    'محمود',
    'علي',
    'حسن',
    'عمر',
    'خالد',
    'يوسف',
    'كريم',
    'طارق',
    'حسام',
    'مصطفى',
    'إبراهيم',
    'وليد',
    'سامي',
    'هشام',
    'عبدالله',
    'معاذ',
    'زياد',
    'بلال'
  ];
  final maleFirstEn = [
    'Ahmed',
    'Mohamed',
    'Mahmoud',
    'Ali',
    'Hassan',
    'Omar',
    'Khaled',
    'Youssef',
    'Karim',
    'Tarek',
    'Hossam',
    'Mostafa',
    'Ibrahim',
    'Walid',
    'Samy',
    'Hesham',
    'Abdullah',
    'Moaz',
    'Ziad',
    'Bilal'
  ];

  final femaleFirstAr = [
    'سارة',
    'منى',
    'نورا',
    'ليلى',
    'مريم',
    'هدير',
    'رنا',
    'هبة',
    'دينا',
    'ياسمين',
    'سلمى',
    'فاطمة',
    'أمل',
    'إيمان',
    'رحمة',
    'شيماء',
    'نادية',
    'دعاء',
    'آية',
    'جنة'
  ];
  final femaleFirstEn = [
    'Sarah',
    'Mona',
    'Noura',
    'Laila',
    'Mariam',
    'Hadir',
    'Rana',
    'Heba',
    'Dina',
    'Yasmine',
    'Salma',
    'Fatma',
    'Amal',
    'Eman',
    'Rahma',
    'Shaimaa',
    'Nadia',
    'Doaa',
    'Aya',
    'Jana'
  ];

  // ============================================================
  // الأسماء الأخيرة (30 اسم - كافية لتنوع كبير)
  // ============================================================
  final lastNamesAr = [
    'محمود',
    'علي',
    'حسن',
    'إبراهيم',
    'خالد',
    'سمير',
    'أشرف',
    'حسام',
    'مصطفى',
    'عبدالله',
    'عبدالرحمن',
    'الشريف',
    'السيد',
    'فؤاد',
    'كمال',
    'منصور',
    'رشاد',
    'سعيد',
    'جمعة',
    'عبدالعزيز',
    'فهمي',
    'شعبان',
    'النجار',
    'الصياد',
    'الحداد',
    'عوض',
    'سليمان',
    'عامر',
    'الشامي',
    'الجندي'
  ];
  final lastNamesEn = [
    'Mahmoud',
    'Ali',
    'Hassan',
    'Ibrahim',
    'Khaled',
    'Samir',
    'Ashraf',
    'Hossam',
    'Mostafa',
    'Abdullah',
    'Abdelrahman',
    'ElSherif',
    'ElSayed',
    'Fouad',
    'Kamal',
    'Mansour',
    'Rashad',
    'Said',
    'Gomaa',
    'Abdelaziz',
    'Fahmy',
    'Shaaban',
    'ElNagar',
    'ElSayed',
    'ElHadad',
    'Awad',
    'Soliman',
    'Amer',
    'ElShamy',
    'ElGendy'
  ];

  // ============================================================
  // الأقسام والمسميات الوظيفية
  // ============================================================
  final departments = [
    'IT',
    'HR',
    'Sales',
    'Finance',
    'Marketing',
    'Operations'
  ];

  final jobTitles = {
    'IT': [
      'Software Engineer',
      'Frontend Developer',
      'Backend Developer',
      'DevOps Engineer',
      'QA Engineer',
      'Mobile Developer'
    ],
    'HR': [
      'HR Manager',
      'HR Specialist',
      'Recruiter',
      'Payroll Specialist',
      'Training Coordinator'
    ],
    'Sales': [
      'Sales Manager',
      'Sales Rep',
      'Account Manager',
      'Sales Director',
      'Business Development'
    ],
    'Finance': [
      'Accountant',
      'Financial Analyst',
      'Auditor',
      'CFO',
      'Treasury Officer'
    ],
    'Marketing': [
      'Marketing Manager',
      'Content Creator',
      'SEO Specialist',
      'Social Media Manager',
      'Brand Manager'
    ],
    'Operations': [
      'Operations Manager',
      'Coordinator',
      'Logistics Specialist',
      'Supply Chain Officer',
      'Facility Manager'
    ],
  };

  // ============================================================
  // البنوك
  // ============================================================
  final banks = [
    {'name': 'CIB', 'swift': 'CIBEEGCX'},
    {'name': 'QNB', 'swift': 'QNBAEGCX'},
    {'name': 'NBE', 'swift': 'NBEGEGCX'},
    {'name': 'Banque Misr', 'swift': 'BMISEGCX'},
    {'name': 'HSBC', 'swift': 'HSBCEGCX'},
    {'name': 'Alex Bank', 'swift': 'ALEXEGCX'},
  ];

  final rnd = Random();

  // ============================================================
  // توليد 50 موظف
  // ============================================================
  for (int i = 0; i < 50; i++) {
    // --- اسم عشوائي (ذكر أو أنثى) ---
    final isMale = rnd.nextBool();
    final firstIdx = rnd.nextInt(20);
    final lastIdx = rnd.nextInt(30);

    final nameAr =
        '${(isMale ? maleFirstAr : femaleFirstAr)[firstIdx]} ${lastNamesAr[lastIdx]}';
    final nameEn =
        '${(isMale ? maleFirstEn : femaleFirstEn)[firstIdx]} ${lastNamesEn[lastIdx]}';

    // --- قسم ومسمى وظيفي ---
    final dept = departments[rnd.nextInt(departments.length)];
    final titlesForDept = jobTitles[dept]!;
    final jobTitle = titlesForDept[rnd.nextInt(titlesForDept.length)];

    // --- تاريخ تعيين عشوائي (2018 إلى 2024) ---
    final year = 2018 + rnd.nextInt(7);
    final month = 1 + rnd.nextInt(12);
    final day = 1 + rnd.nextInt(28);
    final hireDate =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    // --- رقم قومي (14 رقم - مصري تقريبي) ---
    final nationalId =
        '2${rnd.nextInt(10)}${rnd.nextInt(10)}${rnd.nextInt(10)}${rnd.nextInt(10)}'
        '${rnd.nextInt(10)}${rnd.nextInt(10)}${rnd.nextInt(10)}${rnd.nextInt(10)}'
        '${rnd.nextInt(10)}${rnd.nextInt(10)}${rnd.nextInt(10)}${rnd.nextInt(10)}'
        '${rnd.nextInt(10)}';

    // --- نوع العقد ونوع الموظف ---
    final contractTypes = ['permanent', 'temporary', 'contract'];
    final contractType = contractTypes[rnd.nextInt(contractTypes.length)];

    final employeeTypes = ['full-time', 'part-time', 'intern'];
    final employeeType = employeeTypes[rnd.nextInt(employeeTypes.length)];

    // --- الراتب الأساسي (6000 - 35000) ---
    final basicSalary = (6000 + rnd.nextInt(29000)).toDouble();

    // --- المتغير (50% فرصة إن يكون فيه) ---
    final variableSalary =
        rnd.nextBool() ? (1000 + rnd.nextInt(5000)).toDouble() : 0.0;

    // --- البدلات (70% فرصة) ---
    final allowances =
        rnd.nextInt(10) < 7 ? (500 + rnd.nextInt(4500)).toDouble() : 0.0;

    // --- الخصومات (30% فرصة) ---
    final deductions = rnd.nextInt(10) < 3 ? rnd.nextInt(1500).toDouble() : 0.0;

    // --- المصروفات (20% فرصة) ---
    final expenses = rnd.nextInt(10) < 2 ? rnd.nextInt(800).toDouble() : 0.0;

    // --- التأمينات الثابتة (30% فرصة) ---
    final fixedInsurance =
        rnd.nextInt(10) < 3 ? (500 + rnd.nextInt(1500)).toDouble() : 0.0;

    // --- نوع الراتب ---
    final salaryType = rnd.nextBool() ? 'net' : 'gross';

    // --- طريقة الدفع ---
    final isBank = rnd.nextInt(10) < 7; // 70% بنك
    final paymentMethod = isBank ? 'bank' : 'cash';

    String bankName = '';
    String bankAccount = '';
    String bankSwift = '';
    String bankIban = '';

    if (isBank) {
      final bank = banks[rnd.nextInt(banks.length)];
      bankName = bank['name']!;
      bankSwift = bank['swift']!;
      bankAccount = '${1000000000 + rnd.nextInt(900000000)}';
      bankIban = 'EG38${rnd.nextInt(1000).toString().padLeft(4, '0')}'
          '${rnd.nextInt(1000).toString().padLeft(4, '0')}'
          '${rnd.nextInt(10000).toString().padLeft(4, '0')}'
          '${rnd.nextInt(10000).toString().padLeft(4, '0')}'
          '${rnd.nextInt(100).toString().padLeft(2, '0')}';
    }

    // --- الحالة (90% نشط) ---
    final isActive = rnd.nextInt(10) < 9;

    // ============================================================
    // إضافة الصف
    // ============================================================
    sheet.appendRow([
      TextCellValue(nameAr),
      TextCellValue(nameEn),
      TextCellValue(dept),
      TextCellValue(jobTitle),
      TextCellValue(hireDate),
      TextCellValue(nationalId),
      TextCellValue(contractType),
      TextCellValue(employeeType),
      DoubleCellValue(basicSalary),
      DoubleCellValue(variableSalary),
      DoubleCellValue(allowances),
      DoubleCellValue(deductions),
      DoubleCellValue(expenses),
      DoubleCellValue(fixedInsurance),
      TextCellValue(salaryType),
      TextCellValue(paymentMethod),
      TextCellValue(bankName),
      TextCellValue(bankAccount),
      TextCellValue(bankSwift),
      TextCellValue(bankIban),
      TextCellValue(isActive ? 'true' : 'false'),
    ]);
  }

  // ============================================================
  // حفظ الملف
  // ============================================================
  final bytes = excel.encode();
  if (bytes != null) {
    final file = File('test_employees_50.xlsx');
    file.writeAsBytesSync(bytes);
    print('✅ اتولّد الملف: ${file.absolute.path}');
    print('📊 عدد الموظفين: 50');
    print('📁 حجم الملف: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
  }
}
