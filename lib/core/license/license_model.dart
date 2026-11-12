/* class LicenseData {
  final String customerName;
  final int maxUsers;
  final int maxDevices;
  final int? totalDays; // null = ترخيص دائم. غير كده = عدد أيام العد التنازلي
  final String plan; // 'demo' | 'monthly' | 'quarterly' | 'semiannual' | 'yearly' | 'custom' | 'lifetime'
  final List<String> features;

  const LicenseData({
    required this.customerName,
    required this.maxUsers,
    required this.maxDevices,
    this.totalDays,
    this.plan = 'custom',
    this.features = const [],
  });

  /// مفتاح ترجمة لاسم الخطة - استخدمه: license.planLabelKey.tr()
  String get planLabelKey => 'plan_$plan';

  Map<String, dynamic> toJson() => {
        'customerName': customerName,
        'maxUsers': maxUsers,
        'maxDevices': maxDevices,
        'totalDays': totalDays,
        'plan': plan,
        'features': features,
      };

  factory LicenseData.fromJson(Map<String, dynamic> json) => LicenseData(
        customerName: json['customerName'],
        maxUsers: json['maxUsers'],
        maxDevices: json['maxDevices'],
        totalDays: json['totalDays'],
        plan: json['plan'] ?? 'custom',
        features: List<String>.from(json['features'] ?? []),
      );
}

/// نتيجة عملية التحقق من الترخيص - بترجع للـ UI عشان تعرض رسالة واضحة.
/// messageKey مفتاح ترجمة (استخدمه مع easy_localization: messageKey.tr())
class LicenseCheckResult {
  final bool isValid;
  final String messageKey;
  final int? remainingDays; // اختياري - لو حابب تعرضه في شاشة "معلومات الترخيص"
  const LicenseCheckResult(this.isValid, this.messageKey, {this.remainingDays});
}
 */
// lib/core/license/license_model.dart

class LicenseData {
  final String customerName;
  final int maxUsers;
  final int maxDevices;
  final String plan;
  final List<String> features;

  /// تاريخ إصدار الترخيص (من التوقيع). مش موجود للديمو المحلي.
  final DateTime? issuedAt;

  /// تاريخ انتهاء الترخيص المطلق (null = دائم، أو ديمو محلي).
  final DateTime? expiresAt;

  /// محفوظ للعرض فقط. القيمة الحقيقية تُحسب من expiresAt.
  /// null = lifetime أو ديمو محلي بدون expiresAt.
  final int? totalDays;

  const LicenseData({
    required this.customerName,
    required this.maxUsers,
    required this.maxDevices,
    this.plan = 'custom',
    this.features = const [],
    this.issuedAt,
    this.expiresAt,
    this.totalDays,
  });

  String get planLabelKey => 'plan_$plan';

  /// الأيام المتبقية من الآن. null = دائم/غير محدد.
  int? get computedRemainingDays {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isLifetime => expiresAt == null && plan == 'lifetime';

  Map<String, dynamic> toJson() => {
        'customerName': customerName,
        'maxUsers': maxUsers,
        'maxDevices': maxDevices,
        'plan': plan,
        'features': features,
        'issuedAt': issuedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'totalDays': totalDays,
      };

  factory LicenseData.fromJson(Map<String, dynamic> json) => LicenseData(
        customerName: json['customerName'] as String,
        maxUsers: json['maxUsers'] as int,
        maxDevices: json['maxDevices'] as int,
        plan: (json['plan'] as String?) ?? 'custom',
        features: List<String>.from(json['features'] ?? []),
        issuedAt: json['issuedAt'] != null
            ? DateTime.tryParse(json['issuedAt'] as String)
            : null,
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
        totalDays: json['totalDays'] as int?,
      );
}

class LicenseCheckResult {
  final bool isValid;
  final String messageKey;
  final int? remainingDays;

  const LicenseCheckResult(this.isValid, this.messageKey, {this.remainingDays});
}
