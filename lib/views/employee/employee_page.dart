/* // lib/views/employee/employee_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
import '../../models/employee_model.dart';
import '../../views/employee/employee_form.dart';
import '../../views/employee/employee_card.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/permission.dart';

class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  String _searchQuery = '';
  String _filterDepartment = 'all';
  String _filterStatus = 'all';

  final List<String> _departments = [
    'all',
    'hr',
    'it',
    'finance',
    'sales',
    'marketing',
    'operations',
    'logistics',
    'quality',
    'maintenance',
    'purchasing',
  ];

  List<Employee> _getFilteredEmployees(List<Employee> employees) {
    final query = _searchQuery.trim().toLowerCase();
    
    // ✅ إذا كان البحث فارغاً، نعرض الكل
    if (query.isEmpty && _filterDepartment == 'all' && _filterStatus == 'all') {
      return employees;
    }

    return employees.where((emp) {
      // ✅ البحث في الاسم العربي والإنجليزي معاً
      final nameMatch = query.isEmpty ||
          emp.nameAr.toLowerCase().contains(query) ||
          emp.nameEn.toLowerCase().contains(query);
      
      // ✅ فلتر القسم
      final deptMatch = _filterDepartment == 'all' || emp.department == _filterDepartment;
      
      // ✅ فلتر الحالة
      final statusMatch = _filterStatus == 'all' || 
          (_filterStatus == 'active' && emp.isActive) ||
          (_filterStatus == 'inactive' && !emp.isActive);
      
      return nameMatch && deptMatch && statusMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final auth = context.watch<AuthService>();
    final canAdd = auth.can(Permission.addEmployee);
    final canEdit = auth.can(Permission.editEmployee);
    final canDelete = auth.can(Permission.deleteEmployee);
    final filteredEmployees = _getFilteredEmployees(controller.employees);

    return Scaffold(
      appBar: AppBar(
        title: Text('employees'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // ✅ زر التحديث
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
            tooltip: 'refresh'.tr(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // ✅ شريط البحث
                TextField(
                  decoration: InputDecoration(
                    hintText: 'search_employees'.tr(),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 6),
                // ✅ فلاتر
                Row(
                  children: [
                    // فلتر القسم
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterDepartment,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          isDense: true,
                        ),
                        items: _departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept,
                            child: Text(dept == 'all' ? 'all_departments'.tr() : dept.tr()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _filterDepartment = value!);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // فلتر الحالة
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterStatus,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          isDense: true,
                        ),
                        items: [
                          'all',
                          'active',
                          'inactive',
                        ].map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status == 'all' ? 'all_status'.tr() : status.tr()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _filterStatus = value!);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: !canAdd
          ? null
          : FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EmployeeForm(),
            ),
          );
        },
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: filteredEmployees.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchQuery.isNotEmpty || _filterDepartment != 'all' || _filterStatus != 'all'
                          ? Icons.search_off
                          : Icons.people_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty || _filterDepartment != 'all' || _filterStatus != 'all'
                          ? 'no_results'.tr()
                          : 'no_employees'.tr(),
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    if (_searchQuery.isNotEmpty || _filterDepartment != 'all' || _filterStatus != 'all')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _filterDepartment = 'all';
                            _filterStatus = 'all';
                          });
                        },
                        child: Text('clear_filters'.tr()),
                      ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: filteredEmployees.length,
                itemBuilder: (context, index) {
                  final employee = filteredEmployees[index];
                  return EmployeeCard(
                    employee: employee,
                    onEdit: !canEdit
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmployeeForm(employee: employee),
                        ),
                      );
                    },
                    onDelete: !canDelete
                        ? null
                        : () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('delete_employee'.tr()),
                          content: Text('confirm_delete'.tr()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('cancel'.tr()),
                            ),
                            TextButton(
                              onPressed: () {
                                if (!context.read<AuthService>().can(Permission.deleteEmployee)) {
                                  Navigator.pop(context);
                                  return;
                                }
                                controller.deleteEmployee(employee.id);
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: Text('delete'.tr()),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
} */

