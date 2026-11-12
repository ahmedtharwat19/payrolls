
 

// lib/views/data_tools/data_tools_page.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_payrolls/core/database/app_database.dart';
import '../../controllers/employee_controller.dart';
import '../../services/bulk_import_service.dart';
import '../../services/backup_service.dart';
import '../../core/audit/audit_log.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/permission.dart';

class DataToolsPage extends StatefulWidget {
  const DataToolsPage({super.key});

  @override
  State<DataToolsPage> createState() => _DataToolsPageState();
}

class _DataToolsPageState extends State<DataToolsPage> {
  final _importService = BulkImportService();
  bool _busy = false;

  // متغيرات لاختيار الشهر والسنة
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  void _snack(String messageKey) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(messageKey.tr())));
  }

  bool get _allowed => context.read<AuthService>().can(Permission.manageData);

  // ✅ نسخة احتياطية حقيقية (كانت الأزرار بتعرض رسالة نجاح وهمية)
  Future<void> _exportBackup() async {
    if (!_allowed) return _snack('auth_error_forbidden');
    setState(() => _busy = true);
    try {
      final saved =
          await BackupService().exportBackup(context.read<AuthService>());
      if (saved != null) _snack('backup_exported_ok');
    } catch (_) {
      _snack('backup_export_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore({required bool merge}) async {
    if (!_allowed) return _snack('auth_error_forbidden');
    if (!merge) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('restore_overwrite'.tr()),
          content: Text('clear_all_data_warning'.tr()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text('cancel'.tr())),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(c, true),
                child: Text('restore_overwrite'.tr())),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final auth = context.read<AuthService>();
    final controller = context.read<EmployeeController>();
    setState(() => _busy = true);
    try {
      final r = await BackupService().restoreBackup(auth, merge: merge);
      if (r.success) await controller.loadEmployees();
      _snack(r.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ✅ تصدير Excel
  Future<void> _exportExcel() async {
    setState(() => _busy = true);
    try {
      final filePath = await _importService.exportEmployeesToExcel();
      setState(() => _busy = false);
      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'export_excel_success'.tr()}\n$filePath'),
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (mounted) {
        _snack('export_excel_error');
      }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) _snack('export_excel_error');
    }
  }

  // ✅ تحميل النموذج
  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final filePath = await BulkImportService.downloadTemplate(context);
      setState(() => _busy = false);
      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'download_template_success'.tr()}\n$filePath'),
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (mounted) {
        _snack('download_template_error');
      }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) _snack('download_template_error');
    }
  }

  // ✅ الاستيراد
  Future<void> _bulkImport() async {
    setState(() => _busy = true);
    final result = await _importService.importFromExcel();
    setState(() => _busy = false);

    if (result.cancelled) return;

    if (result.imported > 0 && mounted) {
      final controller =
          Provider.of<EmployeeController>(context, listen: false);
      await controller.loadEmployees();
    }

    if (!mounted) return;
    final msg = '${'import_done'.tr()}: ${result.imported}'
        '${result.errors.isNotEmpty ? ' - ${'import_errors'.tr()}: ${result.errors.length}' : ''}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ✅ عرض حوار اختيار الشهر والسنة
  Future<void> _showGeneratePayrollDialog() async {
    // استخدم local variables للقيم الحالية
    int localMonth = _selectedMonth;
    int localYear = _selectedYear;

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('generate_payroll_records'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    // ✅ استخدم initialValue بدلاً من value
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
                        setDialogState(() {
                          localMonth = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    // ✅ استخدم initialValue بدلاً من value
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
                        setDialogState(() {
                          localYear = value;
                        });
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
                    // تحديث المتغيرات العامة
                    _selectedMonth = localMonth;
                    _selectedYear = localYear;
                    Navigator.pop(dialogContext);
                    // تنفيذ الإنشاء بعد إغلاق الحوار
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

  // ✅ إنشاء سجلات الرواتب
  Future<void> _generatePayrollRecords() async {
    setState(() => _busy = true);

    try {
      final count = await _importService.generatePayrollRecordsFromEmployees(
        month: _selectedMonth,
        year: _selectedYear,
      );

      setState(() => _busy = false);

      if (!mounted) return;

      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'payroll_records_created'.tr()}: $count'),
          ),
        );
        // تحديث البيانات بعد الإنشاء
        final controller =
            Provider.of<EmployeeController>(context, listen: false);
        await controller.loadEmployees();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('payroll_records_already_exist'.tr())),
        );
      }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_general'.tr())),
        );
      }
      debugPrint('خطأ في إنشاء سجلات الرواتب: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthService>().can(Permission.manageData)) {
      return Scaffold(
        appBar: AppBar(title: Text('data_tools'.tr())),
        body: Center(child: Text('auth_error_forbidden'.tr())),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('data_tools'.tr())),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTitle('excel_operations'.tr()),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: Text('download_template'.tr()),
                  subtitle: Text('download_template_desc'.tr()),
                  onTap: _downloadTemplate,
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text('bulk_import_employees'.tr()),
                  subtitle: Text('bulk_import_desc'.tr()),
                  onTap: _bulkImport,
                ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text('export_excel'.tr()),
                  subtitle: Text('export_excel_desc'.tr()),
                  onTap: _exportExcel,
                ),
                const Divider(height: 32),
                _SectionTitle('payroll_operations'.tr()),
                ListTile(
                  leading: const Icon(Icons.calculate),
                  title: Text('generate_payroll_records'.tr()),
                  subtitle: Text('generate_payroll_records_desc'.tr()),
                  onTap: _showGeneratePayrollDialog,
                ),
                const Divider(height: 32),
                _SectionTitle('maintenance_section'.tr()),
                ListTile(
                  leading: const Icon(Icons.build_circle_outlined),
                  title: Text('fix_duplicate_allowances'.tr()),
                  subtitle: Text('fix_duplicate_allowances_desc'.tr()),
                  onTap: _runFixDuplicateAllowances,
                ),
                const Divider(height: 32),
                _SectionTitle('backup_section'.tr()),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: Text('export_backup'.tr()),
                  subtitle: Text('export_backup_desc'.tr()),
                  onTap: _exportBackup,
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text('restore_merge'.tr()),
                  subtitle: Text('restore_merge_desc'.tr()),
                  onTap: () => _restore(merge: true),
                ),
                ListTile(
                  leading: const Icon(Icons.restore_page),
                  title: Text('restore_overwrite'.tr()),
                  subtitle: Text('restore_overwrite_desc'.tr()),
                  onTap: () => _restore(merge: false),
                ),
                // lib/views/data_tools/data_tools_page.dart

