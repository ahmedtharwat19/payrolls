// lib/views/settings/rules_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../services/tax_service.dart';
import '../../services/insurance_service.dart';

class RulesPage extends StatefulWidget {
  const RulesPage({super.key});

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  // ===== الضرائب =====
  final _taxRateController = TextEditingController();
  final _overtimeRateController = TextEditingController();
  final _latePenaltyController = TextEditingController();

  // ===== التأمينات =====
  final _insuranceEmployeeController = TextEditingController();
  final _insuranceCompanyController = TextEditingController();
  final _minInsuranceController = TextEditingController();
  final _maxInsuranceController = TextEditingController();

  // ===== شرائح الضريبة =====
  final List<TextEditingController> _bracketFromControllers = [];
  final List<TextEditingController> _bracketToControllers = [];
  final List<TextEditingController> _bracketRateControllers = [];

  // ===== البنوك =====
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankSwiftController = TextEditingController();
  final _bankIbanController = TextEditingController();

  // ===== المكافآت والخصومات =====
  final _bonusNameController = TextEditingController();
  final _bonusAmountController = TextEditingController();
  String _bonusType = 'fixed';

  final _deductionNameController = TextEditingController();
  final _deductionAmountController = TextEditingController();
  String _deductionType = 'fixed';

  // ✅ تهيئة المتغيرات مسبقاً
  late TaxService _taxService;
  late InsuranceService _insuranceService;

  final List<Map<String, dynamic>> _defaultBrackets = const [
    {'from': 0, 'to': 15000, 'rate': 0.0},
    {'from': 15000, 'to': 30000, 'rate': 0.025},
    {'from': 30000, 'to': 45000, 'rate': 0.10},
    {'from': 45000, 'to': 60000, 'rate': 0.15},
    {'from': 60000, 'to': 200000, 'rate': 0.20},
    {'from': 200000, 'to': 400000, 'rate': 0.225},
    {'from': 400000, 'to': 600000, 'rate': 0.25},
    {'from': 600000, 'to': null, 'rate': 0.275},
  ];