// lib/views/employee/employee_page.dart
/* 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
import '../../models/employee_model.dart';
import '../../views/employee/employee_form.dart';
import '../../views/employee/employee_card.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/permission.dart';

class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  String _searchQuery = '';
  String _filterDepartment = 'all';
  String _filterStatus = 'all';

  final List<String> _departments = [
    'all',
    'hr',
    'it',
    'finance',
    'sales',
    'marketing',
    'operations',
    'logistics',
    'quality',
    'maintenance',
    'purchasing',
  ];

  List<Employee> _getFilteredEmployees(List<Employee> employees) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty && _filterDepartment == 'all' && _filterStatus == 'all') {
      return employees;
    }
    return employees.where((emp) {
      final nameMatch = query.isEmpty ||
          emp.nameAr.toLowerCase().contains(query) ||
          emp.nameEn.toLowerCase().contains(query);
      final deptMatch =
          _filterDepartment == 'all' || emp.department == _filterDepartment;
      final statusMatch = _filterStatus == 'all' ||
          (_filterStatus == 'active' && emp.isActive) ||
          (_filterStatus == 'inactive' && !emp.isActive);
      return nameMatch && deptMatch && statusMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final auth = context.watch<AuthService>();
    final canAdd = auth.can(Permission.addEmployee);
    final canEdit = auth.can(Permission.editEmployee);
    final canDelete = auth.can(Permission.deleteEmployee);
    final filteredEmployees = _getFilteredEmployees(controller.employees);

    // ✅ جلب لون الخلفية من الثيم
    final theme = Theme.of(context);
    final inputFillColor = theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text('employees'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
            tooltip: 'refresh'.tr(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'search_employees'.tr(),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: inputFillColor, // ✅ تعديل اللون
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterDepartment,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFillColor, // ✅ تعديل اللون
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          isDense: true,
                        ),
                        isExpanded: true, // ✅ منع الـ Overflow
                        items: _departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept,
                            child: Text(
                              dept == 'all'
                                  ? 'all_departments'.tr()
                                  : dept.tr(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _filterDepartment = value!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterStatus,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFillColor, // ✅ تعديل اللون
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          isDense: true,
                        ),
                        isExpanded: true, // ✅ منع الـ Overflow
                        items: ['all', 'active', 'inactive'].map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status == 'all' ? 'all_status'.tr() : status.tr(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _filterStatus = value!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: !canAdd
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EmployeeForm()));
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: filteredEmployees.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchQuery.isNotEmpty ||
                              _filterDepartment != 'all' ||
                              _filterStatus != 'all'
                          ? Icons.search_off
                          : Icons.people_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty ||
                              _filterDepartment != 'all' ||
                              _filterStatus != 'all'
                          ? 'no_results'.tr()
                          : 'no_employees'.tr(),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    if (_searchQuery.isNotEmpty ||
                        _filterDepartment != 'all' ||
                        _filterStatus != 'all')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _filterDepartment = 'all';
                            _filterStatus = 'all';
                          });
                        },
                        child: Text('clear_filters'.tr()),
                      ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: filteredEmployees.length,
                itemBuilder: (context, index) {
                  final employee = filteredEmployees[index];
                  return EmployeeCard(
                    employee: employee,
                    onEdit: !canEdit
                        ? null
                        : () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        EmployeeForm(employee: employee)));
                          },
                    onDelete: !canDelete
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('delete_employee'.tr()),
                                content: Text('confirm_delete'.tr()),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('cancel'.tr())),
                                  TextButton(
                                    onPressed: () {
                                      if (!context
                                          .read<AuthService>()
                                          .can(Permission.deleteEmployee)) {
                                        Navigator.pop(context);
                                        return;
                                      }
                                      controller.deleteEmployee(employee.id);
                                      Navigator.pop(context);
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: Text('delete'.tr()),
                                  ),
                                ],
                              ),
                            );
                          },
                  );
                },
              ),
      ),
    );
  }
}
 */

