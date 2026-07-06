// lib/views/reports/reports_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {

  final List<Map<String, dynamic>> _reports = [
    {'id': 'payroll_summary', 'title': 'Payroll Summary', 'icon': Icons.summarize},
    {'id': 'salary_slip', 'title': 'Salary Slips', 'icon': Icons.receipt_long},
    {'id': 'tax_report', 'title': 'Tax Report', 'icon': Icons.request_quote},
    {'id': 'insurance_report', 'title': 'Insurance Report', 'icon': Icons.health_and_safety},
    {'id': 'attendance_report', 'title': 'Attendance Report', 'icon': Icons.calendar_today},
    {'id': 'bank_transfer', 'title': 'Bank Transfer', 'icon': Icons.account_balance},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reports'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportReport,
            tooltip: 'export_pdf'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.table_view),
            onPressed: _exportExcel,
            tooltip: 'export_excel'.tr(),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return Card(
            child: InkWell(
              onTap: () => _openReport(report['id']),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(report['icon'], size: 48, color: Colors.green),
                    const SizedBox(height: 12),
                    Text(
                      report['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⏳ جاري تصدير التقرير...')),
    );
  }

  void _exportExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⏳ جاري تصدير Excel...')),
    );
  }

  void _openReport(String reportId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📊 فتح التقرير: $reportId')),
    );
  }
}