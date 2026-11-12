// lib/views/payroll/payroll_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';
import 'package:puresip_payrolls/models/employee_model.dart';
import '../../controllers/employee_controller.dart';
import '../../database/app_database.dart';
import '../../models/payroll_record_model.dart';
import '../../services/pdf_export_service.dart';
import '../../services/bulk_import_service.dart';
import 'payment_adjustment_page.dart';
import 'employee_salary_detail_page.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/permission.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  final BulkImportService _importService = BulkImportService();
  List<PayrollRecord> _payrollRecords = [];
  final Map<String, double> _paidAmounts = {};
  bool _isLoading = true;
  bool _isGenerating = false;
  final ScrollController _horizontalScrollController = ScrollController();

  late int _viewMonth = DateTime.now().month;
  late int _viewYear = DateTime.now().year;
  String _filterPaymentMethod = 'all';
  String _filterDepartment = 'all';

  @override
  void initState() {
    super.initState();
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
        where: 'month = ? AND year = ?',
        whereArgs: [_viewMonth, _viewYear],
      );
      _payrollRecords =
          records.map((map) => PayrollRecord.fromMap(map)).toList();

      final payments = await db.query('salary_payments');
      _paidAmounts.clear();
      for (var p in payments) {
        final recordId = p['payrollRecordId'] as String;
        final amount = (p['amount'] as num).toDouble();
        _paidAmounts[recordId] = (_paidAmounts[recordId] ?? 0) + amount;
      }
    } catch (e) {
      _payrollRecords = [];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  PayrollRecord? _getPayrollForMonth(String employeeId) {
    try {
      return _payrollRecords.firstWhere((r) => r.employeeId == employeeId);
    } catch (_) {
      return null;
    }
  }

  double _getTotalSalary(Employee e) =>
      e.basicSalary + e.variableSalary + e.allowances;
  bool _hasValidSalary(Employee e) => _getTotalSalary(e) > 0;

  Future<void> _openEmployeeDetail(Employee e) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EmployeeSalaryDetailPage(employee: e)),
    );
    if (updated == true) {
      await _loadData();
    }
  }

  // ✅ 1. الدفع الفردي (تم تعديل النسب لتحسب من الإجمالي)
  Future<void> _showPaymentDialog(Employee e, PayrollRecord? payroll) async {
    if (payroll == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('must_generate_payroll_first'.tr())),
      );
      return;
    }

    final totalPaid = _paidAmounts[payroll.id] ?? 0.0;
    final remaining = payroll.netSalary - totalPaid;

    if (remaining <= 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('salary_already_fully_paid'.tr())),
      );
      return;
    }

    final amountCtrl =
        TextEditingController(text: remaining.toStringAsFixed(2));
    final notesCtrl = TextEditingController();

    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
              'register_payment_for'.tr(args: [e.getDisplayName(context)])),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${'net_due'.tr()}: ${payroll.netSalary.toStringAsFixed(2)}'),
                Text(
                  '${'previously_paid'.tr()}: ${totalPaid.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.orange),
                ),
                Text(
                  '${'remaining'.tr()}: ${remaining.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ActionChip(
                      label: const Text('50%'),
                      onPressed: () {
                        final targetAmt = payroll.netSalary * 0.5;
                        final amtToPay = targetAmt - totalPaid;
                        amountCtrl.text =
                            (amtToPay > 0 ? amtToPay : 0).toStringAsFixed(2);
                      },
                    ),
                    ActionChip(
                      label: const Text('30%'),
                      onPressed: () {
                        final targetAmt = payroll.netSalary * 0.3;
                        final amtToPay = targetAmt - totalPaid;
                        amountCtrl.text =
                            (amtToPay > 0 ? amtToPay : 0).toStringAsFixed(2);
                      },
                    ),
                    ActionChip(
                      label: Text('remaining_full'.tr()),
                      onPressed: () =>
                          amountCtrl.text = remaining.toStringAsFixed(2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'paid_amount'.tr(),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                      labelText: 'notes_optional'.tr(),
                      border: const OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amount <= 0 || amount > remaining + 0.01) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('invalid_amount'.tr())),
                  );
                  return;
                }

                final db = await AppDatabase.instance.database;
                await db.insert('salary_payments', {
                  'id': const Uuid().v4(),
                  'payrollRecordId': payroll.id,
                  'amount': amount,
                  'cashAmount': e.paymentMethod == 'cash' ? amount : 0.0,
                  'bankAmount': e.paymentMethod == 'bank' ? amount : 0.0,
                  'paymentDate': DateTime.now().toIso8601String(),
                  'notes': notesCtrl.text.trim(),
                });

                if (!dialogContext.mounted || !mounted) return;
                Navigator.pop(dialogContext);
                await _loadData();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('payment_saved_success'.tr())),
                );
              },
              child: Text('save_payment'.tr()),
            ),
          ],
        );
      },
    );
  }

  // ✅ 2. الدفع الجماعي
  Future<void> _showBulkPaymentDialog() async {
    final controller = Provider.of<EmployeeController>(context, listen: false);
    final allEmployees = controller.employees;

    final departments = allEmployees.map((e) => e.department).toSet().toList();

    String selectedTarget = 'all';
    String selectedType = '100';
    final customAmountCtrl = TextEditingController();
    final customPercentCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    return showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('bulk_payment'.tr()),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('target_group'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedTarget,
                      items: [
                        DropdownMenuItem(
                            value: 'all', child: Text('all_employees'.tr())),
                        ...departments.map(
                            (d) => DropdownMenuItem(value: d, child: Text(d))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedTarget = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('payment_ratio'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedType,
                      items: [
                        DropdownMenuItem(
                            value: '100',
                            child: Text('pay_remaining_100'.tr())),
                        DropdownMenuItem(
                            value: '50', child: Text('pay_50_remaining'.tr())),
                        DropdownMenuItem(
                            value: '30', child: Text('pay_30_remaining'.tr())),
                        DropdownMenuItem(
                            value: 'custom_percent',
                            child: Text('custom_percent_remaining'.tr())),
                        DropdownMenuItem(
                            value: 'custom',
                            child: Text('custom_amount_per_emp'.tr())),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedType = val);
                        }
                      },
                    ),
                    if (selectedType == 'custom_percent') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customPercentCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'custom_percent_hint'.tr(),
                          border: const OutlineInputBorder(),
                          suffixText: '%',
                        ),
                      ),
                    ],
                    if (selectedType == 'custom') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customAmountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'custom_amount_hint'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'notes_optional'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _processBulkPayment(
                      target: selectedTarget,
                      type: selectedType,
                      customAmount:
                          double.tryParse(customAmountCtrl.text) ?? 0.0,
                      customPercent:
                          double.tryParse(customPercentCtrl.text) ?? 0.0,
                      notes: notesCtrl.text.trim(),
                    );
                  },
                  child: Text('execute_payment'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ 3. معالجة الدفع الجماعي (تم تعديل منطق النسب)
  Future<void> _processBulkPayment({
    required String target,
    required String type,
    required double customAmount,
    required double customPercent,
    required String notes,
  }) async {
    if (type == 'custom_percent' && customPercent <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('❌ يرجى إدخال نسبة مئوية صحيحة أكبر من صفر')),
      );
      return;
    }
    if (type == 'custom' && customAmount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ يرجى إدخال مبلغ صحيح أكبر من صفر')),
      );
      return;
    }

    final controller = Provider.of<EmployeeController>(context, listen: false);
    final allEmployees = controller.employees;

    final targetEmployees = allEmployees.where((e) {
      if (!_hasValidSalary(e)) return false;
      if (target != 'all' && e.department != target) return false;
      return true;
    }).toList();

    if (targetEmployees.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_employees_in_category'.tr())),
      );
      return;
    }

    final db = await AppDatabase.instance.database;
    int successCount = 0;
    int skippedNoPayroll = 0;
    int skippedFullyPaid = 0;

    for (var e in targetEmployees) {
      final payroll = _getPayrollForMonth(e.id);
      if (payroll == null) {
        skippedNoPayroll++;
        continue;
      }

      final totalPaid = _paidAmounts[payroll.id] ?? 0.0;
      final remaining = payroll.netSalary - totalPaid;

      if (remaining <= 0.01) {
        skippedFullyPaid++;
        continue;
      }

      double amountToPay = 0.0;
      if (type == '100') {
        amountToPay = remaining;
      } else if (type == '50') {
        final targetAmt = payroll.netSalary * 0.5;
        amountToPay = targetAmt - totalPaid;
      } else if (type == '30') {
        final targetAmt = payroll.netSalary * 0.3;
        amountToPay = targetAmt - totalPaid;
      } else if (type == 'custom_percent') {
        final targetAmt = payroll.netSalary * (customPercent / 100);
        amountToPay = targetAmt - totalPaid;
      } else if (type == 'custom') {
        amountToPay = customAmount;
      }

      if (amountToPay > remaining) amountToPay = remaining;
      if (amountToPay <= 0) continue;

      await db.insert('salary_payments', {
        'id': const Uuid().v4(),
        'payrollRecordId': payroll.id,
        'amount': amountToPay,
        'cashAmount': e.paymentMethod == 'cash' ? amountToPay : 0.0,
        'bankAmount': e.paymentMethod == 'bank' ? amountToPay : 0.0,
        'paymentDate': DateTime.now().toIso8601String(),
        'notes': notes,
      });
      successCount++;
    }

    await _loadData();

    if (mounted) {
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم إجراء الدفعات بنجاح لـ $successCount موظف'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String errorMsg = '⚠️ لم يتم صرف أي مبالغ. ';
        if (skippedNoPayroll > 0) {
          errorMsg += '(المرتبات غير مولدة لهذا الشهر). ';
        }
        if (skippedFullyPaid > 0) {
          errorMsg += '(تم صرف رواتب هؤلاء الموظفين بالكامل مسبقاً). ';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg.trim()),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showGeneratePayrollDialog() async {
    int localMonth = _viewMonth;
    int localYear = _viewYear;

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
                          value: year, child: Text(year.toString()));
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
                    setState(() {
                      _viewMonth = localMonth;
                      _viewYear = localYear;
                    });
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

  Future<void> _generatePayrollRecords() async {
    setState(() => _isGenerating = true);
    try {
      final count = await _importService.generatePayrollRecordsFromEmployees(
        month: _viewMonth,
        year: _viewYear,
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
    if (!mounted) return;
    final isAr = context.locale.languageCode == 'ar';

    final controller = Provider.of<EmployeeController>(context, listen: false);
    final allEmployees = controller.employees;

    final employees = allEmployees.where((e) {
      final hasSalary = _hasValidSalary(e);
      final matchesPayment = _filterPaymentMethod == 'all' ||
          e.paymentMethod == _filterPaymentMethod;
      final matchesDept =
          _filterDepartment == 'all' || e.department == _filterDepartment;
      return hasSalary && matchesPayment && matchesDept;
    }).toList();

    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_valid_salary_employees'.tr())),
      );
      return;
    }

    try {
      final isBank = _filterPaymentMethod == 'bank';
      final monthName = DateFormat('MMMM', context.locale.languageCode)
          .format(DateTime(_viewYear, _viewMonth));

      final db = await AppDatabase.instance.database;
      final metaRows = await db.query('app_meta');

      String companyNameAr = '';
      String companyNameEn = '';
      String companyAddressAr = '';
      String companyAddressEn = '';
      String companyPhone = '';

      for (var row in metaRows) {
        if (row['key'] == 'company_name_ar') {
          companyNameAr = row['value'] as String;
        }
        if (row['key'] == 'company_name_en') {
          companyNameEn = row['value'] as String;
        }
        if (row['key'] == 'company_address_ar') {
          companyAddressAr = row['value'] as String;
        }
        if (row['key'] == 'company_address_en') {
          companyAddressEn = row['value'] as String;
        }
        if (row['key'] == 'company_phone') {
          companyPhone = row['value'] as String;
        }
      }

      final data = employees.map((e) {
        final payroll = _getPayrollForMonth(e.id);
        final displayName = isAr
            ? (e.nameAr.isNotEmpty ? e.nameAr : e.nameEn)
            : (e.nameEn.isNotEmpty ? e.nameEn : e.nameAr);

        final basic = payroll?.basicSalary ?? e.basicSalary;
        final variable = payroll?.variableSalary ?? e.variableSalary;
        final allowances = payroll?.allowances ?? e.allowances;
        final deductions = payroll?.deductions ?? e.deductions;
        final net = payroll?.netSalary ?? 0.0;
        final paid = payroll != null ? (_paidAmounts[payroll.id] ?? 0.0) : 0.0;
        final remaining = net - paid;

        return {
          'name': displayName,
          'department': e.department,
          'basicSalary': basic,
          'variableSalary': variable,
          'allowances': allowances,
          'deductions': deductions,
          'tax': payroll?.taxAmount ?? 0,
          'insurance': payroll?.insuranceAmount ?? 0,
          'netSalary': net,
          'paid': paid,
          'remaining': remaining,
          'bankName': e.bankName,
          'bankAccount': e.bankAccount,
          'bankIban': e.bankIban,
        };
      }).toList();

      final filePath = await PdfExportService.exportPayrollReport(
        data,
        title: isBank
            ? (isAr ? 'كشف تحويلات بنكية' : 'Bank Transfer Sheet')
            : (isAr
                ? 'كشف مرتبات شهر $monthName $_viewYear'
                : 'Payroll Report - $monthName $_viewYear'),
        isArabic: isAr,
        isBankTransfer: isBank,
        companyNameAr: companyNameAr,
        companyNameEn: companyNameEn,
        companyAddressAr: companyAddressAr,
        companyAddressEn: companyAddressEn,
        companyPhone: companyPhone,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${'pdf_exported_success'.tr()}\n$filePath'),
              duration: const Duration(seconds: 5)),
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

    final filteredEmployees = allEmployees.where((e) {
      final hasSalary = _hasValidSalary(e);
      final matchesPayment = _filterPaymentMethod == 'all' ||
          e.paymentMethod == _filterPaymentMethod;
      final matchesDept =
          _filterDepartment == 'all' || e.department == _filterDepartment;
      return hasSalary && matchesPayment && matchesDept;
    }).toList();

    final departments = allEmployees.map((e) => e.department).toSet().toList();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputFillColor =
        isDark ? theme.colorScheme.surface : Colors.grey.shade100;

    return Scaffold(
      appBar: AppBar(
        title: Text('payroll'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (context.watch<AuthService>().can(Permission.runPayroll))
            IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.calculate),
              onPressed: _isGenerating ? null : _showGeneratePayrollDialog,
              tooltip: 'generate_payroll_records'.tr(),
            ),
          if (context.watch<AuthService>().can(Permission.runPayroll))
            IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.monetization_on, color: Colors.amber),
              onPressed: _showBulkPaymentDialog,
              tooltip: 'bulk_payment'.tr(),
            ),
          if (context.watch<AuthService>().can(Permission.runPayroll))
            IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_calendar),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PaymentAdjustmentPage()),
              ),
              tooltip: 'payment_adjustments'.tr(),
            ),
          if (context.watch<AuthService>().can(Permission.exportReports))
            IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportPdf,
              tooltip: 'export_pdf'.tr(),
            ),
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'refresh'.tr(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 12.0),
                  color: theme.cardColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _viewMonth,
                          decoration: InputDecoration(
                            labelText: 'month'.tr(),
                            isDense: true,
                            fillColor: inputFillColor,
                            filled: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                          items: List.generate(12, (i) => i + 1).map((m) {
                            return DropdownMenuItem(
                                value: m,
                                child: Text(DateFormat(
                                        'MMM', context.locale.languageCode)
                                    .format(DateTime(2000, m))));
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _viewMonth = val!);
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _viewYear,
                          decoration: InputDecoration(
                            labelText: 'year'.tr(),
                            isDense: true,
                            fillColor: inputFillColor,
                            filled: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                          items: List.generate(
                              5, (i) => DateTime.now().year - 2 + i).map((y) {
                            return DropdownMenuItem(
                                value: y, child: Text(y.toString()));
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _viewYear = val!);
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _filterDepartment,
                          decoration: InputDecoration(
                            labelText: 'department'.tr(),
                            isDense: true,
                            fillColor: inputFillColor,
                            filled: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: 'all', child: Text('all'.tr())),
                            ...departments.map((d) =>
                                DropdownMenuItem(value: d, child: Text(d))),
                          ],
                          onChanged: (val) =>
                              setState(() => _filterDepartment = val!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _filterPaymentMethod,
                          decoration: InputDecoration(
                            labelText: 'payment_method'.tr(),
                            isDense: true,
                            fillColor: inputFillColor,
                            filled: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: 'all', child: Text('all'.tr())),
                            DropdownMenuItem(
                                value: 'cash', child: Text('cash'.tr())),
                            DropdownMenuItem(
                                value: 'bank', child: Text('bank'.tr())),
                          ],
                          onChanged: (val) =>
                              setState(() => _filterPaymentMethod = val!),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.green.withValues(alpha: 0.08),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('double_tap_hint'.tr(),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.green)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredEmployees.isEmpty
                      ? Center(child: Text('no_employees'.tr()))
                      : Scrollbar(
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
                                columns: [
                                  DataColumn(label: Text('name'.tr())),
                                  DataColumn(label: Text('department'.tr())),
                                  DataColumn(label: Text('basic_salary'.tr())),
                                  DataColumn(label: Text('variable'.tr())),
                                  DataColumn(label: Text('allowances'.tr())),
                                  DataColumn(
                                      label: Text('total_earned'.tr(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('deductions'.tr())),
                                  DataColumn(label: Text('tax'.tr())),
                                  DataColumn(label: Text('insurance'.tr())),
                                  DataColumn(
                                      label: Text('total_deducted'.tr(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('net_salary'.tr(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('paid'.tr(),
                                          style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('remaining'.tr(),
                                          style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('payment_method'.tr())),
                                  DataColumn(label: Text('action'.tr())),
                                ],
                                rows: filteredEmployees.map((e) {
                                  final payroll = _getPayrollForMonth(e.id);

                                  final basic =
                                      payroll?.basicSalary ?? e.basicSalary;
                                  final variable = payroll?.variableSalary ??
                                      e.variableSalary;
                                  final allowances =
                                      payroll?.allowances ?? e.allowances;
                                  final deductions =
                                      payroll?.deductions ?? e.deductions;
                                  final totalEarned = payroll?.totalEarned ??
                                      (basic + variable + allowances);
                                  final tax = payroll?.taxAmount ?? 0;
                                  final insurance =
                                      payroll?.insuranceAmount ?? 0;
                                  final totalDeducted =
                                      payroll?.totalDeducted ??
                                          (deductions + tax + insurance);
                                  final net = payroll?.netSalary ?? 0;
                                  final paid = payroll != null
                                      ? (_paidAmounts[payroll.id] ?? 0.0)
                                      : 0.0;
                                  final remaining = net - paid;

                                  DataCell cell(Widget child) => DataCell(
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onDoubleTap: () =>
                                              _openEmployeeDetail(e),
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
                                    cell(Text(paid.toStringAsFixed(2),
                                        style: const TextStyle(
                                            color: Colors.orange))),
                                    cell(Text(remaining.toStringAsFixed(2),
                                        style: TextStyle(
                                            color: remaining > 0
                                                ? Colors.red
                                                : Colors.green,
                                            fontWeight: FontWeight.bold))),
                                    cell(Text(e.paymentMethod == 'cash'
                                        ? 'cash'.tr()
                                        : 'bank'.tr())),
                                    cell(
                                      IconButton(
                                        icon: const Icon(Icons.payments,
                                            color: Colors.blue),
                                        tooltip: 'register_payment'.tr(),
                                        onPressed: () =>
                                            _showPaymentDialog(e, payroll),
                                      ),
                                    ),
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
