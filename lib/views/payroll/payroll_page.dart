// lib/views/payroll/payroll_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
import '../../services/tax_service.dart';
import '../../services/insurance_service.dart';
import '../../services/pdf_export_service.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  Future<void> _exportPdf() async {
    try {
      final controller = Provider.of<EmployeeController>(context, listen: false);
      final employees = controller.employees;
      
      // تحويل الموظفين إلى Map للـ PDF
      final data = employees.map((e) {
        final gross = e.basicSalary + e.allowances - e.deductions;
        final taxable = e.salaryType == 'net' ? gross : e.basicSalary;
        final tax = TaxService.calculateMonthlyTax(taxable);
        final insurance = InsuranceService.calculateInsurance(basicSalary: taxable);
        final net = gross - tax - insurance['employee_share']!;
        
        return {
          'name': e.name,
          'department': e.department,
          'basicSalary': e.basicSalary,
          'allowances': e.allowances,
          'deductions': e.deductions,
          'tax': tax,
          'insurance': insurance['employee_share'],
          'netSalary': net,
        };
      }).toList();
      
      await PdfExportService.exportPayrollReport(
        data, 
        title: 'payroll'.tr(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تصدير PDF بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ فشل التصدير: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final employees = controller.employees;

    return Scaffold(
      appBar: AppBar(
        title: Text('payroll'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPdf,
            tooltip: 'export_pdf'.tr(),
          ),
        ],
      ),
      body: employees.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'no_employees'.tr(),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columnSpacing: 12,
                  columns: [
                    const DataColumn(label: Text('Name')),
                    const DataColumn(label: Text('Department')),
                    const DataColumn(label: Text('Basic Salary')),
                    const DataColumn(label: Text('Allowance')),
                    const DataColumn(label: Text('Deduction')),
                    const DataColumn(label: Text('Tax')),
                    const DataColumn(label: Text('Insurance')),
                    const DataColumn(label: Text('Net Salary')),
                    const DataColumn(label: Text('Payment Method')),
                  ],
                  rows: employees.map((e) {
                    final gross = e.basicSalary + e.allowances - e.deductions;
                    final taxable = e.salaryType == 'net' ? gross : e.basicSalary;
                    final tax = TaxService.calculateMonthlyTax(taxable);
                    final insurance = InsuranceService.calculateInsurance(
                      basicSalary: taxable,
                    );
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
                      DataCell(Text(
                        e.paymentMethod == 'cash' ? 'cash'.tr() : 'bank'.tr(),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
    );
  }
}