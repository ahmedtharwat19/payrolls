class LicenseData {
  final String customerName;
  final int maxUsers;
  final int maxDevices;
  final DateTime? expiryDate; // null = ترخيص دائم
  final List<String> features;

  const LicenseData({
    required this.customerName,
    required this.maxUsers,
    required this.maxDevices,
    this.expiryDate,
    this.features = const [],
  });

  bool get isExpired => expiryDate != null && DateTime.now().isAfter(expiryDate!);

  Map<String, dynamic> toJson() => {
        'customerName': customerName,
        'maxUsers': maxUsers,
        'maxDevices': maxDevices,
        'expiryDate': expiryDate?.toIso8601String(),
        'features': features,
      };

  factory LicenseData.fromJson(Map<String, dynamic> json) => LicenseData(
        customerName: json['customerName'],
        maxUsers: json['maxUsers'],
        maxDevices: json['maxDevices'],
        expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : null,
        features: List<String>.from(json['features'] ?? []),
      );
}

/// نتيجة عملية التحقق من الترخيص - بترجع للـ UI عشان تعرض رسالة واضحة.
class LicenseCheckResult {
  final bool isValid;
  final String message;
  const LicenseCheckResult(this.isValid, this.message);
}
