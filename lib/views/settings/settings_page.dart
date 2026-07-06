// lib/views/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../services/tax_service.dart';
import '../../services/insurance_service.dart';
import '../../core/utils/logger.dart';

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
    _insuranceEmployeeController.text = (_insuranceService.employeeRate * 100).toStringAsFixed(2);
    _insuranceCompanyController.text = (_insuranceService.companyRate * 100).toStringAsFixed(2);
    _overtimeRateController.text = _taxService.overtimeRate.toStringAsFixed(2);
    _latePenaltyController.text = _taxService.latePenalty.toStringAsFixed(2);
    _minInsuranceController.text = _insuranceService.minInsurance.toStringAsFixed(2);
    _maxInsuranceController.text = _insuranceService.maxInsurance.toStringAsFixed(2);
  }

  Future<void> _saveSettings() async {
    try {
      _taxService.taxRate = double.parse(_taxRateController.text) / 100;
      _insuranceService.employeeRate = double.parse(_insuranceEmployeeController.text) / 100;
      _insuranceService.companyRate = double.parse(_insuranceCompanyController.text) / 100;
      _taxService.overtimeRate = double.parse(_overtimeRateController.text);
      _taxService.latePenalty = double.parse(_latePenaltyController.text);
      _insuranceService.minInsurance = double.parse(_minInsuranceController.text);
      _insuranceService.maxInsurance = double.parse(_maxInsuranceController.text);

      await _taxService.saveSettings();
      await _insuranceService.saveSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ الإعدادات بنجاح')),
        );
      }
      
      Logger.info('✅ Settings saved successfully');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في حفظ الإعدادات: $e')),
        );
      }
      Logger.error('❌ Failed to save settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== الضرائب =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'tax_settings'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _taxRateController,
                      label: 'tax_rate'.tr(),
                      suffix: '%',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _overtimeRateController,
                      label: 'overtime_rate'.tr(),
                      suffix: 'x',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _latePenaltyController,
                      label: 'late_penalty'.tr(),
                      suffix: 'EGP',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ===== التأمينات =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'insurance_settings'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _insuranceEmployeeController,
                      label: 'insurance_employee'.tr(),
                      suffix: '%',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _insuranceCompanyController,
                      label: 'insurance_company'.tr(),
                      suffix: '%',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _minInsuranceController,
                      label: 'min_insurance'.tr(),
                      suffix: 'EGP',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _maxInsuranceController,
                      label: 'max_insurance'.tr(),
                      suffix: 'EGP',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ===== زر الحفظ =====
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'save_settings'.tr(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      keyboardType: TextInputType.number,
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