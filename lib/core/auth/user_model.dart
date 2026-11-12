class AppUser {
  final String id;
  final String username;
  final String passwordHash; // مشتق بـ PBKDF2 - أبدًا متسيبش الباسورد صريح
  final String salt;
  final String roleId;
  final bool isActive;
  final DateTime createdAt;

  /// لو true: لازم المستخدم يغيّر كلمة المرور قبل ما يستخدم البرنامج
  /// (بيتفعّل لحساب admin الافتراضي ولأي كلمة مرور اتعمل لها reset).
  final bool mustChangePassword;
  final int failedAttempts;
  final DateTime? lockedUntil;

  const AppUser({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.roleId,
    required this.createdAt,
    this.isActive = true,
    this.mustChangePassword = false,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'passwordHash': passwordHash,
        'salt': salt,
        'roleId': roleId,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'mustChangePassword': mustChangePassword ? 1 : 0,
        'failedAttempts': failedAttempts,
        'lockedUntil': lockedUntil?.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'],
        username: map['username'],
        passwordHash: map['passwordHash'],
        salt: map['salt'],
        roleId: map['roleId'],
        isActive: map['isActive'] == 1,
        createdAt: DateTime.parse(map['createdAt']),
        mustChangePassword: (map['mustChangePassword'] ?? 0) == 1,
        failedAttempts: (map['failedAttempts'] ?? 0) as int,
        lockedUntil: map['lockedUntil'] == null
            ? null
            : DateTime.tryParse(map['lockedUntil'] as String),
      );
}
