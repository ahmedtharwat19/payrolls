// lib/views/shared/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_payrolls/views/reports/reports_page.dart';
import '../employee/employee_page.dart';
import '../payroll/payroll_page.dart';
import '../settings/rules_page.dart';
import '../settings/settings_page.dart';
import '../auth/login_page.dart'; // ✅ أضف هذا
import '../backup/data_tools_page.dart'; // ✅ أدوات البيانات (نسخ احتياطي + استيراد)

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
            // ✅ الموظفين
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
            // ✅ الرواتب
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
            // ✅ القواعد (إعدادات الضرائب والتأمينات)
            ListTile(
              leading: const Icon(Icons.gavel),
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
            //  /,/ في app_scaffold.dart - أضف في Drawer
            ListTile(
              leading: const Icon(Icons.assessment),
              title: Text('reports'.tr()),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppScaffold(body: ReportsPage()),
                  ),
                );
              },
            ),
            // ✅ أدوات البيانات (نسخ احتياطي + استيراد دفعة موظفين)
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: Text('data_tools'.tr()),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppScaffold(body: DataToolsPage()),
                  ),
                );
              },
            ),
            // ✅ الإعدادات العامة
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: Text('settings'.tr()),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppScaffold(body: SettingsPage()),
                  ),
                );
              },
            ),
            const Divider(),
            // ✅ تسجيل الخروج
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                'logout'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                // ✅ إصلاح تسجيل الخروج - تمرير homeAfterLogin
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => LoginPage(
                      homeAfterLogin: const AppScaffold(body: EmployeePage()),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text('payroll_system'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}
