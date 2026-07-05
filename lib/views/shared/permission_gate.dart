import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/permission.dart';

/// استخدمه لتغليف أي زرار/شاشة عايز تظهر بس لو المستخدم عنده الصلاحية دي.
///
/// مثال:
///   PermissionGate(
///     permission: Permission.deleteEmployee,
///     child: IconButton(icon: Icon(Icons.delete), onPressed: () {}),
///   )
class PermissionGate extends StatelessWidget {
  final Permission permission;
  final Widget child;
  final Widget? fallback; // لو مفيش صلاحية، ممكن تعرض حاجة بديلة (اختياري)

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.can(permission)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
