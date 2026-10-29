import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tikaddis/core/api_service.dart';
import 'package:tikaddis/core/router.dart';
import 'package:tikaddis/providers/auth_provider.dart';
import 'package:tikaddis/widgets/session_verification_banner.dart';

class _VerificationApi extends ApiService {
  final String access;
  _VerificationApi(this.access);
  @override
  Future<bool> renewSession() async => false;
  @override
  Future<Response> login(String username, String password) async => Response(
    requestOptions: RequestOptions(path: '/public/authenticate'),
    data: {
      'token': access,
      'refreshToken': 'new-secret',
      'pid': 'owner',
      'roles': ['INFLUENCER'],
    },
  );
}

void main() {
  testWidgets(
    'Verification preserves an unsaved form before and after password entry',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final access =
          'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'owner-phone', 'exp': 4102444800})))}.signature';
      SharedPreferences.setMockInitialValues({
        'token': access,
        'pid': 'owner',
        'hasSeenOnboarding': true,
      });
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(_VerificationApi(access)),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authProvider.notifier)
          .stream
          .firstWhere((s) => s.initialized);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            builder: (context, child) =>
                SessionVerificationBanner(child: child!),
            home: const Scaffold(
              body: TextField(key: ValueKey('unsaved-channel-title')),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('unsaved-channel-title')),
        'Unsaved TechAddis',
      );
      container.read(authProvider.notifier).requireVerification();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved TechAddis'), findsOneWidget);
      expect(container.read(authProvider).isLoggedIn, isTrue);
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(find.text('Verify your account'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'password');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved TechAddis'), findsOneWidget);
      expect(container.read(authProvider).sessionExpired, isFalse);
      expect(container.read(authProvider).isLoggedIn, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
