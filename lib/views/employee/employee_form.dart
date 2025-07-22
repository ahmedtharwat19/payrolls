// employee_form.dart placeholder// lib/views/employee/employee_form.dart

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

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text('add_employee'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SectionHeader(title: 'basic_info'),
              TextFormField(
                decoration: InputDecoration(labelText: 'name'.tr()),
                onSaved: (v) => _data['name'] = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'national_id'.tr()),
                onSaved: (v) => _data['nationalId'] = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'department'.tr()),
                onSaved: (v) => _data['department'] = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'job_title'.tr()),
                onSaved: (v) => _data['jobTitle'] = v,
              ),
              const SizedBox(height: 10),
              const SectionHeader(title: 'salary_info'),
              TextFormField(
                decoration: InputDecoration(labelText: 'basic_salary'.tr()),
                keyboardType: TextInputType.number,
                onSaved: (v) => _data['basicSalary'] = double.tryParse(v ?? '0') ?? 0,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'allowances'.tr()),
                keyboardType: TextInputType.number,
                onSaved: (v) => _data['allowances'] = double.tryParse(v ?? '0') ?? 0,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'deductions'.tr()),
                keyboardType: TextInputType.number,
                onSaved: (v) => _data['deductions'] = double.tryParse(v ?? '0') ?? 0,
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'salary_type'.tr()),
                value: 'net',
                onChanged: (v) => _data['salaryType'] = v,
                items: ['net', 'gross'].map((e) {
                  return DropdownMenuItem(value: e, child: Text(e.tr()));
                }).toList(),
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'payment_method'.tr()),
                value: 'cash',
                onChanged: (v) => _data['paymentMethod'] = v,
                items: ['cash', 'bank'].map((e) {
                  return DropdownMenuItem(value: e, child: Text(e.tr()));
                }).toList(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _formKey.currentState!.save();
                  final emp = Employee(
                    id: const Uuid().v4(),
                    name: _data['name'],
                    nationalId: _data['nationalId'],
                    department: _data['department'],
                    jobTitle: _data['jobTitle'],
                    contractType: 'permanent',
                    employeeType: 'full-time',
                    hireDate: DateTime.now().toIso8601String(),
                    insuranceCode: '',
                    insuranceFile: '',
                    taxFile: '',
                    basicSalary: _data['basicSalary'],
                    allowances: _data['allowances'],
                    deductions: _data['deductions'],
                    salaryType: _data['salaryType'] ?? 'net',
                    paymentMethod: _data['paymentMethod'] ?? 'cash',
                  );
                  controller.addEmployee(emp);
                  Navigator.pop(context);
                },
                child: Text('save'.tr()),
              )
            ],
          ),
        ),
      ),
    );
  }
}
