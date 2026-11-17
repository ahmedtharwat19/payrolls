// lib/views/settings/attendance_settings_page.dart

import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/settings/attendance_settings.dart';

class AttendanceSettingsPage extends StatefulWidget {
  const AttendanceSettingsPage({super.key});

  @override
  State<AttendanceSettingsPage> createState() => _AttendanceSettingsPageState();
}

class _AttendanceSettingsPageState extends State<AttendanceSettingsPage> {
  AttendanceSettings _settings = const AttendanceSettings();
  bool _isLoading = true;

  final _weekdayNames = {
    1: 'الاثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
    7: 'الأحد',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AttendanceSettingsService.load();
    if (mounted) {
      setState(() {
        _settings = s;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    await AttendanceSettingsService.save(_settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings_saved_success'.tr())),
    );
    Navigator.pop(context);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart
        ? _settings.getWorkStart(DateTime.now())
        : _settings.getWorkEnd(DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _settings = isStart
            ? _settings.copyWith(workStartTime: formatted)
            : _settings.copyWith(workEndTime: formatted);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('attendance_settings'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ================= مواعيد العمل =================
                _buildSectionTitle('work_hours'.tr()),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.login, color: Colors.green),
                        title: Text('work_start_time'.tr()),
                        subtitle: Text(_settings.workStartTime),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _pickTime(isStart: true),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: Text('work_end_time'.tr()),
                        subtitle: Text(_settings.workEndTime),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ================= سماحية التأخير =================
                _buildSectionTitle('grace_period'.tr()),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_settings.graceMinutes} ${'minutes'.tr()}',
                          style: theme.textTheme.titleMedium,
                        ),
                        Slider(
                          value: _settings.graceMinutes.toDouble(),
                          min: 0,
                          max: 60,
                          divisions: 12,
                          label: '${_settings.graceMinutes} دقيقة',
                          onChanged: (v) => setState(() {
                            _settings = _settings.copyWith(
                              graceMinutes: v.round(),
                            );
                          }),
                        ),
                        Text(
                          'grace_period_hint'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ================= معدل الإضافي =================
                _buildSectionTitle('overtime_rate'.tr()),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_settings.overtimeRate}x',
                          style: theme.textTheme.titleMedium,
                        ),
                        Slider(
                          value: _settings.overtimeRate,
                          min: 1.0,
                          max: 3.0,
                          divisions: 4,
                          label: '${_settings.overtimeRate}x',
                          onChanged: (v) => setState(() {
                            _settings = _settings.copyWith(overtimeRate: v);
                          }),
                        ),
                        Text(
                          'overtime_rate_hint'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ================= أيام العطلة =================
                _buildSectionTitle('weekend_days'.tr()),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _weekdayNames.entries.map((e) {
                        final selected = _settings.weekendDays.contains(e.key);
                        return FilterChip(
                          label: Text(e.value),
                          selected: selected,
                          onSelected: (val) {
                            final set = Set<int>.from(_settings.weekendDays);
                            if (val) {
                              set.add(e.key);
                            } else {
                              set.remove(e.key);
                            }
                            setState(() {
                              _settings = _settings.copyWith(weekendDays: set);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ================= زرار الحفظ =================
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text('save_settings'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
