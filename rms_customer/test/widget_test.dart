import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_customer/main.dart';

void main() {
  testWidgets('renders the customer sign-in when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(const CustomerApp());
    await tester.pump();
    expect(find.text('Order your favourites'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start ordering'), findsOneWidget);
  });
}
