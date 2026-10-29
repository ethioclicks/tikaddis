import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tikaddis/core/api_service.dart';
import 'package:tikaddis/core/notification_stream.dart';
import 'package:tikaddis/core/theme.dart';
import 'package:tikaddis/models/notification_models.dart';
import 'package:tikaddis/providers/auth_provider.dart';
import 'package:tikaddis/providers/notification_provider.dart';
import 'package:tikaddis/screens/notifications/notifications_screen.dart';

Map<String, dynamic> item(
  int id, {
  String category = 'PROMOTIONS',
  String resource = 'PROMOTION',
}) => {
  'id': id,
  'type': 'PROMOTION_SUBMITTED',
  'category': category,
  'title': 'Real update $id',
  'body': 'Request received',
  'resourceType': resource,
  'resourceId': 'request-$id',
  'createdAt': '2026-10-28T12:00:00Z',
  'readAt': null,
  'archivedAt': null,
};

class _NotificationsApi extends ApiService {
  final rows = <Map<String, dynamic>>[];
  NotificationSettings settings = const NotificationSettings();
  final streams = <StreamController<Uint8List>>[];
  int revision = 0;
  int listCalls = 0;
  bool fail = false;
  bool failMutation = false;
  Response response(dynamic data) => Response(
    requestOptions: RequestOptions(path: '/test'),
    data: data,
  );
  @override
  Future<Response> getNotifications({
    String filter = 'ALL',
    int page = 0,
    int size = 20,
  }) async {
    listCalls++;
    if (fail) throw StateError('Offline');
    final matching =
        rows
            .where(
              (n) => filter == 'ARCHIVED'
                  ? n['archivedAt'] != null
                  : n['archivedAt'] == null &&
                        (filter != 'UNREAD' || n['readAt'] == null),
            )
            .toList()
          ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    return response({
      'content': matching.skip(page * size).take(size).toList(),
      'last': (page + 1) * size >= matching.length,
    });
  }

  @override
  Future<Response> getNotificationSnapshot() async => response({
    'revision': revision,
    'unreadCount': rows
        .where((n) => n['readAt'] == null && n['archivedAt'] == null)
        .length,
    'preferences': settings.toJson(),
  });
  @override
  Future<Response<ResponseBody>> openNotificationStream(
    CancelToken cancel,
  ) async {
    final stream = StreamController<Uint8List>();
    streams.add(stream);
    unawaited(
      cancel.whenCancel.then((_) {
        if (!stream.isClosed) unawaited(stream.close());
      }),
    );
    return Response(
      requestOptions: RequestOptions(path: '/stream'),
      data: ResponseBody(stream.stream, 200),
    );
  }

  @override
  Future<Response> setNotificationRead(int id, bool value) async {
    if (failMutation) throw StateError('Offline');
    rows.firstWhere((n) => n['id'] == id)['readAt'] = value
        ? DateTime.now().toUtc().toIso8601String()
        : null;
    revision++;
    return response({});
  }

  @override
  Future<Response> setNotificationArchived(int id, bool value) async {
    rows.firstWhere((n) => n['id'] == id)['archivedAt'] = value
        ? DateTime.now().toUtc().toIso8601String()
        : null;
    revision++;
    return response({});
  }

  @override
  Future<Response> markAllNotificationsRead() async {
    for (final n in rows) {
      if (n['archivedAt'] == null) {
        n['readAt'] = DateTime.now().toUtc().toIso8601String();
      }
    }
    revision++;
    return response({});
  }

  @override
  Future<Response> saveNotificationPreferences(
    Map<String, dynamic> preferences,
  ) async {
    settings = NotificationSettings.fromJson(preferences);
    revision++;
    return response(preferences);
  }

  void signal() => streams.last.add(
    Uint8List.fromList(
      utf8.encode('event:inbox\ndata:{"revision":$revision}\n\n'),
    ),
  );
}

