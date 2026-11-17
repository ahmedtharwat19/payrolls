// lib/views/shared/app_scaffold.dart

import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:puresip_payrolls/views/attendance/attendance_page.dart';
import 'package:puresip_payrolls/views/dashboard/dashboard_page.dart';
import 'package:puresip_payrolls/views/employees/eos_calculator_page.dart';
import 'package:puresip_payrolls/views/hr/leave_management_page.dart';
import 'package:puresip_payrolls/views/hr/penalties_page.dart';
import 'package:puresip_payrolls/views/reports/compliance_reports_page.dart';
import 'package:puresip_payrolls/views/reports/reports_page.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/permission.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/theme_controller.dart';
import '../employee/employee_page.dart';
import '../payroll/payroll_page.dart';
import '../settings/rules_page.dart';
import '../settings/settings_page.dart';
import '../auth/login_page.dart';
import '../backup/data_tools_page.dart';
import '../auth/change_password_page.dart';
import '../users/users_page.dart';

class _NavItem {
  final IconData icon;
  final String labelKey;
  final Widget Function() pageBuilder;
  final Type pageType;
  final Permission permission;

  const _NavItem({
    required this.icon,
    required this.labelKey,
    required this.pageBuilder,
    required this.pageType,
    required this.permission,
  });
}

class _NavGroup {
  final String titleKey;
  final IconData icon;
  final Color color;
  final List<_NavItem> items;

  const _NavGroup({
    required this.titleKey,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class AppScaffold extends StatefulWidget {
  final Widget body;
  const AppScaffold({super.key, required this.body});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _isHovered = false;

  static final _NavItem _dashboardItem = _NavItem(
    icon: Icons.dashboard_outlined,
    labelKey: 'dashboard',
    pageBuilder: () => const DashboardPage(),
    pageType: DashboardPage,
    permission: Permission.viewReports,
  );

  static final List<_NavGroup> _groups = [
    _NavGroup(
      titleKey: 'nav_group_hr',
      icon: Icons.people_alt,
      color: const Color(0xFF2196F3),
      items: [
        _NavItem(
            icon: Icons.people_alt_outlined,
            labelKey: 'employees',
            pageBuilder: () => const EmployeePage(),
            pageType: EmployeePage,
            permission: Permission.viewEmployees),
        _NavItem(
            icon: Icons.fingerprint,
            labelKey: 'attendance',
            pageBuilder: () => const AttendancePage(),
            pageType: AttendancePage,
            permission: Permission.manageAttendance),
        _NavItem(
            icon: Icons.beach_access,
            labelKey: 'leave_management',
            pageBuilder: () => const LeaveManagementPage(),
            pageType: LeaveManagementPage,
            permission: Permission.manageLeaves),
        _NavItem(
            icon: Icons.warning_amber,
            labelKey: 'penalties',
            pageBuilder: () => const PenaltiesPage(),
            pageType: PenaltiesPage,
            permission: Permission.managePenalties),
        _NavItem(
            icon: Icons.exit_to_app,
            labelKey: 'eos_calculator',
            pageBuilder: () => const EOSCalculatorPage(),
            pageType: EOSCalculatorPage,
            permission: Permission.viewEmployees),
      ],
    ),
    _NavGroup(
      titleKey: 'nav_group_finance',
      icon: Icons.account_balance_wallet,
      color: const Color(0xFF4CAF50),
      items: [
        _NavItem(
            icon: Icons.attach_money_outlined,
            labelKey: 'payroll',
            pageBuilder: () => const PayrollPage(),
            pageType: PayrollPage,
            permission: Permission.viewPayroll),
        _NavItem(
            icon: Icons.assessment,
            labelKey: 'reports',
            pageBuilder: () => const ReportsPage(),
            pageType: ReportsPage,
            permission: Permission.viewReports),
        _NavItem(
            icon: Icons.receipt_long,
            labelKey: 'compliance_reports',
            pageBuilder: () => const ComplianceReportsPage(),
            pageType: ComplianceReportsPage,
            permission: Permission.viewReports),
      ],
    ),
    _NavGroup(
      titleKey: 'nav_group_admin',
      icon: Icons.admin_panel_settings,
      color: const Color(0xFF9C27B0),
      items: [
        _NavItem(
            icon: Icons.gavel,
            labelKey: 'rules_settings',
            pageBuilder: () => const RulesPage(),
            pageType: RulesPage,
            permission: Permission.manageSettings),
        _NavItem(
            icon: Icons.storage_outlined,
            labelKey: 'data_tools',
            pageBuilder: () => const DataToolsPage(),
            pageType: DataToolsPage,
            permission: Permission.manageData),
        _NavItem(
            icon: Icons.settings,
            labelKey: 'settings',
            pageBuilder: () => const SettingsPage(),
            pageType: SettingsPage,
            permission: Permission.manageSettings),
        _NavItem(
            icon: Icons.manage_accounts_outlined,
            labelKey: 'users_management',
            pageBuilder: () => const UsersPage(),
            pageType: UsersPage,
            permission: Permission.manageUsers),
      ],
    ),
  ];

  bool _canShow(Permission p) => context.watch<AuthService>().can(p);
  bool _canShowDashboard() => _canShow(_dashboardItem.permission);

  List<_NavGroup> get _visibleGroups {
    final result = <_NavGroup>[];
    for (final group in _groups) {
      final visible =
          group.items.where((item) => _canShow(item.permission)).toList();
      if (visible.isNotEmpty) {
        result.add(_NavGroup(
            titleKey: group.titleKey,
            icon: group.icon,
            color: group.color,
            items: visible));
      }
    }
    return result;
  }

  List<_NavItem> get _allVisibleItems {
    final items = <_NavItem>[];
    if (_canShowDashboard()) items.add(_dashboardItem);
    for (final group in _visibleGroups) {
      items.addAll(group.items);
    }
    return items;
  }

  int? get _currentIndex {
    final items = _allVisibleItems;
    for (var i = 0; i < items.length; i++) {
      if (items[i].pageType == widget.body.runtimeType) return i;
    }
    return null;
  }

  bool _groupHasSelected(_NavGroup group) {
    return group.items.any((i) => i.pageType == widget.body.runtimeType);
  }

  void _navigateTo(Widget page) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => AppScaffold(body: page)));
  }

