// lib/views/hr/penalties_page.dart

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
import '../../models/employee_model.dart';
import '../../services/penalty_service.dart';

class PenaltiesPage extends StatefulWidget {
  const PenaltiesPage({super.key});

  @override
  State<PenaltiesPage> createState() => _PenaltiesPageState();
}

class _PenaltiesPageState extends State<PenaltiesPage> {
  final _service = PenaltyService();
  Employee? _selectedEmployee;
  String _penaltyType = 'financial';
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  Future<void> _addPenalty() async {
    if (_selectedEmployee == null || _amountCtrl.text.isEmpty) return;
    await _service.addPenalty(
      employeeId: _selectedEmployee!.id,
      type: _penaltyType,
      amount: double.tryParse(_amountCtrl.text) ?? 0.0,
      reason: _reasonCtrl.text,
      appliedMonth: DateTime.now().month,
      appliedYear: DateTime.now().year,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تسجيل الجزاء بنجاح')));
      _amountCtrl.clear();
      _reasonCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final employees = controller.employees.where((e) => e.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('penalties'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Employee>(
            decoration: InputDecoration(
                labelText: 'employee'.tr(), border: const OutlineInputBorder()),
            items: employees
                .map((e) => DropdownMenuItem(
                    value: e, child: Text(e.getDisplayName(context))))
                .toList(),
            onChanged: (val) => setState(() => _selectedEmployee = val),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _penaltyType,
            decoration: InputDecoration(
                labelText: 'penalty_type'.tr(),
                border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                  value: 'financial', child: Text('financial_penalty'.tr())),
              DropdownMenuItem(value: 'warning', child: Text('warning'.tr())),
            ],
            onChanged: (val) => setState(() => _penaltyType = val!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'amount'.tr(),
                border: const OutlineInputBorder(),
                prefixText: 'EGP '),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            decoration: InputDecoration(
                labelText: 'reason'.tr(), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addPenalty,
            icon: const Icon(Icons.warning),
            label: Text('add_penalty'.tr()),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}
