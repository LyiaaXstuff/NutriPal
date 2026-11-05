import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/main.dart';

void main() {
  testWidgets('NutriPal app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const NutriPalApp());

    expect(find.text('Welcome to NutriPal'), findsOneWidget);
  });
}