  @override
  void initState() {
    super.initState();
    // ✅ تهيئة الخدمات فوراً
    _taxService = context.read<TaxService>();
    _insuranceService = context.read<InsuranceService>();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _initBracketControllers();
    });
  }

  void _initBracketControllers() {
    for (int i = 0; i < _defaultBrackets.length; i++) {
      _bracketFromControllers.add(TextEditingController(
        text: _defaultBrackets[i]['from'].toString(),
      ));
      _bracketToControllers.add(TextEditingController(
        text: _defaultBrackets[i]['to']?.toString() ?? '∞',
      ));
      _bracketRateControllers.add(TextEditingController(
        text: (_defaultBrackets[i]['rate'] * 100).toStringAsFixed(2),
      ));
    }
  }

  void _loadSettings() {
    try {
      _taxRateController.text = (_taxService.taxRate * 100).toStringAsFixed(2);
      _overtimeRateController.text = _taxService.overtimeRate.toStringAsFixed(2);
      _latePenaltyController.text = _taxService.latePenalty.toStringAsFixed(2);

      _insuranceEmployeeController.text = (_insuranceService.employeeRate * 100).toStringAsFixed(2);
      _insuranceCompanyController.text = (_insuranceService.companyRate * 100).toStringAsFixed(2);
      _minInsuranceController.text = _insuranceService.minInsurance.toStringAsFixed(2);
      _maxInsuranceController.text = _insuranceService.maxInsurance.toStringAsFixed(2);

      _bankNameController.text = _taxService.bankName;
      _bankAccountController.text = _taxService.bankAccount;
      _bankSwiftController.text = _taxService.bankSwift;
      _bankIbanController.text = _taxService.bankIban;

    } catch (e) {
      _setDefaultValues();
    }
  }

  void _setDefaultValues() {
    _taxRateController.text = '0.00';
    _overtimeRateController.text = '1.50';
    _latePenaltyController.text = '50.00';
    _insuranceEmployeeController.text = '11.00';
    _insuranceCompanyController.text = '12.00';
    _minInsuranceController.text = '1000.00';
    _maxInsuranceController.text = '10000.00';
  }

  Future<void> _saveSettings() async {
    try {
      _taxService.taxRate = double.parse(_taxRateController.text) / 100;
      _taxService.overtimeRate = double.parse(_overtimeRateController.text);
      _taxService.latePenalty = double.parse(_latePenaltyController.text);

      _insuranceService.employeeRate = double.parse(_insuranceEmployeeController.text) / 100;
      _insuranceService.companyRate = double.parse(_insuranceCompanyController.text) / 100;
      _insuranceService.minInsurance = double.parse(_minInsuranceController.text);
      _insuranceService.maxInsurance = double.parse(_maxInsuranceController.text);

      _taxService.bankName = _bankNameController.text;
      _taxService.bankAccount = _bankAccountController.text;
      _taxService.bankSwift = _bankSwiftController.text;
      _taxService.bankIban = _bankIbanController.text;

      final List<Map<String, dynamic>> brackets = [];
      for (int i = 0; i < _bracketFromControllers.length; i++) {
        final from = double.tryParse(_bracketFromControllers[i].text) ?? 0;
        final toText = _bracketToControllers[i].text;
        final to = toText == '∞' ? null : double.tryParse(toText);
        final rate = (double.tryParse(_bracketRateControllers[i].text) ?? 0) / 100;
        brackets.add({'from': from, 'to': to, 'rate': rate});
      }
      _taxService.taxBrackets = brackets;

      await _taxService.saveSettings();
      await _insuranceService.saveSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ الإعدادات بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('rules_settings'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'save_settings'.tr(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTaxBracketsCard(),
            const SizedBox(height: 16),
            _buildTaxCard(),
            const SizedBox(height: 16),
            _buildInsuranceCard(),
            const SizedBox(height: 16),
            _buildBankCard(),
            const SizedBox(height: 16),
            _buildBonusesCard(),
            const SizedBox(height: 16),
            _buildDeductionsCard(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxBracketsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vertical_split, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'tax_brackets'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'tax_brackets_description'.tr(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('From (EGP)', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('To (EGP)', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('Rate %', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 40),
                      ],
                    ),
                  ),
                  ...List.generate(_bracketFromControllers.length, (index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _bracketFromControllers[index],
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _bracketToControllers[index],
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _bracketRateControllers[index],
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                suffixText: '%',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () {
                              if (_bracketFromControllers.length > 1) {
                                setState(() {
                                  _bracketFromControllers.removeAt(index);
                                  _bracketToControllers.removeAt(index);
                                  _bracketRateControllers.removeAt(index);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _bracketFromControllers.add(TextEditingController(text: '0'));
                            _bracketToControllers.add(TextEditingController(text: '∞'));
                            _bracketRateControllers.add(TextEditingController(text: '0'));
                          });
                        },
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        label: const Text('Add Bracket'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text('tax_settings'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(_taxRateController, 'tax_rate'.tr(), '%'),
            const SizedBox(height: 12),
            _buildTextField(_overtimeRateController, 'overtime_rate'.tr(), 'x'),
            const SizedBox(height: 12),
            _buildTextField(_latePenaltyController, 'late_penalty'.tr(), 'EGP'),
          ],
        ),
      ),
    );
  }

  Widget _buildInsuranceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text('insurance_settings'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(_insuranceEmployeeController, 'insurance_employee'.tr(), '%'),
            const SizedBox(height: 12),
            _buildTextField(_insuranceCompanyController, 'insurance_company'.tr(), '%'),
            const SizedBox(height: 12),
            _buildTextField(_minInsuranceController, 'min_insurance'.tr(), 'EGP'),
            const SizedBox(height: 12),
            _buildTextField(_maxInsuranceController, 'max_insurance'.tr(), 'EGP'),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text('bank_settings'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(_bankNameController, 'bank_name'.tr(), null),
            const SizedBox(height: 12),
            _buildTextField(_bankAccountController, 'bank_account'.tr(), null),
            const SizedBox(height: 12),
            _buildTextField(_bankSwiftController, 'bank_swift'.tr(), null),
            const SizedBox(height: 12),
            _buildTextField(_bankIbanController, 'bank_iban'.tr(), null),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text('bonuses_settings'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _bonusNameController,
                    decoration: const InputDecoration(
                      hintText: 'Bonus name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _bonusAmountController,
                    decoration: const InputDecoration(
                      hintText: 'Amount',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    initialValue: _bonusType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    items: const [
                      DropdownMenuItem(value: 'fixed', child: Text('Fixed', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'percentage', child: Text('Percent', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'performance', child: Text('Perf.', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _bonusType = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 24),
                  onPressed: _addBonus,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...(_taxService.bonuses).map((bonus) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${bonus['name']}: ${bonus['amount']} ${bonus['type']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _taxService.bonuses.remove(bonus);
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeductionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.remove_circle_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text('deductions_settings'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _deductionNameController,
                    decoration: const InputDecoration(
                      hintText: 'Deduction name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _deductionAmountController,
                    decoration: const InputDecoration(
                      hintText: 'Amount',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    initialValue: _deductionType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    items: const [
                      DropdownMenuItem(value: 'fixed', child: Text('Fixed', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'percentage', child: Text('Percent', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'loan', child: Text('Loan', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _deductionType = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 24),
                  onPressed: _addDeduction,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...(_taxService.deductions).map((deduction) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${deduction['name']}: ${deduction['amount']} ${deduction['type']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _taxService.deductions.remove(deduction);
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _addBonus() {
    if (_bonusNameController.text.isNotEmpty && _bonusAmountController.text.isNotEmpty) {
      setState(() {
        _taxService.bonuses.add({
          'name': _bonusNameController.text,
          'amount': double.parse(_bonusAmountController.text),
          'type': _bonusType,
        });
        _bonusNameController.clear();
        _bonusAmountController.clear();
      });
    }
  }

  void _addDeduction() {
    if (_deductionNameController.text.isNotEmpty && _deductionAmountController.text.isNotEmpty) {
      setState(() {
        _taxService.deductions.add({
          'name': _deductionNameController.text,
          'amount': double.parse(_deductionAmountController.text),
          'type': _deductionType,
        });
        _deductionNameController.clear();
        _deductionAmountController.clear();
      });
    }
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveSettings,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text('save_settings'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String? suffix) {
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
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankSwiftController.dispose();
    _bankIbanController.dispose();
    _bonusNameController.dispose();
    _bonusAmountController.dispose();
    _deductionNameController.dispose();
    _deductionAmountController.dispose();
    for (var c in _bracketFromControllers) {
      c.dispose();
    }
    for (var c in _bracketToControllers) {
      c.dispose();
    }
    for (var c in _bracketRateControllers) {
      c.dispose();
    }
    super.dispose();
  }
}