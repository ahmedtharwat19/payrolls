// lib/views/users/users_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/audit/audit_log.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/permission.dart';
import '../../core/auth/role.dart';
import '../../core/auth/user_model.dart';

/// إدارة المستخدمين + عرض سجل التدقيق. متاحة لمن عنده manageUsers فقط.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<AppUser> _users = [];
  List<Role> _roles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final auth = context.read<AuthService>();
    final users = await auth.listUsers();
    final roles = await auth.listRoles();
    if (!mounted) return;
    setState(() {
      _users = users;
      _roles = roles;
      _loading = false;
    });
  }

  void _toast(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(key == 'ok' ? 'saved_ok'.tr() : key.tr())),
    );
  }

  Future<void> _addUser() async {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String roleId = _roles.any((r) => r.id == 'viewer')
        ? 'viewer'
        : (_roles.isNotEmpty ? _roles.first.id : 'viewer');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('add_user'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: 'username'.tr())),
              TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration:
                      InputDecoration(labelText: 'temporary_password'.tr())),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('role'.tr(),
                    style: Theme.of(ctx).textTheme.bodySmall),
              ),
              // DropdownButton (بدل DropdownButtonFormField) عشان `value`
              // فيها شغّالة على كل إصدارات Flutter بدون تحذيرات deprecated.
              DropdownButton<String>(
                isExpanded: true,
                value: roleId,
                items: [
                  for (final r in _roles)
                    DropdownMenuItem(value: r.id, child: Text(r.name.tr())),
                ],
                onChanged: (v) => setLocal(() => roleId = v ?? roleId),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr())),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('save'.tr())),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final result = await context.read<AuthService>().createUser(
          username: nameCtrl.text,
          password: passCtrl.text,
          roleId: roleId,
        );
    _toast(result);
    await _reload();
  }

  Future<void> _resetPassword(AppUser u) async {
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${'reset_password'.tr()}: ${u.username}'),
        content: TextField(
            controller: passCtrl,
            obscureText: true,
            decoration:
                InputDecoration(labelText: 'temporary_password'.tr())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('save'.tr())),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _toast(await context
        .read<AuthService>()
        .adminResetPassword(userId: u.id, newPassword: passCtrl.text));
    await _reload();
  }

  Future<void> _confirmDelete(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text(u.username),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('delete'.tr())),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _toast(await context.read<AuthService>().deleteUser(u.id));
    await _reload();
  }

  Future<void> _showAudit() async {
    final rows = await AuditLog.recent(limit: 300);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('audit_log'.tr()),
        content: SizedBox(
          width: 640,
          height: 440,
          child: rows.isEmpty
              ? Center(child: Text('no_data'.tr()))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return ListTile(
                      dense: true,
                      title: Text('${r['action']}'),
                      subtitle: Text(
                          '${r['at']}  •  ${r['username'] ?? '-'}  ${r['details'] ?? ''}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text('close'.tr())),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.can(Permission.manageUsers)) {
      return Center(child: Text('auth_error_forbidden'.tr()));
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('users_management'.tr()),
        actions: [
          IconButton(
              onPressed: _showAudit,
              icon: const Icon(Icons.history),
              tooltip: 'audit_log'.tr()),
          IconButton(
              onPressed: _addUser,
              icon: const Icon(Icons.person_add),
              tooltip: 'add_user'.tr()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = _users[i];
                final isSelf = u.id == auth.currentUser?.id;
                return ListTile(
                  leading: Icon(u.isActive ? Icons.person : Icons.person_off),
                  title: Text(u.username + (isSelf ? '  (you)' : '')),
                  subtitle: Text([
                    u.roleId,
                    if (u.mustChangePassword) 'must_change_password'.tr(),
                    if (u.isLocked) 'auth_error_locked'.tr(),
                  ].join('  •  ')),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.key),
                        tooltip: 'reset_password'.tr(),
                        onPressed: () => _resetPassword(u),
                      ),
                      Switch(
                        value: u.isActive,
                        onChanged: isSelf
                            ? null
                            : (v) async {
                                _toast(await context
                                    .read<AuthService>()
                                    .setUserActive(u.id, v));
                                await _reload();
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: isSelf ? null : () => _confirmDelete(u),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
