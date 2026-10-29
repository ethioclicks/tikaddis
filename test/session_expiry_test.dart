import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikaddis/core/api_service.dart';
import 'package:tikaddis/core/browse_error.dart';
import 'package:tikaddis/core/session_token.dart';
import 'package:tikaddis/providers/auth_provider.dart';

String _token(DateTime expiry) {
  final claims = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': 'test',
            'exp': expiry.millisecondsSinceEpoch ~/ 1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'header.$claims.signature';
}

class _Adapter implements HttpClientAdapter {
  int calls = 0;
  int status = 200;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    request = options;
    return ResponseBody.fromString(
      '{"content":[]}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('JWT expiry is checked at its boundary', () {
    final now = DateTime.utc(2026, 10, 24, 12);
    expect(isSessionTokenExpired(_token(now), now: now), isTrue);
    expect(
      isSessionTokenExpired(
        _token(now.add(const Duration(seconds: 1))),
        now: now,
      ),
      isFalse,
    );
    expect(isSessionTokenExpired('unknown', now: now), isFalse);
  });

  test('Restart preserves an expired login and onboarding', () async {
    SharedPreferences.setMockInitialValues({
      'token': _token(DateTime.now().subtract(const Duration(minutes: 1))),
      'pid': 'owner',
      'roles': ['USER'],
      'hasSeenOnboarding': true,
    });
    final auth = AuthNotifier(ApiService());
    addTearDown(auth.dispose);
    final state = await auth.stream.firstWhere((s) => s.initialized);
    expect(state.isLoggedIn, isTrue);
    expect(state.seenOnboarding, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('token'), isTrue);
    expect(prefs.containsKey('roles'), isTrue);
  });

  test('Expired sessions prompt login before making a request', () async {
    SharedPreferences.setMockInitialValues({
      'token': _token(DateTime.now().subtract(const Duration(minutes: 1))),
    });
    var expired = false;
    final api = ApiService(
      onSessionExpired: () async {
        expired = true;
      },
    );
    final adapter = _Adapter();
    api.dio.httpClientAdapter = adapter;
    await expectLater(api.getApprovedAccounts(), throwsA(isA<DioException>()));
    expect(expired, isTrue);
    expect(adapter.calls, 0);
  });

  test(
    'The API provider requests verification without clearing an expired session',
    () async {
      SharedPreferences.setMockInitialValues({
        'token': _token(DateTime.now().subtract(const Duration(minutes: 1))),
        'pid': 'owner',
        'roles': ['USER'],
        'hasSeenOnboarding': true,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(authProvider.notifier)
          .stream
          .firstWhere((state) => state.initialized);
      expect(container.read(authProvider).isLoggedIn, isTrue);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'token',
        _token(DateTime.now().subtract(const Duration(minutes: 1))),
      );
      final api = container.read(apiServiceProvider);
      final adapter = _Adapter();
      api.dio.httpClientAdapter = adapter;
      await expectLater(
        api.getApprovedAccounts(),
        throwsA(isA<DioException>()),
      );
      expect(container.read(authProvider).isLoggedIn, isTrue);
      expect(container.read(authProvider).sessionExpired, isTrue);
      expect(adapter.calls, 0);
    },
  );

  test('An expired stored token does not block a new login', () async {
    SharedPreferences.setMockInitialValues({
      'token': _token(DateTime.now().subtract(const Duration(minutes: 1))),
    });
    final api = ApiService();
    final adapter = _Adapter();
    api.dio.httpClientAdapter = adapter;
    await api.login('test', 'password');
    expect(adapter.calls, 1);
    expect(adapter.request!.headers.containsKey('Authorization'), isFalse);
  });

  test(
    'Permission denial preserves login; failed renewal requests verification',
    () async {
      SharedPreferences.setMockInitialValues({
        'token': _token(DateTime.now().add(const Duration(hours: 1))),
      });
      var expired = false;
      final api = ApiService(
        onSessionExpired: () async {
          expired = true;
        },
      );
      final adapter = _Adapter()..status = 403;
      api.dio.httpClientAdapter = adapter;
      await expectLater(
        api.getApprovedAccounts(),
        throwsA(isA<DioException>()),
      );
      expect(expired, isFalse);
      adapter.status = 401;
      await expectLater(
        api.getApprovedAccounts(),
        throwsA(isA<DioException>()),
      );
      expect(expired, isTrue);
    },
  );

  test('Browse distinguishes connectivity and server errors', () {
    expect(
      browseErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/browse'),
          type: DioExceptionType.connectionError,
        ),
      ),
      contains('internet connection'),
    );
    expect(
      browseErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/browse'),
          response: Response(
            requestOptions: RequestOptions(path: '/browse'),
            statusCode: 503,
          ),
        ),
      ),
      contains('temporarily unavailable'),
    );
  });
}
