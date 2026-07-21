import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_waiter/main.dart';

void main() {
  testWidgets('renders the login screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(const WaiterApp());
    await tester.pump();
    // Signed-out launch lands on the waiter sign-in screen.
    expect(find.text('Sign in to take orders'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
