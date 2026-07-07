import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../database/payment_storage.dart';
import '../../models/payroll_record_model.dart';
import '../../models/salary_payment_model.dart';

/// Dialog لتسجيل دفعة صرف على راتب موظف - بيدعم:
/// - دفعة جزئية (نص الراتب مثلاً)
/// - تقسيم المبلغ نفسه كاش/بنك
///
/// استخدمه كده من أي شاشة عندك فيها PayrollRecord:
// ignore: unintended_html_in_doc_comment
///   final saved = await showDialog<bool>(
///     context: context,
///     builder: (_) => RecordPaymentDialog(record: record, remainingBalance: remaining),
///   );
class RecordPaymentDialog extends StatefulWidget {
  final PayrollRecord record;
  final double remainingBalance;
  const RecordPaymentDialog({super.key, required this.record, required this.remainingBalance});

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  late final TextEditingController _cashCtrl;
  late final TextEditingController _bankCtrl;
  final _notesCtrl = TextEditingController();
  final _paymentStorage = PaymentStorage();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // افتراضيًا نقترح صرف المتبقي بالكامل كاش - المستخدم يقدر يعدّل ويقسم
    _cashCtrl = TextEditingController(text: widget.remainingBalance.toStringAsFixed(2));
    _bankCtrl = TextEditingController(text: '0');
  }

  double get _cash => double.tryParse(_cashCtrl.text) ?? 0;
  double get _bank => double.tryParse(_bankCtrl.text) ?? 0;
  double get _total => _cash + _bank;

  Future<void> _save() async {
    if (_total <= 0) return;
    setState(() => _saving = true);

    await _paymentStorage.recordPayment(SalaryPayment(
      id: const Uuid().v4(),
      payrollRecordId: widget.record.id,
      cashAmount: _cash,
      bankAmount: _bank,
      paymentDate: DateTime.now(),
      notes: _notesCtrl.text,
    ));

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final overpaying = _total > widget.remainingBalance + 0.01;

    return AlertDialog(
      title: Text('record_payment'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'remaining_balance'.tr()}: ${widget.remainingBalance.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: _cashCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'cash_amount'.tr()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bankCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'bank_amount'.tr()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: 'notes'.tr()),
            ),
            const SizedBox(height: 12),
            Text('${'total_payment'.tr()}: ${_total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (overpaying)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('payment_exceeds_balance'.tr(),
                    style: const TextStyle(color: Colors.orange)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: (_total <= 0 || _saving) ? null : _save,
          child: _saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('save'.tr()),
        ),
      ],
    );
  }
}
