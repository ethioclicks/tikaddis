// Smoke test: the app boots to the splash, then lands on the launch screen
// on first launch.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tikaddis/main.dart';

void main() {
  testWidgets('App boots, shows splash, then lands on the launch screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: EthioPromoApp()));

    // Splash shows the brand logo and name.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Tikaddis'), findsOneWidget);

    // Let startup state restore so the router leaves the splash.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));

    // No onboarding flag was set, so we should land on the launch screen.
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
