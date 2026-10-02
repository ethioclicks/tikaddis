// Basic smoke test: the app boots to the animated splash screen,
// then auto-navigates to the walkthrough on first launch.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ethio_promo_mobile/main.dart';

void main() {
  testWidgets('App boots, shows splash, then lands on the walkthrough',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: EthioPromoApp()));
    await tester.pump(const Duration(milliseconds: 1200));

    // Splash shows the brand logo during the intro.
    expect(find.byType(Image), findsOneWidget);

    // Let the bootstrap delay (2.8s) fire so the splash navigates away.
    // Lottie animates continuously, so we pump fixed steps rather than
    // pumpAndSettle (which would never settle).
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));

    // No onboarding flag was set, so we should land on the walkthrough.
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