  void _logout() {
    if (Navigator.canPop(context)) Navigator.of(context).pop();
    context.read<AuthService>().logout();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => LoginPage(
            homeAfterLogin: const AppScaffold(body: EmployeePage()))));
  }

  // ✅ دالة آمنة لتغيير حالة الـ Hover
  void _setHovered(bool value) {
    Future.microtask(() {
      if (mounted && _isHovered != value) {
        setState(() => _isHovered = value);
      }
    });
  }

  PreferredSizeWidget _buildAppBar({bool showMenu = true}) {
    return AppBar(
      title: Text('payroll_system'.tr()),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: showMenu,
      leading: showMenu
          ? Builder(
              builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer()))
          : null,
      actions: [
        IconButton(
            icon: const Icon(Icons.lock_reset),
            tooltip: 'change_password'.tr(),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),
        Consumer<ThemeController>(
          builder: (context, themeController, _) {
            return IconButton(
              icon: Icon(
                  themeController.isDark ? Icons.light_mode : Icons.dark_mode),
              tooltip:
                  themeController.isDark ? 'light_mode'.tr() : 'dark_mode'.tr(),
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
          itemBuilder: (BuildContext context) => const [
            PopupMenuItem(value: 'ar', child: Text('العربية')),
            PopupMenuItem(value: 'en', child: Text('English')),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet,
              size: 36, color: Colors.white),
          if (_isHovered) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'payroll_system'.tr(),
                style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]
        ],
      ),
    );
  }

  // ==========================================
  // Collapsed Sidebar (70px) - Icons Only
  // ==========================================
  Widget _buildCollapsedSidebar() {
    final theme = Theme.of(context);
    final items = _allVisibleItems;
    final currentIdx = _currentIndex;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (int i = 0; i < items.length; i++)
                    Tooltip(
                      message: items[i].labelKey.tr(),
                      child: InkWell(
                        onTap: () => _navigateTo(items[i].pageBuilder()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Icon(
                            items[i].icon,
                            size: 24,
                            color: currentIdx == i ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Expanded Sidebar (280px) - Full Menu
  // ==========================================
  Widget _buildExpandedSidebar() {
    final theme = Theme.of(context);
    final themeController = context.watch<ThemeController>();

    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: SizedBox(
        width: 280,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (_canShowDashboard()) _buildDashboardTile(),
                  const SizedBox(height: 4),
                  ..._visibleGroups.map((group) => _buildGroupTile(group)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                        themeController.isDark
                            ? Icons.light_mode
                            : Icons.dark_mode,
                        size: 20),
                    tooltip: themeController.isDark
                        ? 'light_mode'.tr()
                        : 'dark_mode'.tr(),
                    onPressed: () => themeController.toggle(),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                    label: Text('logout'.tr(),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Desktop Layout Wrapper
  // ==========================================
  Widget _buildDesktopSidebar() {
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topLeft,
        child: _isHovered ? _buildExpandedSidebar() : _buildCollapsedSidebar(),
      ),
    );
  }

  // ==========================================
  // Builders for Expanded Menu
  // ==========================================
  Widget _buildDashboardTile() {
    final isSelected =
        _allVisibleItems.indexOf(_dashboardItem) == _currentIndex;
    const color = Color(0xFFFF9800);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(_dashboardItem.icon, color: color, size: 20),
          ),
          title: Text(
            _dashboardItem.labelKey.tr(),
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
                color: isSelected ? color : null),
          ),
          selected: isSelected,
          selectedTileColor: color.withValues(alpha: 0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onTap: () => _navigateTo(_dashboardItem.pageBuilder()),
        ),
      ),
    );
  }

  Widget _buildGroupTile(_NavGroup group) {
    final isGroupActive = _groupHasSelected(group);

    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isGroupActive
                  ? Border.all(
                      color: group.color.withValues(alpha: 0.3), width: 1)
                  : null,
            ),
            child: ExpansionTile(
              initiallyExpanded: isGroupActive || group == _groups.first,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: group.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(group.icon, color: group.color, size: 20),
              ),
              title: Text(
                group.titleKey.tr(),
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isGroupActive ? group.color : null),
              ),
              iconColor: group.color,
              collapsedIconColor: Colors.grey,
              children: group.items
                  .map((item) => _buildItemTile(item, group.color))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(_NavItem item, Color groupColor) {
    final isSelected = _allVisibleItems.indexOf(item) == _currentIndex;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 32, right: 16),
        leading:
            Icon(item.icon, size: 20, color: isSelected ? groupColor : null),
        title: Text(
          item.labelKey.tr(),
          style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? groupColor : null),
        ),
        selected: isSelected,
        selectedTileColor: groupColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => _navigateTo(item.pageBuilder()),
      ),
    );
  }

  // ==========================================
  // Drawer (Mobile)
  // ==========================================
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (_canShowDashboard()) _buildDashboardTile(),
                const SizedBox(height: 4),
                ..._visibleGroups.map((group) => _buildGroupTile(group)),
                const SizedBox(height: 8),
                const Divider(indent: 16, endIndent: 16),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: Text('logout'.tr(),
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w600)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      onTap: _logout,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWideScreen;

    if (!wide) {
      return Scaffold(
        drawer: _buildDrawer(),
        appBar: _buildAppBar(),
        body: SafeArea(child: widget.body),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(showMenu: false),
      body: SafeArea(
        child: Row(
          children: [
            _buildDesktopSidebar(),
            Expanded(child: widget.body),
          ],
        ),
      ),
    );
  }
}
