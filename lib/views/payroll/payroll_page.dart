// lib/views/payroll/payroll_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_payrolls/models/employee_model.dart';
import '../../controllers/employee_controller.dart';
import '../../database/app_database.dart';
import '../../models/payroll_record_model.dart';
import '../../services/tax_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/payroll_calculator.dart';
import '../../services/bulk_import_service.dart';
import 'payment_adjustment_page.dart';
import 'employee_salary_detail_page.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  late TaxService _taxService;
  final BulkImportService _importService = BulkImportService();
  List<PayrollRecord> _payrollRecords = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  final ScrollController _horizontalScrollController = ScrollController();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _taxService = context.read<TaxService>();
    _loadData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
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

  Future<void> _openEmployeeDetail(Employee e) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeSalaryDetailPage(employee: e),
      ),
    );
    if (updated == true) {
      await _loadData();
    }
  }

  // ✅ حوار اختيار الشهر/السنة لتوليد سجلات المرتبات
  Future<void> _showGeneratePayrollDialog() async {
    int localMonth = _selectedMonth;
    int localYear = _selectedYear;

    return showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('generate_payroll_records'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: localMonth,
                    decoration: InputDecoration(labelText: 'month'.tr()),
                    items: List.generate(12, (i) => i + 1).map((month) {
                      return DropdownMenuItem(
                        value: month,
                        child: Text(
                          DateFormat('MMMM', context.locale.languageCode)
                              .format(DateTime(2000, month)),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => localMonth = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: localYear,
                    decoration: InputDecoration(labelText: 'year'.tr()),
                    items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                        .map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => localYear = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () async {
                    _selectedMonth = localMonth;
                    _selectedYear = localYear;
                    Navigator.pop(dialogContext);
                    await _generatePayrollRecords();
                  },
                  child: Text('generate'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ توليد سجلات المرتبات للشهر/السنة المختارة
  Future<void> _generatePayrollRecords() async {
    setState(() => _isGenerating = true);
    try {
      final count = await _importService.generatePayrollRecordsFromEmployees(
        month: _selectedMonth,
        year: _selectedYear,
      );

      if (!mounted) return;

      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'payroll_records_created'.tr()}: $count')),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('payroll_records_already_exist'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_general'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
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

          // ✅ net: الشركة بتتحمل الضريبة والتأمين وبيتم تصعيد الراتب
          //    تلقائياً عشان الموظف يوصله المتفق عليه بالظبط.
          // ✅ gross: يتم التعامل زي المعتاد (الضريبة والتأمين بيتخصموا
          //    من الموظف نفسه).
          final result = PayrollCalculator.calculate(
            salaryType: e.salaryType,
            taxableSalary: basic,
            targetNet: totalEarned,
            taxService: _taxService,
          );
          final tax = result.tax;
          final insuranceShare = result.insuranceEmployee;
          final isNet = e.salaryType == 'net';
          final totalDeducted =
              isNet ? e.deductions : (e.deductions + tax + insuranceShare);
          final net = totalEarned - totalDeducted;

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
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.calculate),
            onPressed: _isGenerating ? null : _showGeneratePayrollDialog,
            tooltip: 'generate_payroll_records'.tr(),
          ),
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
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.green.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'double_tap_hint'.tr(),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        notificationPredicate: (notif) => notif.depth == 0,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
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

                          // ✅ net: الشركة بتتحمل الضريبة والتأمين وبيتم
                          //    تصعيد الراتب تلقائياً عشان الموظف يوصله
                          //    المتفق عليه بالظبط.
                          // ✅ gross: يتم التعامل زي المعتاد.
                          final result = PayrollCalculator.calculate(
                            salaryType: e.salaryType,
                            taxableSalary: basic,
                            targetNet: totalEarned,
                            taxService: _taxService,
                          );
                          tax = result.tax;
                          insurance = result.insuranceEmployee;
                          final isNet = e.salaryType == 'net';
                          totalDeducted =
                              isNet ? deductions : (deductions + tax + insurance);
                          net = totalEarned - totalDeducted;
                          monthYear = 'not_specified'.tr();
                        }

                        // ✅ لف كل خلية بـ GestureDetector عشان الدبل كليك
                        // يفتح شاشة تفاصيل الموظف من أي عمود في الصف
                        DataCell cell(Widget child) => DataCell(
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onDoubleTap: () => _openEmployeeDetail(e),
                                child: child,
                              ),
                            );

                        return DataRow(cells: [
                          cell(Text(e.getDisplayName(context))),
                          cell(Text(e.department)),
                          cell(Text(basic.toStringAsFixed(2))),
                          cell(Text(variable.toStringAsFixed(2))),
                          cell(Text(allowances.toStringAsFixed(2))),
                          cell(Text(totalEarned.toStringAsFixed(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green))),
                          cell(Text(deductions.toStringAsFixed(2))),
                          cell(Text(tax.toStringAsFixed(2))),
                          cell(Text(insurance.toStringAsFixed(2))),
                          cell(Text(totalDeducted.toStringAsFixed(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red))),
                          cell(Text(net.toStringAsFixed(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          cell(Text(monthYear)),
                          cell(Text(
                            e.paymentMethod == 'cash'
                                ? 'cash'.tr()
                                : 'bank'.tr(),
                          )),
                        ]);
                      }).toList(),
                          ),
                        ),
                      ),
                    ),
                    ),
                  ],
                ),
    );
  }
}