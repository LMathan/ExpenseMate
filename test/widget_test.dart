import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:espenseai/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: ExpenseMateApp(),
      ),
    );

    // Verify that the logo name 'ExpenseMate' is visible on startup
    expect(find.text('ExpenseMate'), findsOneWidget);

    // Unmount the app to dispose the controllers and set mounted to false
    await tester.pumpWidget(const SizedBox());

    // Settle the splash screen's 3-second redirect timer safely
    await tester.pump(const Duration(seconds: 4));
  });
}
