// lib/views/dashboard/dashboard_page.dart

import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/compliance_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _service = ComplianceService();
  bool _isLoading = true;

  final int _month = DateTime.now().month;
  final int _year = DateTime.now().year;

  Map<String, dynamic> _stats = {};
  Map<String, int> _deptDistribution = {};
  Map<String, double> _paymentDistribution = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final stats = await _service.getMonthlyComplianceStats(
        month: _month,
        year: _year,
      );
      final dept = await _service.getDepartmentDistribution();
      final pay = await _service.getPaymentMethodDistribution(
        month: _month,
        year: _year,
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _deptDistribution = dept;
          _paymentDistribution = pay;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('dashboard'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'refresh'.tr(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  _buildCharts(),
                ],
              ),
            ),
    );
  }

  // ==========================================
  // Stats Grid (4 Cards)
  // ==========================================
  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ✅ تحديد عدد الأعمدة وارتفاع الكارت بناءً على عرض الشاشة
        int crossAxisCount;
        double mainAxisExtent;

        if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
          mainAxisExtent = 120; // ارتفاع كافي بدون Overflow
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
          mainAxisExtent = 130;
        } else {
          crossAxisCount = 1;
          mainAxisExtent = 110;
        }

        return GridView.builder(
          itemCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: mainAxisExtent, // ✅ ارتفاع ثابت لكل كارت
          ),
          itemBuilder: (context, index) {
            final cards = [
              _buildStatCard(
                title: 'total_employees'.tr(),
                value: '${_stats['employeeCount'] ?? 0}',
                icon: Icons.people,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: 'total_salaries'.tr(),
                value: '${(_stats['totalGross'] ?? 0).toStringAsFixed(0)}',
                icon: Icons.attach_money,
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'total_taxes'.tr(),
                value: '${(_stats['totalTax'] ?? 0).toStringAsFixed(0)}',
                icon: Icons.account_balance,
                color: Colors.red,
              ),
              _buildStatCard(
                title: 'total_insurance'.tr(),
                value:
                    '${(_stats['totalEmployeeInsurance'] ?? 0).toStringAsFixed(0)}',
                icon: Icons.health_and_safety,
                color: Colors.orange,
              ),
            ];
            return cards[index];
          },
        );
      },
    );
  }

  // ==========================================
  // Stat Card (✅ Fixed - no Spacer)
  // ==========================================
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.2), width: 1),
      ),
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // ✅ spaceBetween بدل Spacer (لأن Spacer بياخد باقي المساحة وممكن يفيض)
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_upward,
                  color: Colors.green.withValues(alpha: 0.5),
                  size: 14,
                ),
              ],
            ),
            // ✅ Text column بيتاخد ارتفاعه الطبيعي (mainAxisSize.min)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Charts Section (Responsive)
  // ==========================================
  Widget _buildCharts() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final pie = _buildPieChartCard(isDark);
        final bar = _buildBarChartCard(isDark);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: pie),
              const SizedBox(width: 16),
              Expanded(child: bar),
            ],
          );
        }
        return Column(
          children: [
            pie,
            const SizedBox(height: 16),
            bar,
          ],
        );
      },
    );
  }

  // ==========================================
  // Pie Chart Card
  // ==========================================
  Widget _buildPieChartCard(bool isDark) {
    final theme = Theme.of(context);
    final cash = _paymentDistribution['cash'] ?? 0;
    final bank = _paymentDistribution['bank'] ?? 0;
    final total = cash + bank;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'payment_distribution'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: total == 0
                  ? Center(
                      child: Text(
                        'no_data'.tr(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 55,
                        sections: [
                          if (cash > 0)
                            PieChartSectionData(
                              value: cash,
                              title:
                                  '${((cash / total) * 100).toStringAsFixed(1)}%',
                              color: Colors.green,
                              radius: 45,
                              titleStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (bank > 0)
                            PieChartSectionData(
                              value: bank,
                              title:
                                  '${((bank / total) * 100).toStringAsFixed(1)}%',
                              color: Colors.blue,
                              radius: 45,
                              titleStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('cash'.tr(), cash, Colors.green),
                _buildLegendItem('bank'.tr(), bank, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Bar Chart Card
  // ==========================================
  Widget _buildBarChartCard(bool isDark) {
    final theme = Theme.of(context);

    final sortedEntries = _deptDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    double maxVal = 0;
    for (var e in sortedEntries) {
      if (e.value.toDouble() > maxVal) maxVal = e.value.toDouble();
    }
    final maxY = maxVal > 0 ? (maxVal * 1.2).ceilToDouble() : 10.0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'department_distribution'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: sortedEntries.isEmpty
                  ? Center(
                      child: Text(
                        'no_data'.tr(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        minY: 0,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: (maxY / 4).ceilToDouble(),
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: theme.dividerColor.withValues(alpha: 0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 &&
                                    value.toInt() < sortedEntries.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      sortedEntries[value.toInt()].key,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: (maxY / 4).ceilToDouble(),
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        barGroups: List.generate(sortedEntries.length, (index) {
                          final entry = sortedEntries[index];
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.toDouble(),
                                color: isDark
                                    ? Colors.lightBlueAccent
                                    : Colors.blue,
                                width: 24,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: theme.dividerColor
                                      .withValues(alpha: 0.08),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '${value.toStringAsFixed(0)} EGP',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }
}
