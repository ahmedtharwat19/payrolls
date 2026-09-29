// lib/views/shared/hover_sidebar.dart
//
// ✅ شريط جانبي (Sidebar) لوضع الديسكتوب/الويب: يبان مضغوط (أيقونات بس)
// ولما الماوس يدخل عليه (hover) يتمدد بسلاسة ويبان اسم كل صفحة، مستوحى
// من فكرة "CSS hover sidebar" الشائعة، لكن ده تصميم أصلي بـ Flutter
// مربوط ببيانات التطبيق الفعلية (مش نسخ من أي مصدر خارجي).
import 'package:flutter/material.dart';

class HoverSidebarItem {
  final IconData icon;
  final String label;
  final int? badgeCount;

  const HoverSidebarItem({
    required this.icon,
    required this.label,
    this.badgeCount,
  });
}

class HoverSidebar extends StatefulWidget {
  final List<HoverSidebarItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final String logoutLabel;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final String darkModeLabel;
  final String lightModeLabel;

  const HoverSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    required this.logoutLabel,
    required this.isDark,
    required this.onToggleTheme,
    required this.darkModeLabel,
    required this.lightModeLabel,
  });

  @override
  State<HoverSidebar> createState() => _HoverSidebarState();
}

class _HoverSidebarState extends State<HoverSidebar> {
  bool _hovering = false;

  static const double _collapsedWidth = 72;
  static const double _expandedWidth = 232;
  static const Duration _duration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;
    final expanded = _hovering;
    final accent = Colors.green.shade600;
    final bg = isDarkTheme ? const Color(0xFF1A1A1A) : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOutCubic,
        width: expanded ? _expandedWidth : _collapsedWidth,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(color: bg),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(Icons.account_balance_wallet, size: 30, color: accent),
            const SizedBox(height: 12),
            const Divider(height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return _SidebarTile(
                    icon: item.icon,
                    label: item.label,
                    badgeCount: item.badgeCount,
                    expanded: expanded,
                    selected: widget.selectedIndex == index,
                    accent: accent,
                    onTap: () => widget.onSelect(index),
                  );
                },
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 4),
            _SidebarTile(
              icon: widget.isDark ? Icons.light_mode : Icons.dark_mode,
              label:
                  widget.isDark ? widget.lightModeLabel : widget.darkModeLabel,
              expanded: expanded,
              selected: false,
              accent: accent,
              onTap: widget.onToggleTheme,
            ),
            _SidebarTile(
              icon: Icons.logout,
              label: widget.logoutLabel,
              expanded: expanded,
              selected: false,
              accent: Colors.red,
              iconColor: Colors.red,
              onTap: widget.onLogout,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badgeCount;
  final bool expanded;
  final bool selected;
  final Color accent;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.badgeCount,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? accent : (iconColor ?? Theme.of(context).iconTheme.color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 22, color: color),
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        top: -6,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ClipRect(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: expanded ? 1 : 0,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                          color: color,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
