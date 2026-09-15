// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/account_page.dart';
import 'package:nexus/account_service.dart';
import 'package:nexus/main.dart';

void main() {
  testWidgets('shows login as the default page', (WidgetTester tester) async {
    final accountService = AccountService();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountPage(
          accountService: accountService,
          session: null,
          onSignedIn: (_) async {},
          onSignedOut: () async {},
          onContinueAsGuest: () async {},
        ),
      ),
    );

    expect(find.text('Welcome\nback to the lab.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
    accountService.dispose();
  });

  testWidgets('generates a recipe from the starter pantry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RecipeHomePage()));

    expect(find.text('What do you have?'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(
      find.text('Your next meal\nis hiding in plain sight.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Rice'));
    await tester.tap(find.text('Eggs'));
    await tester.ensureVisible(find.text('Spinach'));
    await tester.tap(find.text('Spinach'));
    await tester.pump();

    final generateButton = find.widgetWithText(
      FilledButton,
      'Generate my recipe',
    );
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.text('SMART RECIPE'), findsOneWidget);
    expect(find.text('Green egg rice'), findsOneWidget);
    expect(find.text('Saves food waste'), findsOneWidget);
  });
}
