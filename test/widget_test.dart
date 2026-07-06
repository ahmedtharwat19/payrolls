// test/widget_test.dart
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puresip_payrolls/main.dart';
import 'package:puresip_payrolls/services/tax_service.dart';
import 'package:puresip_payrolls/services/insurance_service.dart';
import 'package:puresip_payrolls/core/auth/auth_service.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // ✅ إنشاء الخدمات المطلوبة للاختبار
    final authService = AuthService();
    final taxService = TaxService();
    final insuranceService = InsuranceService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MyApp(
        authService: authService,
        taxService: taxService,
        insuranceService: insuranceService,
      ),
    );

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
