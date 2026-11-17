// lib/views/employees/eos_calculator_page.dart

import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../services/eos_service.dart';

class EOSCalculatorPage extends StatefulWidget {
  const EOSCalculatorPage({super.key});

  @override
  State<EOSCalculatorPage> createState() => _EOSCalculatorPageState();
}

class _EOSCalculatorPageState extends State<EOSCalculatorPage> {
  final _salaryCtrl = TextEditingController(text: '10000');
  final _leaveBalanceCtrl = TextEditingController(text: '0');
  DateTime _hireDate = DateTime(2020, 1, 1);
  DateTime _endDate = DateTime.now();
  bool _isResignation = false;
  final _service = EOSService();

  double? _settlementAmount;
  double? _leaveAmount;
  double? _totalAmount;
  double? _years;

  void _calculate() {
    final salary = double.tryParse(_salaryCtrl.text) ?? 0;
    final leaveDays = int.tryParse(_leaveBalanceCtrl.text) ?? 0;

    if (salary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال راتب أساسي صحيح')),
      );
      return;
    }

    final years = _endDate.difference(_hireDate).inDays / 365.25;

    final settlement = _service.calculateSettlementAmount(
      lastBasicSalary: salary,
      yearsOfService: years,
      isResignation: _isResignation,
    );

    final leaveAmount = _service.calculateLeaveBalanceAmount(
      remainingLeaveDays: leaveDays,
      lastBasicSalary: salary,
    );

    setState(() {
      _years = years;
      _settlementAmount = settlement;
      _leaveAmount = leaveAmount;
      _totalAmount = settlement + leaveAmount;
    });
  }

  Future<void> _pickDate({required bool isHireDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isHireDate ? _hireDate : _endDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isHireDate) {
          _hireDate = picked;
        } else {
          _endDate = picked;
        }
        _settlementAmount = null;
        _leaveAmount = null;
        _totalAmount = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة نهاية الخدمة'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'بيانات الحساب',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _salaryCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'آخر راتب أساسي',
                      prefixText: 'EGP ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _leaveBalanceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد أيام الإجازة المتبقية',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.beach_access),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today,
                              color: Colors.blue),
                          title: const Text('تاريخ التعيين'),
                          subtitle: Text(dateFormat.format(_hireDate)),
                          onTap: () => _pickDate(isHireDate: true),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event, color: Colors.red),
                          title: const Text('تاريخ نهاية الخدمة'),
                          subtitle: Text(dateFormat.format(_endDate)),
                          onTap: () => _pickDate(isHireDate: false),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('استقالة (وليست إنهاء عقد)'),
                    subtitle:
                        const Text('يؤثر على حساب المكافأة وفقاً للقانون'),
                    value: _isResignation,
                    onChanged: (v) => setState(() => _isResignation = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _calculate,
                      icon: const Icon(Icons.calculate),
                      label: const Text('احسب المكافأة'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_settlementAmount != null) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نتيجة الحساب',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    _resultRow(
                        'سنوات الخدمة', '${_years!.toStringAsFixed(2)} سنة'),
                    _resultRow('مكافأة نهاية الخدمة',
                        '${_settlementAmount!.toStringAsFixed(2)} EGP'),
                    _resultRow('قيمة رصيد الإجازات',
                        '${_leaveAmount!.toStringAsFixed(2)} EGP'),
                    const Divider(),
                    _resultRow(
                      'الإجمالي المستحق',
                      '${_totalAmount!.toStringAsFixed(2)} EGP',
                      isBold: true,
                      color: Colors.green.shade800,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isBold ? 16 : 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 18 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
