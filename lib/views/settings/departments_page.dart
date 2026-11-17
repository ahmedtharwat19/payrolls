// lib/views/settings/departments_page.dart
import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/department_service.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  final _service = DepartmentService();
  final _controller = TextEditingController();
  List<String> _departments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final depts = await _service.getAll();
    if (mounted) {
      setState(() {
        _departments = depts;
        _isLoading = false;
      });
    }
  }

  Future<void> _add() async {
    if (_controller.text.trim().isEmpty) return;
    await _service.add(_controller.text);
    _controller.clear();
    await _load();
  }

  Future<void> _delete(String id) async {
    try {
      await _service.delete(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains('department_has_employees')
              ? 'department_has_employees'.tr()
              : 'error_general'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('departments_management'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✅ إضافة قسم جديد
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            labelText: 'new_department_name'.tr(),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.business),
                          ),
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        tooltip: 'add'.tr(),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // ✅ قائمة الأقسام
                Expanded(
                  child: _departments.isEmpty
                      ? Center(child: Text('no_departments'.tr()))
                      : ListView.builder(
                          itemCount: _departments.length,
                          itemBuilder: (context, index) {
                            final dept = _departments[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  child: Text(
                                    dept.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(dept),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _delete(dept),
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
