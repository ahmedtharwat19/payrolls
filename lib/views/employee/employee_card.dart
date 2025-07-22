// lib/views/employee/employee_card.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/employee_model.dart';

class EmployeeCard extends StatelessWidget {
  final Employee employee;

  const EmployeeCard({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(employee.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${'national_id'.tr()}: ${employee.nationalId}'),
            Text('${'department'.tr()}: ${employee.department}'),
            Text('${'job_title'.tr()}: ${employee.jobTitle}'),
            Text('${'hire_date'.tr()}: ${employee.hireDate}'),
            Text('${'contract_type'.tr()}: ${employee.contractType}'),
            Text('${'employee_type'.tr()}: ${employee.employeeType}'),
            Text('${'basic_salary'.tr()}: ${employee.basicSalary.toStringAsFixed(2)}'),
            Text('${'allowances'.tr()}: ${employee.allowances.toStringAsFixed(2)}'),
            Text('${'deductions'.tr()}: ${employee.deductions.toStringAsFixed(2)}'),
            Text('${'salary_type'.tr()}: ${employee.salaryType == 'net' ? 'net'.tr() : 'gross'.tr()}'),
            Text('${'payment_method'.tr()}: ${employee.paymentMethod == 'cash' ? 'cash'.tr() : 'bank'.tr()}'),
            Text('${'insurance_code'.tr()}: ${employee.insuranceCode}'),
            Text('${'insurance_file'.tr()}: ${employee.insuranceFile}'),
            Text('${'tax_file'.tr()}: ${employee.taxFile}'),
          ],
        ),
      ),
    );
  }
}
