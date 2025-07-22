// lib/views/settings/rules_page.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RulesPage extends StatefulWidget {
  const RulesPage({super.key});

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  final TextEditingController overtimeRateController = TextEditingController();
  final TextEditingController latePenaltyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    overtimeRateController.text = (prefs.getDouble('overtimeRate') ?? 20).toString();
    latePenaltyController.text = (prefs.getDouble('latePenalty') ?? 1).toString();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('overtimeRate', double.tryParse(overtimeRateController.text) ?? 20);
    await prefs.setDouble('latePenalty', double.tryParse(latePenaltyController.text) ?? 1);

    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings_saved'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('rules_settings'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('overtime_rate'.tr()),
            TextField(
              controller: overtimeRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'eg: 20'),
            ),
            const SizedBox(height: 20),
            Text('late_penalty'.tr()),
            TextField(
              controller: latePenaltyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'eg: 1 (day deduction per 60 mins)'),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: saveSettings,
                child: Text('save'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
