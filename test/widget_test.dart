import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // This is a basic test to ensure the app starts without crashing.
    await tester.pumpWidget(const MyApp());

    // Verify that the main screen is rendered.
    // Let's check for the BottomNavigationBar, which is a core part of the UI.
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Verify that the initial tab is 'Home'.
    expect(find.text('Home'), findsOneWidget);
  });
}
