import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikaddis/core/api_service.dart';
import 'package:tikaddis/core/session_credentials.dart';
import 'package:tikaddis/providers/auth_provider.dart';

class _Credentials extends SessionCredentials {
  String? value = 'device-secret';
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    value = next;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _FailedLoginApi extends ApiService {
  _FailedLoginApi() : super(credentials: _Credentials());
  @override
  Future<bool> renewSession() async => false;
  @override
  Future<Response> login(String userName, String password) async {
    final request = RequestOptions(path: '/public/authenticate');
    throw DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 401),
    );
  }
}

String token(int expiry) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'owner', 'exp': expiry})))}.signature';

class _SessionAdapter implements HttpClientAdapter {
  final int renewalStatus;
  final int resourceStatus;
  Completer<void>? gate;
  final calls = <String>[];
  _SessionAdapter(this.renewalStatus, {this.resourceStatus = 401, this.gate});
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.path);
    final renewal =
        options.path.endsWith('/refresh') || options.path == '/account/session';
    if (renewal && gate != null) await gate!.future;
    final status = renewal ? renewalStatus : resourceStatus;
    return ResponseBody.fromString(
      renewal && status == 200
          ? jsonEncode({
              'token': token(4102444800),
              'pid': 'owner-id',
              'roles': ['INFLUENCER'],
              'refreshToken': 'renewed-secret',
            })
          : '{}',
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'token': 'test-token'}));

  test('failed password entry cannot clear an existing login', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pid', 'owner-id');
    final api = _FailedLoginApi();
    final auth = AuthNotifier(api);
    await auth.stream.firstWhere((s) => s.initialized);
    await expectLater(
      auth.login('owner', 'wrong-password'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.state.isLoggedIn, isTrue);
    expect(auth.state.token, 'test-token');
    expect(prefs.getString('token'), 'test-token');
    auth.dispose();
    api.dio.close();
  });

  test('intentional sign-out clears the identity and credentials', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pid', 'owner-id');
    final credentials = _Credentials();
    final api = ApiService(credentials: credentials);
    api.dio.httpClientAdapter = _SessionAdapter(200, resourceStatus: 204);
    final auth = AuthNotifier(api);
    await auth.stream.firstWhere((s) => s.initialized);
    await auth.logout();
    expect(auth.state.isLoggedIn, isFalse);
    expect(prefs.getString('token'), isNull);
    expect(credentials.value, isNull);
    auth.dispose();
    api.dio.close();
  });
  for (final status in [200, 401, 500]) {
    test(
      'resource failure never clears token; renewal status $status',
      () async {
        var verificationPrompts = 0;
        final api = ApiService(
          credentials: _Credentials(),
          onSessionExpired: () async {
            verificationPrompts++;
          },
        );
        final adapter = _SessionAdapter(status);
        api.dio.httpClientAdapter = adapter;
        await expectLater(
          api.getAccountDetail('channel'),
          throwsA(isA<DioException>()),
        );
        expect(verificationPrompts, status == 401 ? 1 : 0);
        expect(
          (await SharedPreferences.getInstance()).getString('token'),
          isNotNull,
        );
        expect(adapter.calls, [
          '/influencer/get-influencer-account/channel',
          '/public/session/refresh',
        ]);
        api.dio.close();
      },
    );
  }

  test(
    'expired access renews before sending mutation, without duplicate writes',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token(1));
      final api = ApiService(credentials: _Credentials());
      final adapter = _SessionAdapter(200, resourceStatus: 201);
      api.dio.httpClientAdapter = adapter;
      await api.updateInfluencerAccount('owner-id', {'title': 'Updated'});
      expect(adapter.calls, [
        '/public/session/refresh',
        '/influencer/update-influencer-account',
      ]);
      api.dio.close();
    },
  );

  test('concurrent expiry performs one renewal', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token(1));
    final gate = Completer<void>();
    final adapter = _SessionAdapter(200, resourceStatus: 200, gate: gate);
    final api = ApiService(credentials: _Credentials());
    api.dio.httpClientAdapter = adapter;
    final requests = List.generate(8, (_) => api.getAccountDetail('channel'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    await Future.wait(requests);
    expect(adapter.calls.where((p) => p.endsWith('/refresh')).length, 1);
    api.dio.close();
  });

  test('logout wins over an in-flight renewal', () async {
    final credentials = _Credentials();
    final gate = Completer<void>();
    final adapter = _SessionAdapter(200, resourceStatus: 204, gate: gate);
    final api = ApiService(credentials: credentials);
    api.dio.httpClientAdapter = adapter;
    final renewal = api.renewSession();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await api.clearSession();
    gate.complete();
    expect(await renewal, isFalse);
    expect((await SharedPreferences.getInstance()).getString('token'), isNull);
    expect(credentials.value, isNull);
    api.dio.close();
  });

  test(
    'legacy expired startup retains login and requests verification',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token(1));
      await prefs.setString('pid', 'owner-id');
      final credentials = _Credentials()..value = null;
      late AuthNotifier auth;
      final api = ApiService(
        credentials: credentials,
        onSessionExpired: () async => auth.requireVerification(),
      );
      auth = AuthNotifier(api);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(auth.state.isLoggedIn, isTrue);
      expect(auth.state.sessionExpired, isTrue);
      expect(prefs.getString('token'), isNotNull);
      auth.dispose();
      api.dio.close();
    },
  );
}
