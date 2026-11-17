// lib/views/attendance/attendance_page.dart

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
// ✅ تم حذف import 'package:intl/intl.dart'; لأنه غير ضروري
import '../../controllers/employee_controller.dart';
import '../../services/attendance_service.dart';
import '../../models/employee_model.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _service = AttendanceService();
  final _scrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _records = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final controller = Provider.of<EmployeeController>(context, listen: false);
    await controller.refresh();

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final Map<String, Map<String, dynamic>> recs = {};

    // ✅ فلترة: بس الموظفين اللي بيتبعوا الحضور
    final attendanceEmployees = controller.employees
        .where((e) => e.isActive && e.attendanceEnabled)
        .toList();

    for (var e in attendanceEmployees) {
      final rec = await _service.getAttendanceForDay(e.id, dateStr);
      if (rec != null) recs[e.id] = rec.toMap();
    }

    if (mounted) {
      setState(() {
        _records = recs;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIn(Employee e) async {
    await _service.checkIn(e.id);
    await _loadData();
  }

  Future<void> _checkOut(Employee e) async {
    await _service.checkOut(e.id);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final employees = controller.employees
        .where((e) => e.isActive && e.attendanceEnabled)
        .toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('attendance_and_departure'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadData();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: theme.colorScheme.primaryContainer,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${'today_is'.tr()}: ${DateFormat('EEEE, d MMMM yyyy', context.locale.languageCode).format(_selectedDate)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final emp = employees[index];
                      final record = _records[emp.id];
                      final hasCheckedIn =
                          record != null && record['checkInTime'] != null;
                      final hasCheckedOut =
                          record != null && record['checkOutTime'] != null;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: hasCheckedIn
                                ? Colors.green.shade100
                                : theme.colorScheme.surface,
                            child: Text(
                              emp.nameAr.isNotEmpty ? emp.nameAr[0] : '?',
                              style: TextStyle(
                                  color: hasCheckedIn
                                      ? Colors.green.shade800
                                      : theme.colorScheme.onSurface),
                            ),
                          ),
                          title: Text(emp.getDisplayName(context)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${emp.department} - ${emp.jobTitle}'),
                              if (hasCheckedIn)
                                Text(
                                  '${'check_in_time'.tr()}: ${record['checkInTime']} | ${'check_out_time'.tr()}: ${record['checkOutTime'] ?? 'not_recorded'.tr()}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              if (record != null &&
                                  (record['lateMinutes'] > 0 ||
                                      record['overtimeMinutes'] > 0))
                                Text(
                                  '${'late'.tr()}: ${record['lateMinutes']} ${'minutes'.tr()} | ${'overtime'.tr()}: ${record['overtimeMinutes']} ${'minutes'.tr()}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.redAccent),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!hasCheckedIn)
                                ElevatedButton(
                                  onPressed: () => _checkIn(emp),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  child: Text('check_in'.tr(),
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.white)),
                                )
                              else if (!hasCheckedOut)
                                ElevatedButton(
                                  onPressed: () => _checkOut(emp),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange),
                                  child: Text('check_out'.tr(),
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.white)),
                                )
                              else
                                const Icon(Icons.check_circle,
                                    color: Colors.green),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
