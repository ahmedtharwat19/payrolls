// lib/views/settings/cloud_backup_page.dart

import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/cloud_backup_service.dart';

class CloudBackupPage extends StatefulWidget {
  const CloudBackupPage({super.key});

  @override
  State<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends State<CloudBackupPage> {
  bool _isProcessing = false;

  Future<void> _export() async {
    setState(() => _isProcessing = true);
    final path = await CloudBackupService.exportEncryptedBackup();
    if (mounted) {
      setState(() => _isProcessing = false);
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('backup_success'.tr(args: [path]))),
        );
      }
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('warning'.tr()),
        content: Text('restore_warning'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('confirm'.tr())),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final success = await CloudBackupService.restoreEncryptedBackup();
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(success ? 'restore_success'.tr() : 'restore_failed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('cloud_backup'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isProcessing) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_upload,
                    color: Colors.blue, size: 32),
                title: Text('export_backup'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('export_backup_desc'.tr()),
                onTap: _isProcessing ? null : _export,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_download,
                    color: Colors.orange, size: 32),
                title: Text('restore_backup'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('restore_backup_desc'.tr()),
                onTap: _isProcessing ? null : _restore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
