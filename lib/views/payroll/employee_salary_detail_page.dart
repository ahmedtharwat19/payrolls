/* // lib/views/payroll/employee_salary_detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
import '../../models/employee_model.dart';

/// شاشة تفصيلية لموظف واحد بتفتح لما تعمل دبل كليك عليه في شاشة المرتبات.
/// بتسمح بتعديل الإضافي (variableSalary) والبدلات (allowances) والخصومات
/// (deductions) والمصروفات (expenses) بتاعة الموظف ده، وبتحفظهم في قاعدة
/// البيانات عن طريق EmployeeController.updateEmployee.
///
/// ملحوظة: القيم دي بتتحفظ على مستوى بيانات الموظف نفسه، فهي بتأثر على
/// شهر الراتب اللي لسه ما اتولّدش (payroll_records). لو الشهر ده كان
/// اتولّد قبل كده كـ PayrollRecord، التعديل هنا مش هيغيّر السجل القديم
/// المحفوظ، وهيحتاج توليد/تحديث سجل جديد للشهر ده.
class EmployeeSalaryDetailPage extends StatefulWidget {
  final Employee employee;

  const EmployeeSalaryDetailPage({super.key, required this.employee});

  @override
  State<EmployeeSalaryDetailPage> createState() =>
      _EmployeeSalaryDetailPageState();
}

class _EmployeeSalaryDetailPageState extends State<EmployeeSalaryDetailPage> {
  late final TextEditingController _variableController;
  late final TextEditingController _allowancesController;
  late final TextEditingController _deductionsController;
  late final TextEditingController _expensesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _variableController =
        TextEditingController(text: _formatNum(e.variableSalary));
    _allowancesController =
        TextEditingController(text: _formatNum(e.allowances));
    _deductionsController =
        TextEditingController(text: _formatNum(e.deductions));
    _expensesController = TextEditingController(text: _formatNum(e.expenses));

    for (final c in [
      _variableController,
      _allowancesController,
      _deductionsController,
      _expensesController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  String _formatNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double _parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  void dispose() {
    _variableController.dispose();
    _allowancesController.dispose();
    _deductionsController.dispose();
    _expensesController.dispose();
    super.dispose();
  }

  double get _totalEarned =>
      widget.employee.basicSalary +
      _parse(_variableController) +
      _parse(_allowancesController);

  double get _totalDeducted =>
      _parse(_deductionsController) + _parse(_expensesController);

  double get _netEstimate => _totalEarned - _totalDeducted;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final controller = context.read<EmployeeController>();

    final updated = widget.employee.copyWith(
      variableSalary: _parse(_variableController),
      allowances: _parse(_allowancesController),
      deductions: _parse(_deductionsController),
      expenses: _parse(_expensesController),
    );

    try {
      await controller.updateEmployee(updated);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('employee_updated_success'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;

    return Scaffold(
      appBar: AppBar(
        title: Text(e.getDisplayName(context)),
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
                  Text(
                    e.getDisplayName(context),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${e.department} · ${e.jobTitle}',
                      style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  _readOnlyRow('basic_salary'.tr(), e.basicSalary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('salary_info'.tr(),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _amountField(
            controller: _variableController,
            label: 'variable_salary'.tr(),
            icon: Icons.add_card,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _amountField(
            controller: _allowancesController,
            label: 'allowances'.tr(),
            icon: Icons.card_giftcard,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _amountField(
            controller: _deductionsController,
            label: 'deductions'.tr(),
            icon: Icons.remove_circle_outline,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _amountField(
            controller: _expensesController,
            label: 'expenses'.tr(),
            icon: Icons.receipt_long,
            color: Colors.red,
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('total_earned'.tr(), _totalEarned, Colors.green,
                      bold: true),
                  const Divider(),
                  _summaryRow('total_deducted'.tr(), _totalDeducted, Colors.red,
                      bold: true),
                  const Divider(),
                  _summaryRow('net_salary'.tr(), _netEstimate, Colors.black,
                      bold: true, fontSize: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            label: Text('save'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700])),
        Text(value.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        prefixText: 'EGP ',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _summaryRow(String label, double value, Color color,
      {bool bold = false, double fontSize = 15}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize)),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
 */

// lib/views/payroll/employee_salary_detail_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
import '../../models/employee_model.dart';

