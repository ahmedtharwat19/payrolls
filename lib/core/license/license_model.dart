class LicenseData {
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
