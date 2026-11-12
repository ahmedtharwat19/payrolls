// lib/views/payroll/historical_payroll_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class HistoricalPayrollPage extends StatefulWidget {
  const HistoricalPayrollPage({super.key});

  @override
  State<HistoricalPayrollPage> createState() => _HistoricalPayrollPageState();
}

class _HistoricalPayrollPageState extends State<HistoricalPayrollPage> {
  DateTime _selectedMonth = DateTime.now();
  final List<Map<String, dynamic>> _payrollHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    // تحميل البيانات التاريخية من قاعدة البيانات
    // مثال:
    _payrollHistory.addAll([
      {'month': 'January 2026', 'total': 150000, 'employees': 10},
      {'month': 'February 2026', 'total': 148500, 'employees': 10},
      {'month': 'March 2026', 'total': 152000, 'employees': 11},
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('historical_payroll'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectMonth(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // عرض الشهر المحدد
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month - 1,
                          );
                          _loadHistory();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month + 1,
                          );
                          _loadHistory();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // الملخص
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryCard('total_employees'.tr(), '10', Icons.people),
                  _buildSummaryCard('total_salary'.tr(), '150,000 EGP', Icons.attach_money),
                  _buildSummaryCard('avg_salary'.tr(), '15,000 EGP', Icons.trending_up),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // جدول التاريخ
          Expanded(
            child: ListView.builder(
              itemCount: _payrollHistory.length,
              itemBuilder: (context, index) {
                final item = _payrollHistory[index];
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(item['month']),
                  subtitle: Text('${item['employees']} employees'),
                  trailing: Text('${item['total']} EGP'),
                  onTap: () {
                    // عرض تفاصيل الشهر
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.green),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
        _loadHistory();
      });
    }
  }
}