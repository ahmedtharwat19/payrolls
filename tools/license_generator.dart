// أداة سطر أوامر - تشتغل عندك انت (المطوّر) بس، ومش بتتنقل مع التطبيق.
// طريقة التشغيل:
//   1) توليد زوج مفاتيح لأول مرة:
//      dart run tools/license_generator.dart keys
//      → هيطلعلك Private Key (سيبه في مكان آمن عندك) و Public Key (حطه في license_service.dart)
//
//   2) توليد ترخيص شركة جديد:
//      dart run tools/license_generator.dart license "اسم الشركة" 5 3 2026-12-31
//      (اسم الشركة، أقصى عدد مستخدمين، أقصى عدد أجهزة، تاريخ الانتهاء أو "none")
//
//   3) توليد كود تفعيل جهاز (بعد ما العميل يبعتلك بصمة جهازه):
//      dart run tools/license_generator.dart device <بصمة الجهاز> <رقم السلوت>

import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

final _algorithm = Ed25519();

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    debugPrint('استخدم: keys | license | device - راجع التعليقات في أعلى الملف');
    return;
  }

  switch (args[0]) {
    case 'keys':
      await _generateKeys();
      break;
    case 'license':
      await _generateLicense(args.sublist(1));
      break;
    case 'device':
      await _generateDeviceCode(args.sublist(1));
      break;
    default:
      debugPrint('أمر غير معروف: ${args[0]}');
  }
}

Future<void> _generateKeys() async {
  final keyPair = await _algorithm.newKeyPair();
  final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
  final publicKey = await keyPair.extractPublicKey();

  final privateB64 = base64Url.encode(privateKeyBytes);
  final publicB64 = base64Url.encode(publicKey.bytes);

  debugPrint('احفظ ده في مكان آمن جدًا (متسيبوش في أي كود هيترفع GitHub):');
  debugPrint('PRIVATE_KEY = $privateB64');
  debugPrint('');
  debugPrint('وده حطه في lib/core/license/license_service.dart بدل _publicKeyBase64:');
  debugPrint('PUBLIC_KEY  = $publicB64');

  // نحفظهم في ملف محلي كمان عشان تلاقيهم بسهولة (اتأكد إنه مش هيترفع Git)
  File('license_keys.txt').writeAsStringSync('PRIVATE_KEY=$privateB64\nPUBLIC_KEY=$publicB64\n');
  debugPrint('\n✅ اتحفظوا كمان في license_keys.txt - ضيفه في .gitignore فورًا!');
}

Future<void> _generateLicense(List<String> args) async {
  if (args.length < 4) {
    debugPrint('استخدم: license "اسم الشركة" <أقصى مستخدمين> <أقصى أجهزة> <تاريخ الانتهاء أو none>');
    return;
  }

  final payload = {
    'customerName': args[0],
    'maxUsers': int.parse(args[1]),
    'maxDevices': int.parse(args[2]),
    'expiryDate': args[3] == 'none' ? null : args[3],
    'features': <String>[],
  };

  final code = await _sign(payload);
  debugPrint('كود ترخيص الشركة (ابعته للعميل يدخله مرة واحدة):\n');
  debugPrint(code);
}

Future<void> _generateDeviceCode(List<String> args) async {
  if (args.length < 2) {
    debugPrint('استخدم: device <بصمة الجهاز اللي بعتهالك العميل> <رقم السلوت مثلاً 1>');
    return;
  }

  final payload = {
    'deviceFingerprint': args[0],
    'slotNumber': int.parse(args[1]),
  };

  final code = await _sign(payload);
  debugPrint('كود تفعيل الجهاز:\n');
  debugPrint(code);
}

Future<String> _sign(Map<String, dynamic> payload) async {
  final privateKeyLine = File('license_keys.txt')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('PRIVATE_KEY='));
  final privateKeyB64 = privateKeyLine.split('=')[1];

  final keyPair = await _algorithm.newKeyPairFromSeed(base64Url.decode(privateKeyB64));

  final payloadBytes = utf8.encode(jsonEncode(payload));
  final signature = await _algorithm.sign(payloadBytes, keyPair: keyPair);

  final payloadB64 = base64Url.encode(payloadBytes);
  final sigB64 = base64Url.encode(signature.bytes);

  return '$payloadB64.$sigB64';
}
