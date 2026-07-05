import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// بيولّد رقم فريد وثابت لكل جهاز (مايتغيرش لو التطبيق اتقفل وفتح تاني).
/// ده اللي بيتبعته العميل لك عشان تولّدله كود التفعيل.
class DeviceFingerprint {
  static Future<String> get() async {
    final info = DeviceInfoPlugin();
    String raw;

    if (Platform.isWindows) {
      final w = await info.windowsInfo;
      raw = w.deviceId; // معرف ثابت للجهاز
    } else if (Platform.isLinux) {
      final l = await info.linuxInfo;
      raw = l.machineId ?? l.id;
    } else if (Platform.isMacOS) {
      final m = await info.macOsInfo;
      raw = m.systemGUID ?? m.computerName;
    } else if (Platform.isAndroid) {
      final a = await info.androidInfo;
      raw = a.id; // Android ID
    } else if (Platform.isIOS) {
      final i = await info.iosInfo;
      raw = i.identifierForVendor ?? 'unknown-ios';
    } else {
      raw = 'unknown-platform';
    }

    // نعمل hash قصير وسهل النسخ بدل السلسلة الطويلة
    final digest = sha256.convert(utf8.encode(raw));
    return digest.toString().substring(0, 24).toUpperCase();
  }
}
