/* import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/license/license_service.dart';

/// غلّف أي شاشة بيه (عادةً LoginPage أو الصفحة الرئيسية) - هيتأكد إن
/// الترخيص شغال والجهاز مُفعّل قبل ما يسمح بالدخول للتطبيق.
///
///   home: LicenseGate(child: LoginPage(...)),
class LicenseGate extends StatefulWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  bool _loading = true;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final result = await LicenseService.instance.validate();
    setState(() {
      _loading = false;
      _isValid = result.isValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isValid) return widget.child;
    return _ActivationScreen(onActivated: _check);
  }
}

class _ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;
  const _ActivationScreen({required this.onActivated});

  @override
  State<_ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<_ActivationScreen> {
  final _codeCtrl = TextEditingController();
  String? _fingerprint;
  bool _loading = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    LicenseService.instance.currentDeviceFingerprint().then((fp) {
      if (mounted) setState(() => _fingerprint = fp);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });

    final result =
        await LicenseService.instance.activate(_codeCtrl.text.trim());

    setState(() => _loading = false);

    if (result == 'ok') {
      widget.onActivated();
    } else {
      setState(() => _errorKey = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.vpn_key_outlined, size: 48),
                const SizedBox(height: 16),
                Text('license_activation_title'.tr(),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),

                // بصمة الجهاز لازم تتبعت للمُصدر الأول قبل ما يولّدلك الكود
                if (_fingerprint != null) ...[
                  Text('device_fingerprint_label'.tr(),
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _fingerprint!,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'copy_button'.tr(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _fingerprint!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('copied_message'.tr())),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                TextField(
                  controller: _codeCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'license_code_label'.tr(),
                    border: const OutlineInputBorder(),
                    prefixStyle:
                        const TextStyle(fontFamily: 'monospace', fontSize: 16),
                  ),
                ),

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
                        : Text('activate_button'.tr()),
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
 */

// lib/views/license/license_gate.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/license/license_service.dart';

/// غلّف أي شاشة بيه (عادةً LoginPage أو الصفحة الرئيسية) - هيتأكد إن
/// الترخيص شغال والجهاز مُفعّل قبل ما يسمح بالدخول للتطبيق.
///
///   home: LicenseGate(child: LoginPage(...)),
class LicenseGate extends StatefulWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  bool _loading = true;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final result = await LicenseService.instance.validate();
    setState(() {
      _loading = false;
      _isValid = result.isValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isValid) return widget.child;
    return _ActivationScreen(onActivated: _check);
  }
}

class _ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;
  const _ActivationScreen({required this.onActivated});

  @override
  State<_ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<_ActivationScreen> {
  final _codeCtrl = TextEditingController();
  String? _fingerprint;
  bool _loading = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    LicenseService.instance.currentDeviceFingerprint().then((fp) {
      if (mounted) setState(() => _fingerprint = fp);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });

    final result = await LicenseService.instance.activate(_codeCtrl.text.trim());

    setState(() => _loading = false);

    if (result == 'ok') {
      widget.onActivated();
    } else {
      setState(() => _errorKey = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(  // ✅ جعل المحتوى قابلاً للتمرير
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.vpn_key_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'license_activation_title'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // بصمة الجهاز لازم تتبعت للمُصدر الأول قبل ما يولّدلك الكود
                  if (_fingerprint != null) ...[
                    Text(
                      'device_fingerprint_label'.tr(),
                      style: Theme.of(context).textTheme.labelMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _fingerprint!,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'copy_button'.tr(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _fingerprint!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('copied_message'.tr())),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  TextField(
                    controller: _codeCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'license_code_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  if (_errorKey != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorKey!.tr(),
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('activate_button'.tr()),
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