import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/app_database.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final _nameArCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _addressArCtrl = TextEditingController();
  final _addressEnCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('app_meta');
    final Map<String, String> meta = {};
    for (var r in rows) {
      meta[r['key'] as String] = r['value'] as String;
    }

    setState(() {
      _nameArCtrl.text = meta['company_name_ar'] ?? '';
      _nameEnCtrl.text = meta['company_name_en'] ?? '';
      _addressArCtrl.text = meta['company_address_ar'] ?? '';
      _addressEnCtrl.text = meta['company_address_en'] ?? '';
      _phoneCtrl.text = meta['company_phone'] ?? '';
      _taxCtrl.text = meta['company_tax'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final db = await AppDatabase.instance.database;
    final data = {
      'company_name_ar': _nameArCtrl.text.trim(),
      'company_name_en': _nameEnCtrl.text.trim(),
      'company_address_ar': _addressArCtrl.text.trim(),
      'company_address_en': _addressEnCtrl.text.trim(),
      'company_phone': _phoneCtrl.text.trim(),
      'company_tax': _taxCtrl.text.trim(),
    };

    for (var entry in data.entries) {
      await db.insert(
        'app_meta',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ بيانات الشركة بنجاح')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بيانات الشركة'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text('البيانات باللغة العربية',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameArCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم الشركة (عربي)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressArCtrl,
                  decoration: const InputDecoration(
                      labelText: 'العنوان (عربي)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const Text('البيانات باللغة الإنجليزية',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameEnCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم الشركة (إنجليزي)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressEnCtrl,
                  decoration: const InputDecoration(
                      labelText: 'العنوان (إنجليزي)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const Text('بيانات مشتركة',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _taxCtrl,
                  decoration: const InputDecoration(
                      labelText: 'الرقم الضريبي / السجل التجاري',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ البيانات',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }
}
