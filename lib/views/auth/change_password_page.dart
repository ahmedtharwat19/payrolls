// lib/views/auth/change_password_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';

/// شاشة تغيير كلمة المرور. لو [forced] = true (أول دخول أو بعد reset)
/// المستخدم مينفعش يرجع منها ولا يكمل للبرنامج إلا بعد التغيير.
class ChangePasswordPage extends StatefulWidget {
  final bool forced;
  final Widget? nextPage;
  const ChangePasswordPage({super.key, this.forced = false, this.nextPage});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _errorKey;
  bool _loading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _errorKey = 'auth_error_password_mismatch');
      return;
    }
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    final auth = context.read<AuthService>();
    final result = await auth.changeOwnPassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result != 'ok') {
      setState(() => _errorKey = result);
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('password_changed_ok'.tr())));
    if (widget.nextPage != null) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.nextPage!));
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          title: Text('change_password'.tr()),
          automaticallyImplyLeading: !widget.forced,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.forced) ...[
                    Text('must_change_password_hint'.tr(),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _currentCtrl,
                    obscureText: true,
                    decoration:
                        InputDecoration(labelText: 'current_password'.tr()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newCtrl,
                    obscureText: true,
                    decoration:
                        InputDecoration(labelText: 'new_password'.tr()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration:
                        InputDecoration(labelText: 'confirm_password'.tr()),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 8),
                  Text('password_policy_hint'.tr(),
                      style: Theme.of(context).textTheme.bodySmall),
                  if (_errorKey != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorKey!.tr(),
                        style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('save'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
