// lib/views/reports/compliance_reports_page.dart

import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/compliance_pdf_service.dart';

class ComplianceReportsPage extends StatefulWidget {
  const ComplianceReportsPage({super.key});

  @override
  State<ComplianceReportsPage> createState() => _ComplianceReportsPageState();
}

class _ComplianceReportsPageState extends State<ComplianceReportsPage> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  bool _isGenerating = false;

  Future<void> _generateReport(String type) async {
    setState(() => _isGenerating = true);
    try {
      final isArabic = context.locale.languageCode == 'ar';
      await CompliancePdfService.generateComplianceReport(
        month: _month,
        year: _year,
        isArabic: isArabic,
        reportType: type,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('report_generated_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'report_generation_failed'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('compliance_reports'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _month,
                        decoration: InputDecoration(
                            labelText: 'month'.tr(),
                            border: const OutlineInputBorder()),
                        items: List.generate(12, (i) => i + 1)
                            .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(DateFormat(
                                        'MMMM', context.locale.languageCode)
                                    .format(DateTime(2000, m)))))
                            .toList(),
                        onChanged: (val) => setState(() => _month = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _year,
                        decoration: InputDecoration(
                            labelText: 'year'.tr(),
                            border: const OutlineInputBorder()),
                        items:
                            List.generate(5, (i) => DateTime.now().year - 2 + i)
                                .map((y) => DropdownMenuItem(
                                    value: y, child: Text(y.toString())))
                                .toList(),
                        onChanged: (val) => setState(() => _year = val!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isGenerating)
              const CircularProgressIndicator()
            else ...[
              // تقرير الضرائب
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child:
                        const Icon(Icons.account_balance, color: Colors.red)),
                title: Text('tax_return_form'.tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('tax_return_form_desc'.tr()),
                trailing: const Icon(Icons.picture_as_pdf),
                onTap: () => _generateReport('tax'),
              ),
              const Divider(),
              // تقرير التأمينات
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.health_and_safety,
                        color: Colors.blue)),
                title: Text('insurance_statement'.tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('insurance_statement_desc'.tr()),
                trailing: const Icon(Icons.picture_as_pdf),
                onTap: () => _generateReport('insurance'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
