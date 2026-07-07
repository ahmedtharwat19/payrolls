import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../services/backup_service.dart';
import '../../services/bulk_import_service.dart';

class DataToolsPage extends StatefulWidget {
  const DataToolsPage({super.key});

  @override
  State<DataToolsPage> createState() => _DataToolsPageState();
}

class _DataToolsPageState extends State<DataToolsPage> {
  final _backupService = BackupService();
  final _importService = BulkImportService();
  bool _busy = false;

  void _snack(String messageKey) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageKey.tr())));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    final path = await _backupService.exportBackup();
    setState(() => _busy = false);
    _snack(path != null ? 'backup_exported_ok' : 'backup_cancelled');
  }

  Future<void> _restore({required bool merge}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('restore_backup'.tr()),
        content: Text(merge ? 'restore_merge_warning'.tr() : 'restore_overwrite_warning'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('continue_button'.tr())),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final result = await _backupService.restoreBackup(merge: merge);
    setState(() => _busy = false);
    _snack(result.message);
  }

  Future<void> _bulkImport() async {
    setState(() => _busy = true);
    final result = await _importService.importFromExcel();
    setState(() => _busy = false);

    if (result.cancelled) return;

    final msg = '${'import_done'.tr()}: ${result.imported}'
        '${result.errors.isNotEmpty ? ' - ${'import_errors'.tr()}: ${result.errors.length}' : ''}';

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('data_tools'.tr())),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTitle('backup_section'.tr()),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: Text('export_backup'.tr()),
                  subtitle: Text('export_backup_desc'.tr()),
                  onTap: _export,
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
                const Divider(height: 32),
                _SectionTitle('import_section'.tr()),
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: Text('bulk_import_employees'.tr()),
                  subtitle: Text('bulk_import_desc'.tr()),
                  onTap: _bulkImport,
                ),
              ],
            ),
    );
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
