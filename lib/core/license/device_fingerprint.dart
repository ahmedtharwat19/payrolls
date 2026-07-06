import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';

/// بيولّد رقم شبه-فريد لكل جهاز/متصفح (مايتغيرش لو التطبيق اتقفل وفتح تاني
/// على نفس الجهاز ونفس المتصفح).
///
/// ⚠️ ملحوظة مهمة على الويب: بصمة المتصفح أضعف بكتير من بصمة جهاز حقيقي
/// (لو العميل مسح بيانات المتصفح أو فتح من متصفح تاني، هتتغير البصمة ويحتاج
/// تفعيل تاني). ده قيد طبيعي في أي نظام ترخيص أوفلاين شغال من المتصفح.
class DeviceFingerprint {
  static Future<String> get() async {
    final info = DeviceInfoPlugin();
    String raw;

    if (kIsWeb) {
      final w = await info.webBrowserInfo;
      raw = '${w.browserName}-${w.platform}-${w.vendor}-${w.userAgent}';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          final win = await info.windowsInfo;
          raw = win.deviceId;
          break;
        case TargetPlatform.linux:
          final lin = await info.linuxInfo;
          raw = lin.machineId ?? lin.id;
          break;
        case TargetPlatform.macOS:
          final mac = await info.macOsInfo;
          raw = mac.systemGUID ?? mac.computerName;
          break;
        case TargetPlatform.android:
          final and = await info.androidInfo;
          raw = and.id;
          break;
        case TargetPlatform.iOS:
          final ios = await info.iosInfo;
          raw = ios.identifierForVendor ?? 'unknown-ios';
          break;
        default:
          raw = 'unknown-platform';
      }
    }

    // نعمل hash قصير وسهل النسخ بدل السلسلة الطويلة
    final digest = sha256.convert(utf8.encode(raw));
    return digest.toString().substring(0, 24).toUpperCase();
  }
}
