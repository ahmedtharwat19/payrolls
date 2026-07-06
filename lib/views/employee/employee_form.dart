// lib/views/employee/employee_form.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/employee_model.dart';
import '../../controllers/employee_controller.dart';
import '../shared/section_header.dart';
import 'package:uuid/uuid.dart';

class EmployeeForm extends StatefulWidget {
  const EmployeeForm({super.key});

  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  final _data = <String, dynamic>{};

  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankSwiftController = TextEditingController();
  final _bankIbanController = TextEditingController();

  @override
  void dispose() {
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankSwiftController.dispose();
    _bankIbanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('add_employee'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SectionHeader(title: 'basic_info'),
              const SizedBox(height: 8),

              TextFormField(
                decoration: InputDecoration(
                  labelText: 'name'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'name_required'.tr() : null,
                onSaved: (v) => _data['name'] = v,
              ),
              const SizedBox(height: 12),

              TextFormField(
                decoration: InputDecoration(
                  labelText: 'national_id'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.badge),
                ),
                onSaved: (v) => _data['nationalId'] = v,
              ),
              const SizedBox(height: 12),

              TextFormField(
                decoration: InputDecoration(
                  labelText: 'department'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.business),
                ),
                onSaved: (v) => _data['department'] = v,
              ),
              const SizedBox(height: 12),

              TextFormField(
                decoration: InputDecoration(
                  labelText: 'job_title'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.work),
                ),
                onSaved: (v) => _data['jobTitle'] = v,
              ),
              const SizedBox(height: 12),

              TextFormField(
                decoration: InputDecoration(
                  labelText: 'hire_date'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        _data['hireDate'] = date.toIso8601String();
                      }
                    },
                  ),
                ),
                onSaved: (v) => _data['hireDate'] = v ?? DateTime.now().toIso8601String(),
              ),
              const SizedBox(height: 16),

              const SectionHeader(title: 'salary_info'),
              const SizedBox(height: 8),

              TextFormField(
                decoration: InputDecoration(
                  labelText: 'basic_salary'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  prefixText: 'EGP ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'salary_required'.tr();
                  if (double.tryParse(v!) == null) return 'invalid_number'.tr();
                  return null;
                },
                onSaved: (v) => _data['basicSalary'] = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 12),

              TextFormField(
                decoration: InputDecoration(
                  labelText: 'allowances'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.add_circle_outline),
                  prefixText: 'EGP ',
                ),
                keyboardType: TextInputType.number,
                onSaved: (v) => _data['allowances'] = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 12),

              TextFormField(
                decoration: InputDecoration(
                  labelText: 'deductions'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.remove_circle_outline),
                  prefixText: 'EGP ',
                ),
                keyboardType: TextInputType.number,
                onSaved: (v) => _data['deductions'] = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'salary_type'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.monetization_on),
                ),
                initialValue: 'net',
                onChanged: (v) => _data['salaryType'] = v,
                items: ['net', 'gross'].map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e == 'net' ? 'net'.tr() : 'gross'.tr()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'payment_method'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.payment),
                ),
                initialValue: 'cash',
                onChanged: (v) {
                  _data['paymentMethod'] = v;
                  setState(() {});
                },
                items: ['cash', 'bank'].map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e == 'cash' ? 'cash'.tr() : 'bank'.tr()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              if (_data['paymentMethod'] == 'bank') ...[
                const SectionHeader(title: 'bank_details'),
                const SizedBox(height: 8),

                TextField(
                  controller: _bankNameController,
                  decoration: InputDecoration(
                    labelText: 'bank_name'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.account_balance),
                  ),
                  onChanged: (v) => _data['bankName'] = v,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _bankAccountController,
                  decoration: InputDecoration(
                    labelText: 'bank_account'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                  ),
                  onChanged: (v) => _data['bankAccount'] = v,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _bankSwiftController,
                  decoration: InputDecoration(
                    labelText: 'bank_swift'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.code),
                  ),
                  onChanged: (v) => _data['bankSwift'] = v,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _bankIbanController,
                  decoration: InputDecoration(
                    labelText: 'bank_iban'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  onChanged: (v) => _data['bankIban'] = v,
                ),
                const SizedBox(height: 16),
              ],

              const SectionHeader(title: 'additional_info'),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'contract_type'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.description),
                ),
                initialValue: 'permanent',
                onChanged: (v) => _data['contractType'] = v,
                items: ['permanent', 'temporary', 'contract'].map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e.tr()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'employee_type'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.people),
                ),
                initialValue: 'full-time',
                onChanged: (v) => _data['employeeType'] = v,
                items: ['full-time', 'part-time', 'intern'].map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e.tr()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              TextFormField(
                decoration: InputDecoration(
                  labelText: 'insurance_code'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.health_and_safety),
                ),
                onSaved: (v) => _data['insuranceCode'] = v ?? '',
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          _saveEmployee(controller);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('save'.tr()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _saveEmployee(EmployeeController controller) {
    final emp = Employee(
      id: const Uuid().v4(),
      name: _data['name'] ?? '',
      department: _data['department'] ?? '',
      jobTitle: _data['jobTitle'] ?? '',
      nationalId: _data['nationalId'] ?? '',
      hireDate: _data['hireDate'] ?? DateTime.now().toIso8601String(),
      contractType: _data['contractType'] ?? 'permanent',
      employeeType: _data['employeeType'] ?? 'full-time',
      insuranceCode: _data['insuranceCode'] ?? '',
      insuranceFile: '',
      taxFile: '',
      basicSalary: _data['basicSalary'] ?? 0.0,
      allowances: _data['allowances'] ?? 0.0,
      deductions: _data['deductions'] ?? 0.0,
      salaryType: _data['salaryType'] ?? 'net',
      paymentMethod: _data['paymentMethod'] ?? 'cash',
      bankName: _data['bankName'] ?? '',
      bankAccount: _data['bankAccount'] ?? '',
      bankSwift: _data['bankSwift'] ?? '',
      bankIban: _data['bankIban'] ?? '',
      isActive: true,
    );

    controller.addEmployee(emp);
    Navigator.pop(context);
  }
}