import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';

class LoginPage extends StatefulWidget {
  final Widget homeAfterLogin;
  const LoginPage({super.key, required this.homeAfterLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _errorKey;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });

    final auth = context.read<AuthService>();
    final result = await auth.login(_userCtrl.text.trim(), _passCtrl.text);

    setState(() => _loading = false);

    if (result == 'ok') {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.homeAfterLogin),
      );
    } else {
      setState(() => _errorKey = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text('login_title'.tr(), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                TextField(
                  controller: _userCtrl,
                  decoration: InputDecoration(labelText: 'username'.tr()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'password'.tr()),
                  onSubmitted: (_) => _submit(),
                ),
                if (_errorKey != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorKey!.tr(), style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('login_button'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
