// employee_page.dart placeholder// lib/views/employee/employee_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../controllers/employee_controller.dart';
import '../../views/employee/employee_form.dart';
import '../../views/employee/employee_card.dart';

class EmployeePage extends StatelessWidget {
  const EmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context);

    return Scaffold(
      appBar: AppBar(title: Text('employees'.tr())),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EmployeeForm(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: controller.employees.length,
        itemBuilder: (context, index) {
          final employee = controller.employees[index];
          return EmployeeCard(employee: employee);
        },
      ),
    );
  }
}