class AppUser {
  final String id;
  final String username;
  final String passwordHash; // Salted hash - أبدًا متسيبش الباسورد صريح
  final String salt;
  final String roleId;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.roleId,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'passwordHash': passwordHash,
        'salt': salt,
        'roleId': roleId,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'],
        username: map['username'],
        passwordHash: map['passwordHash'],
        salt: map['salt'],
        roleId: map['roleId'],
        isActive: map['isActive'] == 1,
        createdAt: DateTime.parse(map['createdAt']),
      );
}
