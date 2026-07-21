import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_manager/main.dart';

void main() {
  testWidgets('renders the manager sign-in when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(const ManagerApp());
    await tester.pump();
    expect(find.text('Live sales, kitchen & covers'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
