// lib/views/payroll/payroll_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_payrolls/models/employee_model.dart';
import '../../controllers/employee_controller.dart';
import '../../database/app_database.dart';
import '../../models/payroll_record_model.dart';
import '../../services/tax_service.dart';
import '../../services/insurance_service.dart';
import '../../services/pdf_export_service.dart';
import 'payment_adjustment_page.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  late TaxService _taxService;
  List<PayrollRecord> _payrollRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _taxService = context.read<TaxService>();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final controller = Provider.of<EmployeeController>(context, listen: false);
    await controller.refresh();

    try {
      final db = await AppDatabase.instance.database;
      final records = await db.query(
        'payroll_records',
        orderBy: 'year DESC, month DESC',
      );
      _payrollRecords =
          records.map((map) => PayrollRecord.fromMap(map)).toList();
    } catch (e) {
      _payrollRecords = [];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  PayrollRecord? _getLatestPayroll(String employeeId) {
    try {
      final filtered = _payrollRecords
          .where((record) => record.employeeId == employeeId)
          .toList();
      if (filtered.isEmpty) return null;
      filtered.sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });
      return filtered.first;
    } catch (_) {
      return null;
    }
  }

  /// حساب مجموع الراتب مع تصحيح المضاعفة
  /// إذا كان الأساسي == البدلات والبدلات > 0، نعتبر البدلات هي الراتب الفعلي ولا نضيفها مرتين
  double _getTotalSalary(Employee e) {
    double basic = e.basicSalary;
    double allowances = e.allowances;
    double variable = e.variableSalary;

    // ✅ تصحيح المضاعفة: إذا كان الأساسي يساوي البدلات، نعتبر البدلات 0
    // لأن الأساسي هو الراتب الفعلي في هذه الحالة
    if (basic > 0 && basic == allowances) {
      allowances = 0;
    }

    return basic + variable + allowances;
  }

  /// تحديد ما إذا كان الموظف لديه راتب غير صفري
  bool _hasValidSalary(Employee e) {
    return _getTotalSalary(e) > 0;
  }

  Future<void> _exportPdf() async {
    await _loadData();
    if (!mounted) return;

    final controller = Provider.of<EmployeeController>(context, listen: false);
    final allEmployees = controller.employees;

    final employees = allEmployees.where(_hasValidSalary).toList();

    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_valid_salary_employees'.tr())),
      );
      return;
    }

    try {
      final data = employees.map((e) {
        final payroll = _getLatestPayroll(e.id);
        if (payroll != null) {
          return {
            'name': e.nameAr.isNotEmpty ? e.nameAr : e.nameEn,
            'department': e.department,
            'basicSalary': payroll.basicSalary,
            'variableSalary': payroll.variableSalary,
            'allowances': payroll.allowances,
            'totalEarned': payroll.totalEarned,
            'deductions': payroll.deductions,
            'tax': payroll.taxAmount,
            'insurance': payroll.insuranceAmount,
            'totalDeducted': payroll.totalDeducted,
            'netSalary': payroll.netSalary,
          };
        } else {
          // حساب يدوي مع تصحيح المضاعفة
          double basic = e.basicSalary;
          double allowances = e.allowances;
          double variable = e.variableSalary;

          // ✅ تصحيح المضاعفة
          if (basic > 0 && basic == allowances) {
            allowances = 0;
          }

          final totalEarned = basic + variable + allowances;
          final gross = totalEarned - e.deductions;
          final taxable = e.salaryType == 'net' ? gross : basic;
          final tax = _taxService.calculateMonthlyTax(taxable);
          final insurance =
              InsuranceService.calculateInsurance(basicSalary: taxable);
          final insuranceShare = insurance['employee_share']!;
          final totalDeducted = e.deductions + tax + insuranceShare;
          final net = gross - tax - insuranceShare;

          return {
            'name': e.nameAr.isNotEmpty ? e.nameAr : e.nameEn,
            'department': e.department,
            'basicSalary': basic,
            'variableSalary': variable,
            'allowances': allowances,
            'totalEarned': totalEarned,
            'deductions': e.deductions,
            'tax': tax,
            'insurance': insuranceShare,
            'totalDeducted': totalDeducted,
            'netSalary': net,
          };
        }
      }).toList();

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('no_data_to_export'.tr())),
        );
        return;
      }

      final filePath = await PdfExportService.exportPayrollReport(
        data,
        title: 'payroll'.tr(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'pdf_exported_success'.tr()}\n$filePath'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'pdf_export_failed'.tr()}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final allEmployees = controller.employees;
    final employees = allEmployees.where(_hasValidSalary).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('payroll'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PaymentAdjustmentPage()),
              );
            },
            tooltip: 'payment_adjustments'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPdf,
            tooltip: 'export_pdf'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'refresh'.tr(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : employees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        allEmployees.isEmpty
                            ? 'no_employees'.tr()
                            : 'no_valid_salary_employees'.tr(),
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
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
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Department')),
                        DataColumn(label: Text('Basic Salary')),
                        DataColumn(label: Text('Variable')),
                        DataColumn(label: Text('Allowance')),
                        DataColumn(
                            label: Text('Total Earned',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Deduction')),
                        DataColumn(label: Text('Tax')),
                        DataColumn(label: Text('Insurance')),
                        DataColumn(
                            label: Text('Total Deducted',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Net Salary',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Month/Year')),
                        DataColumn(label: Text('Payment Method')),
                      ],
                      rows: employees.map((e) {
                        final payroll = _getLatestPayroll(e.id);
                        String monthYear = '';
                        double basic = e.basicSalary;
                        double variable = e.variableSalary;
                        double allowances = e.allowances;
                        double deductions = e.deductions;
                        double tax = 0;
                        double insurance = 0;
                        double net = 0;
                        double totalEarned = 0;
                        double totalDeducted = 0;

                        if (payroll != null) {
                          monthYear = '${payroll.month}/${payroll.year}';
                          basic = payroll.basicSalary;
                          variable = payroll.variableSalary;
                          allowances = payroll.allowances;
                          deductions = payroll.deductions;
                          tax = payroll.taxAmount;
                          insurance = payroll.insuranceAmount;
                          net = payroll.netSalary;
                          totalEarned = payroll.totalEarned;
                          totalDeducted = payroll.totalDeducted;
                        } else {
                          // ✅ تصحيح المضاعفة في العرض
                          if (basic > 0 && basic == allowances) {
                            allowances = 0;
                          }
                          totalEarned = basic + variable + allowances;
                          final gross = totalEarned - deductions;
                          final taxable = e.salaryType == 'net' ? gross : basic;
                          tax = _taxService.calculateMonthlyTax(taxable);
                          final ins = InsuranceService.calculateInsurance(
                              basicSalary: taxable);
                          insurance = ins['employee_share']!;
                          totalDeducted = deductions + tax + insurance;
                          net = gross - tax - insurance;
                          monthYear = 'not_specified'.tr();
                        }

                        return DataRow(cells: [
                          DataCell(Text(e.getDisplayName(context))),
                          DataCell(Text(e.department)),
                          DataCell(Text(basic.toStringAsFixed(2))),
                          DataCell(Text(variable.toStringAsFixed(2))),
                          DataCell(Text(allowances.toStringAsFixed(2))),
                          DataCell(Text(totalEarned.toStringAsFixed(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green))),
                          DataCell(Text(deductions.toStringAsFixed(2))),
                          DataCell(Text(tax.toStringAsFixed(2))),
                          DataCell(Text(insurance.toStringAsFixed(2))),
                          DataCell(Text(totalDeducted.toStringAsFixed(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red))),
                          DataCell(Text(net.toStringAsFixed(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          DataCell(Text(monthYear)),
                          DataCell(Text(
                            e.paymentMethod == 'cash'
                                ? 'cash'.tr()
                                : 'bank'.tr(),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
    );
  }
}
