// lib/views/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:puresip_payrolls/views/settings/backup_settings_page.dart';
import '../../services/tax_service.dart';
import '../../services/insurance_service.dart';
import '../../core/utils/logger.dart';
import '../tax_settings/tax_settings_screen.dart';
import 'company_settings_page.dart'; // ✅ تأكد إن المسار ده صح

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _taxRateController = TextEditingController();
  final _insuranceEmployeeController = TextEditingController();
  final _insuranceCompanyController = TextEditingController();
  final _overtimeRateController = TextEditingController();
  final _latePenaltyController = TextEditingController();
  final _minInsuranceController = TextEditingController();
  final _maxInsuranceController = TextEditingController();

  late TaxService _taxService;
  late InsuranceService _insuranceService;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _taxService = context.read<TaxService>();
    _insuranceService = context.read<InsuranceService>();

    _taxRateController.text = (_taxService.taxRate * 100).toStringAsFixed(2);
    _insuranceEmployeeController.text =
        (_insuranceService.employeeRate * 100).toStringAsFixed(2);
    _insuranceCompanyController.text =
        (_insuranceService.companyRate * 100).toStringAsFixed(2);
    _overtimeRateController.text = _taxService.overtimeRate.toStringAsFixed(2);
    _latePenaltyController.text = _taxService.latePenalty.toStringAsFixed(2);
    _minInsuranceController.text =
        _insuranceService.minInsurance.toStringAsFixed(2);
    _maxInsuranceController.text =
        _insuranceService.maxInsurance.toStringAsFixed(2);
  }

  Future<void> _saveSettings() async {
    try {
      _taxService.taxRate = double.parse(_taxRateController.text) / 100;
      _insuranceService.employeeRate =
          double.parse(_insuranceEmployeeController.text) / 100;
      _insuranceService.companyRate =
          double.parse(_insuranceCompanyController.text) / 100;
      _taxService.overtimeRate = double.parse(_overtimeRateController.text);
      _taxService.latePenalty = double.parse(_latePenaltyController.text);
      _insuranceService.minInsurance =
          double.parse(_minInsuranceController.text);
      _insuranceService.maxInsurance =
          double.parse(_maxInsuranceController.text);

      await _taxService.saveSettings();
      await _insuranceService.saveSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings_saved_success'.tr())), // ✅ ترجمة
        );
      }

      Logger.info('✅ Settings saved successfully');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'settings_save_error'.tr(args: [e.toString()]))), // ✅ ترجمة
        );
      }
      Logger.error('❌ Failed to save settings: $e');
    }
  }

  Future<void> _resetToEgyptianBrackets() async {
    final taxService = context.read<TaxService>();
    await taxService.resetToEgyptianBrackets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('tax_brackets_reset_success'.tr())), // ✅ ترجمة
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==========================================
          // 1. قسم بيانات الشركة (جديد)
          // ==========================================
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.business, color: theme.colorScheme.primary),
              ),
              title: Text('company_data'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('company_data_subtitle'.tr()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CompanySettingsPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 2. قسم الضرائب
          // ==========================================
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'tax_settings'.tr(),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildTextField(
                      controller: _taxRateController,
                      label: 'tax_rate'.tr(),
                      suffix: '%'),
                  const SizedBox(height: 12),
                  _buildTextField(
                      controller: _overtimeRateController,
                      label: 'overtime_rate'.tr(),
                      suffix: 'x'),
                  const SizedBox(height: 12),
                  _buildTextField(
                      controller: _latePenaltyController,
                      label: 'late_penalty'.tr(),
                      suffix: 'EGP'),
                  const SizedBox(height: 8),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit, color: Colors.orange),
                    title: Text('edit_tax_brackets'.tr()),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TaxSettingsScreen()));
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restore, color: Colors.red),
                    title: Text('reset_tax_brackets'.tr()),
                    onTap: _resetToEgyptianBrackets,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 3. قسم التأمينات
          // ==========================================
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'insurance_settings'.tr(),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildTextField(
                      controller: _insuranceEmployeeController,
                      label: 'insurance_employee'.tr(),
                      suffix: '%'),
                  const SizedBox(height: 12),
                  _buildTextField(
                      controller: _insuranceCompanyController,
                      label: 'insurance_company'.tr(),
                      suffix: '%'),
                  const SizedBox(height: 12),
                  _buildTextField(
                      controller: _minInsuranceController,
                      label: 'min_insurance'.tr(),
                      suffix: 'EGP'),
                  const SizedBox(height: 12),
                  _buildTextField(
                      controller: _maxInsuranceController,
                      label: 'max_insurance'.tr(),
                      suffix: 'EGP'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 4. قسم النسخ الاحتياطي
          // ==========================================
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.tertiary.withValues(alpha: 0.1),
                child: Icon(Icons.backup, color: theme.colorScheme.tertiary),
              ),
              title: Text('backup_settings_title'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('backup_settings_subtitle'.tr()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ==========================================
          // زر الحفظ الرئيسي
          // ==========================================
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
            child: Text(
              'save_settings'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    _insuranceEmployeeController.dispose();
    _insuranceCompanyController.dispose();
    _overtimeRateController.dispose();
    _latePenaltyController.dispose();
    _minInsuranceController.dispose();
    _maxInsuranceController.dispose();
    super.dispose();
  }
}
