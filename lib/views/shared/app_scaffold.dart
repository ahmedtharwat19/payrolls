// lib/views/shared/app_scaffold.dart
//
// ✅ نسخة Responsive:
//   - موبايل (Android/عرض ضيق): Drawer قابل للسحب زي الأول بالظبط.
//   - تابلت/ديسكتوب (Windows/عرض واسع): شريط جانبي (HoverSidebar) مضغوط
//     بيتمدد لما الماوس يعمل hover عليه، بدل NavigationRail الثابت.
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:puresip_payrolls/views/reports/reports_page.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/theme_controller.dart';
import '../employee/employee_page.dart';
import '../payroll/payroll_page.dart';
import '../settings/rules_page.dart';
import '../settings/settings_page.dart';
import '../auth/login_page.dart';
import '../backup/data_tools_page.dart';
import 'hover_sidebar.dart';

class _NavItem {
  final IconData icon;
  final String labelKey;
  final Widget Function() pageBuilder;
  final Type pageType;

  const _NavItem({
    required this.icon,
    required this.labelKey,
    required this.pageBuilder,
    required this.pageType,
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
      pageType: EmployeePage,
    ),
    _NavItem(
      icon: Icons.attach_money_outlined,
      labelKey: 'payroll',
      pageBuilder: () => const PayrollPage(),
      pageType: PayrollPage,
    ),
    _NavItem(
      icon: Icons.gavel,
      labelKey: 'rules_settings',
      pageBuilder: () => const RulesPage(),
      pageType: RulesPage,
    ),
    _NavItem(
      icon: Icons.assessment,
      labelKey: 'reports',
      pageBuilder: () => const ReportsPage(),
      pageType: ReportsPage,
    ),
    _NavItem(
      icon: Icons.storage_outlined,
      labelKey: 'data_tools',
      pageBuilder: () => const DataToolsPage(),
      pageType: DataToolsPage,
    ),
    _NavItem(
      icon: Icons.settings,
      labelKey: 'settings',
      pageBuilder: () => const SettingsPage(),
      pageType: SettingsPage,
    ),
  ];

  /// ✅ بيحدد أنهي عنصر في الشريط هو المفعّل حاليًا، بمقارنة نوع الصفحة
  /// المعروضة فعليًا (body) بنوع كل عنصر. قبل كده كانت القيمة ثابتة على
  /// null يعني مفيش تظليل للعنصر النشط خالص.
  int? _currentIndex() {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].pageType == body.runtimeType) return i;
    }
    return null;
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AppScaffold(body: page)),
    );
  }

  void _logout(BuildContext context) {
    // ⚠️ الـ pop() هنا كانت بتتنفذ دايمًا، سواء فيه حاجة تتقفل ولا لأ.
    // في وضع الموبايل (Drawer) بتقفل الـ Drawer بس (local history entry).
    // في وضع الديسكتوب مفيش Drawer أصلاً، فكانت بتقفل الـ Route الوحيد
    // الموجود في الـ stack، وبعدها pushReplacement كان بيلاقي مفيش
    // Route يستبدله → الكراش. الشرط ده بيخلّيها تتنفذ بس لما يكون فيه
    // فعلاً حاجة قابلة للـ pop.
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          homeAfterLogin: const AppScaffold(body: EmployeePage()),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context,
      {bool showMenu = true}) {
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
        // ✅ زرار تبديل الوضع الليلي/النهاري - متاح في الموبايل كمان
        // (مش بس في الشريط الجانبي بتاع الديسكتوب).
        Consumer<ThemeController>(
          builder: (context, themeController, _) {
            return IconButton(
              icon: Icon(themeController.isDark
                  ? Icons.light_mode
                  : Icons.dark_mode),
              tooltip: themeController.isDark
                  ? 'light_mode'.tr()
                  : 'dark_mode'.tr(),
              onPressed: () => themeController.toggle(),
            );
          },
        ),
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
    final selected = _currentIndex();
    return Drawer(
      child: Column(
        children: [
          _buildHeader(),
          for (var i = 0; i < _items.length; i++)
            ListTile(
              leading: Icon(_items[i].icon,
                  color: selected == i ? Colors.green.shade700 : null),
              title: Text(
                _items[i].labelKey.tr(),
                style: TextStyle(
                  color: selected == i ? Colors.green.shade700 : null,
                  fontWeight: selected == i ? FontWeight.bold : null,
                ),
              ),
              selected: selected == i,
              onTap: () => _navigateTo(context, _items[i].pageBuilder()),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title:
                Text('logout'.tr(), style: const TextStyle(color: Colors.red)),
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
          const Icon(Icons.account_balance_wallet,
              size: 40, color: Colors.white),
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

  /// شريط جانبي لوضع الديسكتوب/التابلت - يتمدد تلقائيًا لما الماوس يعمل
  /// hover عليه (بديل NavigationRail الثابت).
  Widget _buildSidebar(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    return Row(
      children: [
        HoverSidebar(
          items: [
            for (final item in _items)
              HoverSidebarItem(icon: item.icon, label: item.labelKey.tr()),
          ],
          selectedIndex: _currentIndex(),
          onSelect: (index) => _navigateTo(context, _items[index].pageBuilder()),
          onLogout: () => _logout(context),
          logoutLabel: 'logout'.tr(),
          isDark: themeController.isDark,
          onToggleTheme: () => themeController.toggle(),
          darkModeLabel: 'dark_mode'.tr(),
          lightModeLabel: 'light_mode'.tr(),
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

    // ============ تابلت/ديسكتوب: شريط جانبي بـ hover ============
    return Scaffold(
      appBar: _buildAppBar(context, showMenu: false),
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(context),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
