// أداة سطر أوامر - تشتغل عندك انت (المطوّر) بس، ومش بتتنقل مع التطبيق.
//
// طريقة التشغيل:
//   1) توليد زوج مفاتيح لأول مرة (مرة واحدة بس طول عمر المشروع):
//      dart run tools/license_generator.dart keys
//
//   2) توليد كود تفعيل لعميل/جهاز معيّن حسب نوع الخطة:
//      dart run tools/license_generator.dart activate \
//          "اسم الشركة" <أقصى مستخدمين> <أقصى أجهزة> <الخطة> \
//          <بصمة الجهاز> <رقم السلوت>
//
//      الخطة (<الخطة>) ممكن تكون:
//        demo        → نسخة تجريبية 7 أيام (مرة واحدة بس لكل جهاز - مؤمّنة)
//        monthly     → شهر واحد من النهاردة
//        quarterly   → 3 شهور من النهاردة
//        semiannual  → 6 شهور من النهاردة
//        yearly      → سنة من النهاردة
//        none        → ترخيص دائم (بدون انتهاء)
//        أو تاريخ محدد بنفسك بالصيغة: 2026-12-31
//
//      أمثلة:
//      dart run tools/license_generator.dart activate "شركة أحمد" 5 3 demo A1B2C3D4E5F6 1
//      dart run tools/license_generator.dart activate "شركة أحمد" 5 3 yearly A1B2C3D4E5F6 1
//
//      ⚠️ الكود الناتج مربوط ببصمة الجهاز اللي كتبتها بس - مش هيشتغل على
//      جهاز تاني.
//
//      ⚠️ خطة الديمو: الأداة بتحتفظ بدفتر محلي (issued_demos.txt) بكل
//      بصمة جهاز أخدت ديمو قبل كده. لو حاولت تولّد ديمو تاني لنفس البصمة،
//      هتوقفك وتحذّرك (والتطبيق نفسه كمان بيرفض ديمو تاني على نفس الجهاز
//      حتى لو ولّدتلها كود - طبقة حماية مزدوجة).

import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';

final _algorithm = Ed25519();
const _demoDays = 7;

const _planMonths = {
  'monthly': 1,
  'quarterly': 3,
  'semiannual': 6,
  'yearly': 12,
};

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('استخدم: keys | activate - راجع التعليقات في أعلى الملف');
    return;
  }

  switch (args[0]) {
    case 'keys':
      await _generateKeys();
      break;
    case 'activate':
      await _generateActivationCode(args.sublist(1));
      break;
    default:
      print('أمر غير معروف: ${args[0]}');
  }
}

Future<void> _generateKeys() async {
  final keyPair = await _algorithm.newKeyPair();
  final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
  final publicKey = await keyPair.extractPublicKey();

  final privateB64 = base64Url.encode(privateKeyBytes);
  final publicB64 = base64Url.encode(publicKey.bytes);

  print('احفظ ده في مكان آمن جدًا (متسيبوش في أي كود هيترفع GitHub):');
  print('PRIVATE_KEY = $privateB64');
  print('');
  print('وده حطه في lib/core/license/license_service.dart بدل _publicKeyBase64:');
  print('PUBLIC_KEY  = $publicB64');

  File('license_keys.txt').writeAsStringSync('PRIVATE_KEY=$privateB64\nPUBLIC_KEY=$publicB64\n');
  print('\n✅ اتحفظوا كمان في license_keys.txt - ضيفه في .gitignore فورًا!');
}

Future<void> _generateActivationCode(List<String> args) async {
  if (args.length < 6) {
    print('استخدم: activate "اسم الشركة" <أقصى مستخدمين> <أقصى أجهزة> '
        '<demo|monthly|quarterly|semiannual|yearly|none|تاريخ محدد> <بصمة الجهاز> <رقم السلوت>');
    return;
  }

  final customerName = args[0];
  final maxUsers = int.parse(args[1]);
  final maxDevices = int.parse(args[2]);
  final planOrDate = args[3];
  final deviceFingerprint = args[4];
  final slotNumber = int.parse(args[5]);

  // حماية إضافية: منع تكرار توليد ديمو لنفس بصمة الجهاز من عندك انت
  if (planOrDate == 'demo') {
    final ledger = File('issued_demos.txt');
    final issued = ledger.existsSync() ? ledger.readAsLinesSync() : <String>[];
    if (issued.contains(deviceFingerprint)) {
      print('⚠️  الجهاز ده أخد نسخة ديمو قبل كده (موجود في issued_demos.txt).');
      print('    التطبيق نفسه هيرفض أي حال، بس الأداة وقفتك الأول تجنبًا لتضييع وقتك.');
      return;
    }
  }

  int? totalDays;
  String planLabel;

  if (planOrDate == 'none') {
    totalDays = null;
    planLabel = 'lifetime';
  } else if (planOrDate == 'demo') {
    totalDays = _demoDays;
    planLabel = 'demo';
  } else if (_planMonths.containsKey(planOrDate)) {
    final months = _planMonths[planOrDate]!;
    final target = _addMonths(DateTime.now(), months);
    totalDays = target.difference(DateTime.now()).inDays;
    planLabel = planOrDate;
  } else {
    // اتفرض إنه تاريخ محدد بصيغة YYYY-MM-DD
    final target = DateTime.parse(planOrDate);
    totalDays = target.difference(DateTime.now()).inDays;
    planLabel = 'custom';
  }

  final payload = {
    'customerName': customerName,
    'maxUsers': maxUsers,
    'maxDevices': maxDevices,
    'totalDays': totalDays,
    'plan': planLabel,
    'deviceFingerprint': deviceFingerprint,
    'slotNumber': slotNumber,
  };

  final code = await _sign(payload);

  if (planLabel == 'demo') {
    File('issued_demos.txt').writeAsStringSync('$deviceFingerprint\n', mode: FileMode.append);
  }

  print('الخطة: $planLabel${totalDays != null ? ' - $totalDays يوم' : ' (دائم)'}');
  print('كود التفعيل (خاص بالجهاز ده بس، ابعته للعميل يدخله في التطبيق):\n');
  print(code);

  // بيتكتب هنا بترميز UTF-8 صحيح من الأداة نفسها - عشان نتجنب مشاكل
  // ترميز الـ PowerShell لما بنستخدم > أو Out-File.
  File('activation_code.txt').writeAsStringSync(code);
  print('\n✅ الكود اتكتب كمان في activation_code.txt (بترميز سليم).');
}

/// بيضيف عدد شهور لتاريخ معيّن، مع مراعاة تغيير السنة وعدد أيام الشهر.
DateTime _addMonths(DateTime date, int months) {
  final totalMonths = date.month - 1 + months;
  final newYear = date.year + totalMonths ~/ 12;
  final newMonth = totalMonths % 12 + 1;
  final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
  final newDay = date.day > daysInNewMonth ? daysInNewMonth : date.day;
  return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second);
}

Future<String> _sign(Map<String, dynamic> payload) async {
  final privateKeyLine = File('license_keys.txt')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('PRIVATE_KEY='));
  final privateKeyB64 = privateKeyLine.substring(privateKeyLine.indexOf('=') + 1);

  final keyPair = await _algorithm.newKeyPairFromSeed(base64Url.decode(privateKeyB64));

  final payloadBytes = utf8.encode(jsonEncode(payload));
  final signature = await _algorithm.sign(payloadBytes, keyPair: keyPair);

  final payloadB64 = base64Url.encode(payloadBytes);
  final sigB64 = base64Url.encode(signature.bytes);

  return '$payloadB64.$sigB64';
}