// lib/views/employee/employee_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
import '../../models/employee_model.dart';
import '../../views/employee/employee_form.dart';
import '../../views/employee/employee_card.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/permission.dart';

class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  String _searchQuery = '';
  String _filterDepartment = 'all';
  String _filterStatus = 'all';

  final List<String> _departments = [
    'all',
    'hr',
    'it',
    'finance',
    'sales',
    'marketing',
    'operations',
    'logistics',
    'quality',
    'maintenance',
    'purchasing',
  ];

  List<Employee> _getFilteredEmployees(List<Employee> employees) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty && _filterDepartment == 'all' && _filterStatus == 'all') {
      return employees;
    }
    return employees.where((emp) {
      final nameMatch = query.isEmpty ||
          emp.nameAr.toLowerCase().contains(query) ||
          emp.nameEn.toLowerCase().contains(query);
      final deptMatch =
          _filterDepartment == 'all' || emp.department == _filterDepartment;
      final statusMatch = _filterStatus == 'all' ||
          (_filterStatus == 'active' && emp.isActive) ||
          (_filterStatus == 'inactive' && !emp.isActive);
      return nameMatch && deptMatch && statusMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);
    final auth = context.watch<AuthService>();
    final canAdd = auth.can(Permission.addEmployee);
    final canEdit = auth.can(Permission.editEmployee);
    final canDelete = auth.can(Permission.deleteEmployee);
    final filteredEmployees = _getFilteredEmployees(controller.employees);

    final theme = Theme.of(context);
    final inputFillColor = theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text('employees'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
            tooltip: 'refresh'.tr(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'search_employees'.tr(),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterDepartment,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          isDense: true,
                        ),
                        isExpanded: true, // ✅ مهم جداً لمنع الـ Overflow
                        items: _departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept,
                            child: Text(
                              dept == 'all'
                                  ? 'all_departments'.tr()
                                  : dept.tr(),
                              overflow: TextOverflow.ellipsis, // ✅ مهم جداً
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _filterDepartment = value!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterStatus,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          isDense: true,
                        ),
                        isExpanded: true, // ✅ مهم جداً لمنع الـ Overflow
                        items: ['all', 'active', 'inactive'].map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status == 'all' ? 'all_status'.tr() : status.tr(),
                              overflow: TextOverflow.ellipsis, // ✅ مهم جداً
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _filterStatus = value!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: !canAdd
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EmployeeForm()));
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: filteredEmployees.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchQuery.isNotEmpty ||
                              _filterDepartment != 'all' ||
                              _filterStatus != 'all'
                          ? Icons.search_off
                          : Icons.people_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty ||
                              _filterDepartment != 'all' ||
                              _filterStatus != 'all'
                          ? 'no_results'.tr()
                          : 'no_employees'.tr(),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    if (_searchQuery.isNotEmpty ||
                        _filterDepartment != 'all' ||
                        _filterStatus != 'all')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _filterDepartment = 'all';
                            _filterStatus = 'all';
                          });
                        },
                        child: Text('clear_filters'.tr()),
                      ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: filteredEmployees.length,
                itemBuilder: (context, index) {
                  final employee = filteredEmployees[index];
                  return EmployeeCard(
                    employee: employee,
                    onEdit: !canEdit
                        ? null
                        : () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        EmployeeForm(employee: employee)));
                          },
                    onDelete: !canDelete
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('delete_employee'.tr()),
                                content: Text('confirm_delete'.tr()),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('cancel'.tr())),
                                  TextButton(
                                    onPressed: () {
                                      if (!context
                                          .read<AuthService>()
                                          .can(Permission.deleteEmployee)) {
                                        Navigator.pop(context);
                                        return;
                                      }
                                      controller.deleteEmployee(employee.id);
                                      Navigator.pop(context);
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: Text('delete'.tr()),
                                  ),
                                ],
                              ),
                            );
                          },
                  );
                },
              ),
      ),
    );
  }
}