class _Auth extends AuthNotifier {
  _Auth(super.api);
  void identity(String id) => state = AuthState(
    token: 'token-$id',
    pid: id,
    initialized: true,
    seenOnboarding: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'SSE decoder handles split UTF-8, comments, invalid frames and reconnect events',
    () async {
      final bytes = utf8.encode(
        ':keepalive\r\nevent:inbox\r\ndata:{"title":"ሰላም","unreadCount":2}\r\n\r\n'
        'event:other\ndata:{"ignored":true}\n\nevent:inbox\ndata:bad-json\n\nevent:inbox\ndata:{"unreadCount":3}\n\n',
      );
      final frames = await decodeNotificationStream(
        Stream.fromIterable(bytes.map((b) => [b])),
      ).toList();
      expect(frames.length, 2);
      expect(frames.first['title'], 'ሰላም');
      expect(frames.last['unreadCount'], 3);
    },
  );
  test(
    'Notification navigation uses safe role-aware routes and exact promotion IDs',
    () {
      final n = InboxNotification.fromJson(item(1));
      expect(
        notificationRoute(n, isAdmin: false, isInfluencer: true),
        '/promotion/request-1',
      );
      final incoming = InboxNotification.fromJson(
        item(2, resource: 'CREATOR_REQUEST'),
      );
      expect(
        notificationRoute(incoming, isAdmin: false, isInfluencer: true),
        '/promotion/request-2?incoming=1',
      );
      expect(
        notificationRoute(incoming, isAdmin: false, isInfluencer: false),
        isNull,
      );
      final forged = InboxNotification.fromJson({
        ...item(3),
        'resourceType': 'https://evil.example',
      });
      expect(
        notificationRoute(forged, isAdmin: false, isInfluencer: false),
        isNull,
      );
    },
  );
  test(
    'Read, unread, archive and preferences reflect saved server state',
    () async {
      final api = _NotificationsApi()..rows.add(item(1));
      final controller = NotificationInboxController(api);
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.state.unreadCount, 1);
      expect(controller.state.alert, isNull);
      final n = controller.state.items.single;
      await controller.markRead(n, true);
      expect(controller.state.unreadCount, 0);
      await controller.markRead(n, false);
      expect(controller.state.unreadCount, 1);
      await controller.archive(n, true);
      expect(controller.state.items, isEmpty);
      expect(controller.state.unreadCount, 0);
      await controller.changeFilter('ARCHIVED');
      expect(controller.state.items.length, 1);
      await controller.archive(n, false);
      expect(controller.state.items, isEmpty);
      await controller.saveSettings(
        const NotificationSettings(liveAlerts: false),
      );
      expect(controller.state.preferences.liveAlerts, false);
      await controller.changeFilter('ALL');
      expect(controller.state.items.single.id, 1);
    },
  );
  test('Failed server mutations preserve unread state', () async {
    final api = _NotificationsApi()..rows.add(item(1));
    final controller = NotificationInboxController(api);
    addTearDown(controller.dispose);
    await controller.refresh();
    api.failMutation = true;
    await expectLater(
      controller.markRead(controller.state.items.single, true),
      throwsStateError,
    );
    expect(controller.state.unreadCount, 1);
    expect(controller.state.busy, false);
  });
  testWidgets(
    'Live events refresh inbox once per event without repeated alerts on resync',
    (tester) async {
      final api = _NotificationsApi()..rows.add(item(1));
      final controller = NotificationInboxController(api);
      await controller.refresh();
      controller.resume();
      await tester.pump();
      api.rows.add(item(2));
      api.revision++;
      api.signal();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(controller.state.unreadCount, 2);
      expect(controller.state.alert?.item.id, 2);
      final sequence = controller.state.alert!.sequence;
      api.signal();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(controller.state.alert!.sequence, sequence);
      await controller.saveSettings(
        const NotificationSettings(promotionAlerts: false),
      );
      api.rows.add(item(3));
      api.revision++;
      api.signal();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(controller.state.unreadCount, 3);
      expect(controller.state.alert!.sequence, sequence);
      controller.dispose();
      await tester.pump();
    },
  );
  testWidgets(
    'Healthy heartbeats do not poll the inbox and bursts are coalesced',
    (tester) async {
      final api = _NotificationsApi()..rows.add(item(1));
      final controller = NotificationInboxController(api);
      controller.resume();
      await tester.pump();
      api.signal();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      final baseline = api.listCalls;
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 15));
        api.streams.last.add(
          Uint8List.fromList(
            utf8.encode('event:heartbeat\ndata:{"kind":"heartbeat"}\n\n'),
          ),
        );
        await tester.pump();
      }
      expect(api.listCalls, baseline);
      api.rows.add(item(2));
      api.revision++;
      for (int i = 0; i < 100; i++) {
        api.signal();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(api.listCalls, baseline + 1);
      expect(controller.state.unreadCount, 2);
      controller.dispose();
      await tester.pump();
    },
  );

  testWidgets('Stream reconnects after disconnect and stops when paused', (
    tester,
  ) async {
    final api = _NotificationsApi();
    final controller = NotificationInboxController(api);
    controller.resume();
    await tester.pump();
    expect(api.streams.length, 1);
    unawaited(api.streams.single.close());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(api.streams.length, 2);
    controller.pause();
    await tester.pump(const Duration(minutes: 1));
    expect(api.streams.length, 2);
    controller.dispose();
  });
  test(
    'Changing the authenticated identity disposes the previous inbox',
    () async {
      final api = _NotificationsApi()..rows.add(item(1));
      final auth = _Auth(api);
      await Future<void>.delayed(Duration.zero);
      auth.identity('first');
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          authProvider.overrideWith((ref) => auth),
        ],
      );
      final subscription = container.listen(
        notificationInboxProvider,
        (_, next) {},
      );
      final first = container.read(notificationInboxProvider.notifier);
      await first.refresh();
      expect(first.state.unreadCount, 1);
      auth.identity('second');
      final second = container.read(notificationInboxProvider.notifier);
      expect(identical(first, second), false);
      expect(first.mounted, false);
      expect(second.state.unreadCount, 0);
      subscription.close();
      container.dispose();
    },
  );
  testWidgets(
    'Inbox shows real empty state, saved updates and read management',
    (tester) async {
      final api = _NotificationsApi();
      final controller = NotificationInboxController(api);
      await controller.refresh();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationInboxProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.text('Promotion approved'), findsNothing);
      api.rows.add(item(1));
      api.revision++;
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Real update 1'), findsOneWidget);
      expect(find.text('1 unread'), findsOneWidget);
      await tester.tap(find.byTooltip('Mark all read'));
      await tester.pumpAndSettle();
      expect(find.text('0 unread'), findsOneWidget);
      await tester.tap(find.byTooltip('Notification preferences'));
      await tester.pumpAndSettle();
      expect(find.text('Live in-app alerts'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Live in-app alerts'),
      );
      await tester.pumpAndSettle();
      expect(api.settings.liveAlerts, false);
    },
  );
}
