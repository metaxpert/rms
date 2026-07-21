import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_driver/main.dart';

void main() {
  testWidgets('renders the driver sign-in when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(const DriverApp());
    await tester.pump();
    expect(find.text('Your delivery runs'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
