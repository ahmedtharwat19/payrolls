import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/tax_service.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  final TaxService _taxService = TaxService();
  List<Map<String, dynamic>> _brackets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _taxService.loadSettings();
    setState(() {
      _brackets = List.from(_taxService.taxBrackets);
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    _taxService.taxBrackets = _brackets;
    await _taxService.saveSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_saved'.tr())),
      );
    }
  }

  Future<void> _resetToEgyptian() async {
    await _taxService.resetToEgyptianBrackets();
    setState(() {
      _brackets = List.from(_taxService.taxBrackets);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reset_to_egyptian'.tr())),
      );
    }
  }

  void _addBracket() {
    setState(() {
      _brackets.add({'from': 0.0, 'to': null, 'rate': 0.0});
    });
  }

  void _removeBracket(int index) {
    setState(() {
      _brackets.removeAt(index);
    });
  }

  void _editBracket(int index) {
    final bracket = _brackets[index];
    final fromCtrl = TextEditingController(text: bracket['from'].toString());
    final toCtrl = TextEditingController(
        text: bracket['to'] == null ? '' : bracket['to'].toString());
    final rateCtrl = TextEditingController(
        text: ((bracket['rate'] as double) * 100).toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('edit_bracket'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fromCtrl,
              decoration: InputDecoration(labelText: 'from_amount'.tr()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            TextField(
              controller: toCtrl,
              decoration: InputDecoration(labelText: 'to_amount_optional'.tr()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            TextField(
              controller: rateCtrl,
              decoration: InputDecoration(labelText: 'percentage'.tr()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              final from = double.tryParse(fromCtrl.text) ?? 0.0;
              final to = double.tryParse(toCtrl.text);
              final rate = (double.tryParse(rateCtrl.text) ?? 0.0) / 100;
              setState(() {
                _brackets[index] = {
                  'from': from,
                  'to': to,
                  'rate': rate,
                };
              });
              Navigator.pop(ctx);
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('tax_brackets_settings'.tr()),
        actions: [
          IconButton(
            onPressed: _resetToEgyptian,
            icon: const Icon(Icons.restore),
            tooltip: 'reset_to_egyptian'.tr(),
          ),
          IconButton(
            onPressed: _saveData,
            icon: const Icon(Icons.save),
            tooltip: 'save'.tr(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: _brackets.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _brackets.removeAt(oldIndex);
                        _brackets.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final bracket = _brackets[index];
                      return ListTile(
                        key: Key('$index'),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${'from'.tr()}: ${bracket['from']}',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${'to'.tr()}: ${bracket['to'] ?? '∞'}',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                // ✅ تم إصلاح التعبير بوضع أقواس واضحة
                                '${((bracket['rate'] as double) * 100).toStringAsFixed(1)}%',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editBracket(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeBracket(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _addBracket,
                    icon: const Icon(Icons.add),
                    label: Text('add_bracket'.tr()),
                  ),
                ),
              ],
            ),
    );
  }
}