// ... بعد قسم backup_section

                _SectionTitle('danger_zone'.tr()),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('clear_all_data'.tr(),
                      style: const TextStyle(color: Colors.red)),
                  subtitle: Text('clear_all_data_desc'.tr()),
                  onTap: _showClearDataDialog,
                ),
              ],
            ),
    );
  }
// lib/services/bulk_import_service.dart

  /// تصحيح البيانات: إذا كان الأساسي يساوي البدلات، نضبط البدلات = 0
  Future<int> fixDuplicateAllowances() async {
    final db = await AppDatabase.instance.database;
    final count = await db.rawUpdate('''
    UPDATE employees 
    SET allowances = 0 
    WHERE basicSalary > 0 AND basicSalary = allowances
  ''');
    return count;
  }

  // ✅ تشغيل تصحيح تكرار الأساسي/البدلات مع تأكيد وتحديث الشاشة
  Future<void> _runFixDuplicateAllowances() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('fix_duplicate_allowances'.tr()),
        content: Text('fix_duplicate_allowances_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('continue_button'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final count = await fixDuplicateAllowances();
      setState(() => _busy = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? '${'fix_duplicate_allowances_done'.tr()}: $count'
              : 'fix_duplicate_allowances_none'.tr()),
        ),
      );

      if (count > 0) {
        final controller =
            Provider.of<EmployeeController>(context, listen: false);
        await controller.loadEmployees();
      }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_general'.tr())),
        );
      }
    }
  }

  /// عرض حوار تأكيد مسح البيانات
  Future<void> _showClearDataDialog() async {
    // حفظ السياق الحالي
    final currentContext = context;

    return showDialog(
      context: currentContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('clear_all_data'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('clear_all_data_warning'.tr()),
              const SizedBox(height: 16),
              Text(
                'clear_all_data_confirm'.tr(),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // استدعاء دالة المسح بعد إغلاق الحوار
                _clearAllData();
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text('clear_data'.tr()),
            ),
          ],
        );
      },
    );
  }

  /// تنفيذ عملية مسح البيانات
  Future<void> _clearAllData() async {
    final auth = context.read<AuthService>();
    if (!auth.can(Permission.manageData)) return _snack('auth_error_forbidden');
    setState(() => _busy = true);

    try {
      final count = await _importService.clearAllData();
      await AuditLog.record('clear_all_data',
          username: auth.currentUser?.username, details: '$count rows');

      setState(() => _busy = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'data_cleared_success'.tr()}: $count سجل'),
            backgroundColor: Colors.green,
          ),
        );

        // تحديث EmployeeController بعد المسح
        final controller =
            Provider.of<EmployeeController>(context, listen: false);
        await controller.loadEmployees();
      }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'error_general'.tr()}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
