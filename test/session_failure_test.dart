import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikaddis/core/api_service.dart';

class _SessionAdapter implements HttpClientAdapter {
  final int snapshotStatus;
  final calls = <String>[];
  _SessionAdapter(this.snapshotStatus);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.path);
    final status = options.path.endsWith('/snapshot') ? snapshotStatus : 401;
    return ResponseBody.fromString(
      '{}',
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
  for (final status in [200, 401, 500]) {
    test('resource 401 with session check $status', () async {
      var logouts = 0;
      final api = ApiService(
        onSessionExpired: () async {
          logouts++;
        },
      );
      final adapter = _SessionAdapter(status);
      api.dio.httpClientAdapter = adapter;
      await expectLater(
        api.getAccountDetail('channel'),
        throwsA(isA<DioException>()),
      );
      expect(logouts, status == 401 ? 1 : 0);
      expect(adapter.calls, [
        '/influencer/get-influencer-account/channel',
        '/account/notifications/snapshot',
      ]);
      api.dio.close();
    });
  }
}
