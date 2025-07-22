// lib/views/shared/app_scaffold.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../employee/employee_page.dart';
import '../payroll/payroll_page.dart';
import '../settings/rules_page.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  const AppScaffold({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade700],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'payroll_system'.tr(),
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: Text('employees'.tr()),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppScaffold(body: EmployeePage()),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money_outlined),
              title: Text('payroll'.tr()),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppScaffold(body: PayrollPage()),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text('rules_settings'.tr()),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppScaffold(body: RulesPage()),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(title: Text('payroll_system'.tr())),
      body: SafeArea(child: body),
    );
  }
}