/// شاشة تفصيلية لموظف واحد بتفتح لما تعمل دبل كليك عليه في شاشة المرتبات.
/// بتسمح بتعديل الإضافي (variableSalary) والبدلات (allowances) والخصومات
/// (deductions) والمصروفات (expenses) بتاعة الموظف ده، وبتحفظهم في قاعدة
/// البيانات عن طريق EmployeeController.updateEmployee.
///
/// ملحوظة: القيم دي بتتحفظ على مستوى بيانات الموظف نفسه، فهي بتأثر على
/// شهر الراتب اللي لسه ما اتولّدش (payroll_records). لو الشهر ده كان
/// اتولّد قبل كده كـ PayrollRecord، التعديل هنا مش هيغيّر السجل القديم
/// المحفوظ، وهيحتاج توليد/تحديث سجل جديد للشهر ده.
class EmployeeSalaryDetailPage extends StatefulWidget {
  final Employee employee;

  const EmployeeSalaryDetailPage({super.key, required this.employee});

  @override
  State<EmployeeSalaryDetailPage> createState() =>
      _EmployeeSalaryDetailPageState();
}

class _EmployeeSalaryDetailPageState extends State<EmployeeSalaryDetailPage> {
  late final TextEditingController _variableController;
  late final TextEditingController _allowancesController;
  late final TextEditingController _deductionsController;
  late final TextEditingController _expensesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;

    // ⚠️ تصحيح دفاعي: لو الموظف عنده بيانات قديمة اتخزنت فيها نفس القيمة
    // في الأساسي والبدلات مع بعض (بسبب مشكلة استيراد قديمة)، منعرضش
    // البدلات المكررة هنا. الأفضل تشغيل "تصحيح تكرار الأساسي/البدلات"
    // من شاشة أدوات الصيانة عشان يتصحح في قاعدة البيانات نفسها.
    final displayAllowances =
        (e.basicSalary > 0 && e.basicSalary == e.allowances)
            ? 0.0
            : e.allowances;

    _variableController =
        TextEditingController(text: _formatNum(e.variableSalary));
    _allowancesController =
        TextEditingController(text: _formatNum(displayAllowances));
    _deductionsController =
        TextEditingController(text: _formatNum(e.deductions));
    _expensesController = TextEditingController(text: _formatNum(e.expenses));

    for (final c in [
      _variableController,
      _allowancesController,
      _deductionsController,
      _expensesController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  String _formatNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double _parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  void dispose() {
    _variableController.dispose();
    _allowancesController.dispose();
    _deductionsController.dispose();
    _expensesController.dispose();
    super.dispose();
  }

  double get _totalEarned =>
      widget.employee.basicSalary +
      _parse(_variableController) +
      _parse(_allowancesController);

  double get _totalDeducted =>
      _parse(_deductionsController) + _parse(_expensesController);

  double get _netEstimate => _totalEarned - _totalDeducted;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final controller = context.read<EmployeeController>();

    final updated = widget.employee.copyWith(
      variableSalary: _parse(_variableController),
      allowances: _parse(_allowancesController),
      deductions: _parse(_deductionsController),
      expenses: _parse(_expensesController),
    );

    try {
      await controller.updateEmployee(updated);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('employee_updated_success'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;

    return Scaffold(
      appBar: AppBar(
        title: Text(e.getDisplayName(context)),
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
                  Text(
                    e.getDisplayName(context),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${e.department} · ${e.jobTitle}',
                      style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  _readOnlyRow('basic_salary'.tr(), e.basicSalary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('salary_info'.tr(),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _amountField(
            controller: _variableController,
            label: 'variable_salary'.tr(),
            icon: Icons.add_card,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _amountField(
            controller: _allowancesController,
            label: 'allowances'.tr(),
            icon: Icons.card_giftcard,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _amountField(
            controller: _deductionsController,
            label: 'deductions'.tr(),
            icon: Icons.remove_circle_outline,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _amountField(
            controller: _expensesController,
            label: 'expenses'.tr(),
            icon: Icons.receipt_long,
            color: Colors.red,
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('total_earned'.tr(), _totalEarned, Colors.green,
                      bold: true),
                  const Divider(),
                  _summaryRow('total_deducted'.tr(), _totalDeducted, Colors.red,
                      bold: true),
                  const Divider(),
                  _summaryRow('net_salary'.tr(), _netEstimate, Colors.black,
                      bold: true, fontSize: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            label: Text('save'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700])),
        Text(value.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        prefixText: 'EGP ',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _summaryRow(String label, double value, Color color,
      {bool bold = false, double fontSize = 15}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize)),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
