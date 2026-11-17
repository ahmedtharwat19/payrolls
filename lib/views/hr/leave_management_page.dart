// lib/views/hr/leave_management_page.dart

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
import '../../models/employee_model.dart';
import '../../services/leave_service.dart';

class LeaveManagementPage extends StatefulWidget {
  const LeaveManagementPage({super.key});

  @override
  State<LeaveManagementPage> createState() => _LeaveManagementPageState();
}

class _LeaveManagementPageState extends State<LeaveManagementPage> {
  final _service = LeaveService();
  Employee? _selectedEmployee;
  String _leaveType = 'annual';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  Future<void> _submitLeave() async {
    if (_selectedEmployee == null) return;
    await _service.requestLeave(
      employeeId: _selectedEmployee!.id,
      leaveType: _leaveType,
      startDate: _startDate,
      endDate: _endDate,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الإجازة بنجاح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final employees = controller.employees.where((e) => e.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('leave_management'.tr()),
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
            initialValue: _leaveType,
            decoration: InputDecoration(
                labelText: 'leave_type'.tr(),
                border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                  value: 'annual', child: Text('annual_leave'.tr())),
              DropdownMenuItem(value: 'sick', child: Text('sick_leave'.tr())),
              DropdownMenuItem(
                  value: 'unpaid', child: Text('unpaid_leave'.tr())),
            ],
            onChanged: (val) => setState(() => _leaveType = val!),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text('start_date'.tr()),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
            onTap: () async {
              final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030));
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text('end_date'.tr()),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
            onTap: () async {
              final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030));
              if (picked != null) setState(() => _endDate = picked);
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _submitLeave,
            icon: const Icon(Icons.save),
            label: Text('submit_request'.tr()),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}
