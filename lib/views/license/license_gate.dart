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
/* 
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
} */
// lib/views/license/license_gate.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _pickedFileName;
  bool _showAdvancedPaste = false;
  bool _demoAvailable = false;

  @override
  void initState() {
    super.initState();
    LicenseService.instance.currentDeviceFingerprint().then((fp) {
      if (mounted) setState(() => _fingerprint = fp);
    });
    LicenseService.instance.isDemoAvailable().then((available) {
      if (mounted) setState(() => _demoAvailable = available);
    });
  }

  Future<void> _startLocalDemo() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });

    final result = await LicenseService.instance.activateLocalDemo();

    setState(() => _loading = false);

    if (result == 'ok') {
      widget.onActivated();
    } else {
      setState(() {
        _errorKey = result;
        _demoAvailable = false; // اتستهلكت أو فشلت - منمنعش المحاولة تاني
      });
    }
  }

  Future<void> _pickAndActivate() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lic'],
      // ملحوظة: withData بقت deprecated في نسخ file_picker الحديثة -
      // البديل هو PlatformFile.readAsBytes() اللي بيشتغل صح على كل
      // المنصات (بما فيها الويب) من غير ما يحمّل كل حاجة في الذاكرة
      // مقدمًا زي withData القديمة.
    );

    final Uint8List bytes;
    try {
      bytes = await result.single.readAsBytes();
    } catch (_) {
      setState(() => _errorKey = 'license_error_invalid_code');
      return;
    }

    setState(() {
      _pickedFileName = result.single.name;
      _loading = true;
      _errorKey = null;
    });

    final activationResult =
        await LicenseService.instance.activateFromBytes(bytes);

    setState(() => _loading = false);

    if (activationResult == 'ok') {
      widget.onActivated();
    } else {
      setState(() => _errorKey = activationResult);
    }
  }

  Future<void> _submitPastedCode() async {
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
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

                  // بصمة الجهاز لازم تتبعت للمُصدر الأول قبل ما يولّدلك الملف
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
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'copy_button'.tr(),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _fingerprint!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('copied_message'.tr())),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ---- ديمو محلي مجاني (شهر واحد) - مباشرة من غير ملف ----
                  if (_demoAvailable) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _startLocalDemo,
                        icon: const Icon(Icons.rocket_launch_outlined),
                        label: Text('license_start_demo_button'.tr()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'license_or_divider'.tr(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ---- الطريقة الأساسية للتفعيل الرسمي: استيراد ملف .lic ----
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickAndActivate,
                    icon: const Icon(Icons.upload_file),
                    label: Text('license_pick_file_button'.tr()),
                  ),
                  if (_pickedFileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _pickedFileName!,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(
                        () => _showAdvancedPaste = !_showAdvancedPaste),
                    child: Text('license_advanced_paste_toggle'.tr()),
                  ),

                  if (_showAdvancedPaste) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'license_code_label'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _loading ? null : _submitPastedCode,
                        child: Text('activate_button'.tr()),
                      ),
                    ),
                  ],

                  if (_errorKey != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorKey!.tr(),
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (_loading) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
