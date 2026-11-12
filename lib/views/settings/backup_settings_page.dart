// lib/views/settings/backup_settings_page.dart
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';

/// شاشة إعدادات النسخ الاحتياطي - بتوري:
///  - إعداد مجلد الباكأب الخارجي (الأفضل يكون جوه OneDrive/Google Drive)
///  - زرار "باكأب دلوقتي" يدوي فوري
///  - قائمة كل النسخ الموجودة (من الأماكن الثلاثة) مع تاريخ وحجم ومصدر
///  - استرجاع أي نسخة (بعد تأكيد، وبيقفل التطبيق بعدها إجباريًا)
class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  String? _offsitePath;
  List<File> _backups = [];
  bool _loading = true;
  bool _busy = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final offsite = await AppDatabase.instance.getOffsiteBackupPath();
    final backups = await AppDatabase.instance.listBackups();
    if (!mounted) return;
    setState(() {
      _offsitePath = offsite;
      _backups = backups;
      _loading = false;
    });
  }

  Future<void> _chooseOffsiteFolder() async {
    // ⚠️ getDirectoryPath() لسه بترجع String? حتى في file_picker 12 -
    // الاختلاف اللي أثّر على pickFiles()/saveFile() ماأثّرش عليها.
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;

    await AppDatabase.instance.setOffsiteBackupPath(path);
    setState(() => _statusMessage = 'backup_offsite_saved'.tr());
    await _load();
  }

  Future<void> _clearOffsiteFolder() async {
    await AppDatabase.instance.setOffsiteBackupPath(null);
    setState(() => _statusMessage = 'backup_offsite_cleared'.tr());
    await _load();
  }

  Future<void> _backupNow() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    await AppDatabase.instance.createManualBackupNow();
    await _load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _statusMessage = 'backup_created_now'.tr();
    });
  }

  String _sourceLabel(File file) {
    final p = file.path;
    if (_offsitePath != null && p.startsWith(_offsitePath!)) {
      return 'backup_source_offsite'.tr();
    }
    // مجلد AppData بيحتوي على 'Roaming' في مساره على Windows - مش
    // مثالي كتحقق لكنه كافي هنا لمجرد عرض تسمية توضيحية للمستخدم.
    if (Platform.isWindows && p.toLowerCase().contains('roaming')) {
      return 'backup_source_appdata'.tr();
    }
    return 'backup_source_local'.tr();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _confirmRestore(File backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('backup_restore_confirm_title'.tr()),
        content: Text('backup_restore_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel_button'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('backup_restore_confirm_action'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await AppDatabase.instance.restoreBackup(backup);
      if (!mounted) return;

      // ⚠️ بنقفل التطبيق إجباريًا بعد الاسترجاع بدل ما نحاول نعيد
      // تحميل الشاشات الحالية - أي Provider/Controller فاتح بيانات
      // قديمة في الذاكرة مش هيعرف إن قاعدة البيانات اتغيّرت تحته،
      // فالأضمن قفل كامل وفتح جديد نضيف.
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('backup_restore_done_title'.tr()),
          content: Text('backup_restore_done_body'.tr()),
          actions: [
            FilledButton(
              onPressed: () => exit(0),
              child: Text('backup_restore_close_app'.tr()),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = 'backup_restore_failed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('backup_settings_title'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ---- إعداد المجلد الخارجي ----
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'backup_offsite_section_title'.tr(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'backup_offsite_section_desc'.tr(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          if (_offsitePath != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                border:
                                    Border.all(color: Colors.green.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _offsitePath!,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _busy ? null : _chooseOffsiteFolder,
                                  icon: const Icon(Icons.folder_outlined),
                                  label: Text(
                                    _offsitePath == null
                                        ? 'backup_choose_folder_button'.tr()
                                        : 'backup_change_folder_button'.tr(),
                                  ),
                                ),
                              ),
                              if (_offsitePath != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _busy ? null : _clearOffsiteFolder,
                                  icon: const Icon(Icons.close),
                                  tooltip: 'backup_clear_folder_tooltip'.tr(),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _backupNow,
                      icon: const Icon(Icons.backup_outlined),
                      label: Text('backup_now_button'.tr()),
                    ),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_statusMessage!, textAlign: TextAlign.center),
                  ],

                  const SizedBox(height: 24),
                  Text(
                    'backup_list_title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  if (_backups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('backup_list_empty'.tr())),
                    )
                  else
                    ..._backups.map((file) {
                      final stat = file.statSync();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(_formatDate(stat.modified)),
                          subtitle: Text(
                            '${_sourceLabel(file)}  ·  ${_formatSize(stat.size)}',
                          ),
                          trailing: TextButton(
                            onPressed:
                                _busy ? null : () => _confirmRestore(file),
                            child: Text('backup_restore_button'.tr()),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
