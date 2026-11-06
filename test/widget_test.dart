import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/main.dart';

void main() {
  testWidgets('NutriPal app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const NutriPalApp());

    // Splash screen.
    expect(find.text('NutriPal'), findsOneWidget);
    expect(
      find.text('Scan it. Understand it.\nChoose better.', findRichText: true),
      findsOneWidget,
    );

    // Leave the splash and let its 4-second navigation timer run out,
    // otherwise the test fails with "A Timer is still pending".
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
