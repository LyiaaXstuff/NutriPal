import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/main.dart';

void main() {
  testWidgets('NutriPal opens and advances from splash to onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(const NutriPalApp());
    expect(find.text('NutriPal'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Scan nutrition labels'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
