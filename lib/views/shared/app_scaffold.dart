// lib/views/shared/app_scaffold.dart
//
// ✅ نسخة Responsive:
//   - موبايل (Android/عرض ضيق): Drawer قابل للسحب زي الأول بالظبط.
//   - تابلت/ديسكتوب (Windows/عرض واسع): NavigationRail ثابت جنب المحتوى،
//     زي أي تطبيق ديسكتوب حقيقي، بدل ما المستخدم يفتح ويقفل Drawer كل مرة.
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_payrolls/views/reports/reports_page.dart';
import '../../core/responsive/breakpoints.dart';
import '../employee/employee_page.dart';
import '../payroll/payroll_page.dart';
import '../settings/rules_page.dart';
import '../settings/settings_page.dart';
import '../auth/login_page.dart';
import '../backup/data_tools_page.dart';

class _NavItem {
  final IconData icon;
  final String labelKey;
  final Widget Function() pageBuilder;
  final Color? color;

  const _NavItem({
    required this.icon,
    required this.labelKey,
    required this.pageBuilder,
    this.color,
  });
}

class AppScaffold extends StatelessWidget {
  final Widget body;
  const AppScaffold({super.key, required this.body});

  static final List<_NavItem> _items = [
    _NavItem(
      icon: Icons.people_alt_outlined,
      labelKey: 'employees',
      pageBuilder: () => const EmployeePage(),
    ),
    _NavItem(
      icon: Icons.attach_money_outlined,
      labelKey: 'payroll',
      pageBuilder: () => const PayrollPage(),
    ),
    _NavItem(
      icon: Icons.gavel,
      labelKey: 'rules_settings',
      pageBuilder: () => const RulesPage(),
    ),
    _NavItem(
      icon: Icons.assessment,
      labelKey: 'reports',
      pageBuilder: () => const ReportsPage(),
    ),
    _NavItem(
      icon: Icons.storage_outlined,
      labelKey: 'data_tools',
      pageBuilder: () => const DataToolsPage(),
    ),
    _NavItem(
      icon: Icons.settings,
      labelKey: 'settings',
      pageBuilder: () => const SettingsPage(),
    ),
  ];

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AppScaffold(body: page)),
    );
  }

  void _logout(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          homeAfterLogin: const AppScaffold(body: EmployeePage()),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, {bool showMenu = true}) {
    return AppBar(
      title: Text('payroll_system'.tr()),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: showMenu,
      leading: showMenu
          ? Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : null,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.language),
          onSelected: (String value) async {
            if (value == 'ar') {
              await context.setLocale(const Locale('ar'));
            } else {
              await context.setLocale(const Locale('en'));
            }
          },
          itemBuilder: (BuildContext context) {
            return [
              const PopupMenuItem(value: 'ar', child: Text('العربية')),
              const PopupMenuItem(value: 'en', child: Text('English')),
            ];
          },
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildHeader(),
          for (final item in _items)
            ListTile(
              leading: Icon(item.icon, color: item.color),
              title: Text(item.labelKey.tr()),
              onTap: () => _navigateTo(context, item.pageBuilder()),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text('logout'.tr(), style: const TextStyle(color: Colors.red)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade700],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, size: 40, color: Colors.white),
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
    );
  }

  /// شريط جانبي ثابت لوضع الديسكتوب/التابلت - بديل الـ Drawer.
  Widget _buildRail(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          extended: context.isDesktop,
          minExtendedWidth: 220,
          backgroundColor: Colors.green.shade50,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Icon(
              Icons.account_balance_wallet,
              size: 32,
              color: Colors.green.shade700,
            ),
          ),
          selectedIndex: null,
          destinations: [
            for (final item in _items)
              NavigationRailDestination(
                icon: Icon(item.icon),
                label: Text(item.labelKey.tr()),
              ),
          ],
          onDestinationSelected: (index) {
            _navigateTo(context, _items[index].pageBuilder());
          },
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  tooltip: 'logout'.tr(),
                  onPressed: () => _logout(context),
                ),
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWideScreen; // tablet or desktop

    if (!wide) {
      // ============ موبايل: نفس السلوك القديم بالظبط ============
      return Scaffold(
        drawer: _buildDrawer(context),
        appBar: _buildAppBar(context),
        body: SafeArea(child: body),
      );
    }

    // ============ تابلت/ديسكتوب: NavigationRail ثابت ============
    return Scaffold(
      appBar: _buildAppBar(context, showMenu: false),
      body: SafeArea(
        child: Row(
          children: [
            _buildRail(context),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
