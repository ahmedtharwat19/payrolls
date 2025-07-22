// lib/views/payroll/payroll_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
//import '../../models/employee_model.dart';
import '../../services/tax_service.dart';
import '../../services/insurance_service.dart';

class PayrollPage extends StatelessWidget {
  const PayrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final employees = controller.employees;

    return Scaffold(
      appBar: AppBar(title: Text('payroll'.tr())),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text('name'.tr())),
            DataColumn(label: Text('department'.tr())),
            DataColumn(label: Text('basic_salary'.tr())),
            DataColumn(label: Text('allowances'.tr())),
            DataColumn(label: Text('deductions'.tr())),
            DataColumn(label: Text('tax'.tr())),
            DataColumn(label: Text('insurance_employee'.tr())),
            DataColumn(label: Text('net_salary'.tr())),
            DataColumn(label: Text('payment_method'.tr())),
          ],
          rows: employees.map((e) {
            final gross = e.basicSalary + e.allowances - e.deductions;
            final taxable = e.salaryType == 'net' ? gross : e.basicSalary;
            final tax = TaxService.calculateMonthlyTax(taxable);
            final insurance = InsuranceService.calculateInsurance(basicSalary: taxable);
            final net = gross - tax - insurance['employee_share']!;

            return DataRow(cells: [
              DataCell(Text(e.name)),
              DataCell(Text(e.department)),
              DataCell(Text(e.basicSalary.toStringAsFixed(2))),
              DataCell(Text(e.allowances.toStringAsFixed(2))),
              DataCell(Text(e.deductions.toStringAsFixed(2))),
              DataCell(Text(tax.toStringAsFixed(2))),
              DataCell(Text(insurance['employee_share']!.toStringAsFixed(2))),
              DataCell(Text(net.toStringAsFixed(2))),
              DataCell(Text(e.paymentMethod == 'cash' ? 'cash'.tr() : 'bank'.tr())),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}