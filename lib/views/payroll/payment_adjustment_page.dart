// lib/views/payroll/payment_adjustment_page.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../controllers/employee_controller.dart';
import '../../models/employee_model.dart';

class PaymentAdjustmentPage extends StatefulWidget {
  const PaymentAdjustmentPage({super.key});

  @override
  State<PaymentAdjustmentPage> createState() => _PaymentAdjustmentPageState();
}

class _PaymentAdjustmentPageState extends State<PaymentAdjustmentPage> {
  final _advancePaymentController = TextEditingController();
  final _bonusController = TextEditingController();
  final _deductionController = TextEditingController();
  Employee? _selectedEmployee;
  String _adjustmentType = 'advance';

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final employees = controller.employees;

    return Scaffold(
      appBar: AppBar(
        title: Text('payment_adjustments'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Employee>(
              initialValue: _selectedEmployee,
              decoration: InputDecoration(
                labelText: 'select_employee'.tr(),
                border: const OutlineInputBorder(),
              ),
              items: employees.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e.getDisplayName(context)), // ✅ عرض الاسم حسب اللغة
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedEmployee = value);
              },
            ),
            const SizedBox(height: 16),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'advance', label: Text('Advance')),
                ButtonSegment(value: 'bonus', label: Text('Bonus')),
                ButtonSegment(value: 'deduction', label: Text('Deduction')),
              ],
              selected: {_adjustmentType},
              onSelectionChanged: (Set<String> selected) {
                setState(() => _adjustmentType = selected.first);
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _adjustmentType == 'advance' 
                  ? _advancePaymentController 
                  : _adjustmentType == 'bonus' 
                      ? _bonusController 
                      : _deductionController,
              decoration: InputDecoration(
                labelText: _adjustmentType == 'advance' 
                    ? 'advance_amount'.tr() 
                    : _adjustmentType == 'bonus' 
                        ? 'bonus_amount'.tr() 
                        : 'deduction_amount'.tr(),
                border: const OutlineInputBorder(),
                prefixText: 'EGP ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            TextField(
              decoration: InputDecoration(
                labelText: 'notes'.tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _selectedEmployee == null ? null : _saveAdjustment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('save_adjustment'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAdjustment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم حفظ التعديل بنجاح')),
    );
  }
}