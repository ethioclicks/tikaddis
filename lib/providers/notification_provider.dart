import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';
import '../core/notification_stream.dart';
import '../models/notification_models.dart';
import 'auth_provider.dart';
import 'data_providers.dart';

class NotificationAlert {
  const NotificationAlert(this.sequence, this.item, this.count);
  final int sequence, count;
  final InboxNotification item;
}

class NotificationInboxState {
  const NotificationInboxState({
    this.items = const [],
    this.unreadCount = 0,
    this.filter = 'ALL',
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.busy = false,
    this.connected = false,
    this.error,
    this.preferences = const NotificationSettings(),
    this.alert,
  });
  final List<InboxNotification> items;
  final int unreadCount;
  final String filter;
  final bool loading, loadingMore, hasMore, busy, connected;
  final String? error;
  final NotificationSettings preferences;
  final NotificationAlert? alert;
  NotificationInboxState copyWith({
    List<InboxNotification>? items,
    int? unreadCount,
    String? filter,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? busy,
    bool? connected,
    String? error,
    NotificationSettings? preferences,
    NotificationAlert? alert,
  }) => NotificationInboxState(
    items: items ?? this.items,
    unreadCount: unreadCount ?? this.unreadCount,
    filter: filter ?? this.filter,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    busy: busy ?? this.busy,
    connected: connected ?? this.connected,
    error: error,
    preferences: preferences ?? this.preferences,
    alert: alert ?? this.alert,
  );
}

class NotificationInboxController
    extends StateNotifier<NotificationInboxState> {
  NotificationInboxController(
    this.api, {
    this.onBusinessChange,
    this.onAccountChange,
  }) : super(const NotificationInboxState());
  final ApiService api;
  final void Function()? onBusinessChange;
  final Future<void> Function()? onAccountChange;
  CancelToken? _streamCancel;
  Timer? _retry;
  Timer? _fallback;
  bool _foreground = false;
  int _streamGeneration = 0, _fetchGeneration = 0, _page = 0, _attempt = 0;
  int? _revision;
  int? _highWater;
  int _alertSequence = 0;
  Future<void>? _refreshing;

  void resume() {
    if (_foreground) return;
    _foreground = true;
    unawaited(onAccountChange?.call() ?? Future<void>.value());
    unawaited(refresh());
    unawaited(_connect());
    // Independent recovery if a proxy silently buffers/drops SSE. This timer
    // runs only while foregrounded; normal updates still arrive through SSE.
    _fallback = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_syncLive()),
    );
  }

  void pause() {
    _foreground = false;
    _streamGeneration++;
    _streamCancel?.cancel();
    _retry?.cancel();
    _fallback?.cancel();
    if (mounted) state = state.copyWith(connected: false);
  }

  Future<void> _connect() async {
    if (!mounted || !_foreground) return;
    final generation = ++_streamGeneration;
    _streamCancel?.cancel();
    final cancel = CancelToken();
    _streamCancel = cancel;
    try {
      final response = await api.openNotificationStream(cancel);
      if (!mounted || !_foreground || generation != _streamGeneration) return;
      await for (final _ in decodeNotificationStream(response.data!.stream)) {
        if (!mounted || !_foreground || generation != _streamGeneration) return;
        _attempt = 0;
        state = state.copyWith(connected: true);
        // Always refresh on resync frames: persistence is authoritative, including
        // transactions whose IDs were allocated before a later commit.
        await _syncLive();
      }
    } catch (_) {
      // Inbox data stays visible. HTTP 401 handling belongs to ApiService.
    } finally {
      if (mounted && _foreground && generation == _streamGeneration) {
        state = state.copyWith(connected: false);
        final seconds = [3, 5, 10, 20, 30][_attempt.clamp(0, 4)];
        _attempt++;
        _retry = Timer(Duration(seconds: seconds), () => unawaited(_connect()));
      }
    }
  }

  Future<void> _syncLive() async {
    // A signal received during an older fetch must cause a subsequent fetch;
    // otherwise a successfully delivered live event could be coalesced away.
    final pending = _refreshing;
    if (pending != null) await pending;
    if (mounted && _foreground) await refresh(live: true);
  }

  Future<void> refresh({bool live = false}) {
    if (_refreshing != null) return _refreshing!;
    final future = _refresh(live: live);
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<void> _refresh({required bool live}) async {
    final generation = _fetchGeneration;
    final filter = state.filter;
    if (_highWater == null) state = state.copyWith(loading: true);
    try {
      final responses = await Future.wait([
        api.getNotifications(filter: filter),
        api.getNotificationSnapshot(),
        if (filter != 'ALL') api.getNotifications(),
      ]);
      if (!mounted || generation != _fetchGeneration) return;
      final page = responses[0].data as Map<String, dynamic>;
      final snapshot = responses[1].data as Map<String, dynamic>;
      final all =
          (filter == 'ALL' ? page : responses[2].data) as Map<String, dynamic>;
      final latest = (all['content'] as List)
          .map((j) => InboxNotification.fromJson(j as Map<String, dynamic>))
          .toList();
      final prefs = NotificationSettings.fromJson(
        snapshot['preferences'] as Map<String, dynamic>,
      );
      final revision = (snapshot['revision'] as num).toInt();
      final oldHighWater = _highWater;
      final incoming = oldHighWater == null
          ? <InboxNotification>[]
          : latest.where((n) => n.id > oldHighWater).toList();
      final alerts = incoming
          .where((n) => n.unread && prefs.allows(n.category))
          .toList();
      if (latest.isNotEmpty) {
        final maxId = latest.map((n) => n.id).reduce((a, b) => a > b ? a : b);
        _highWater = maxId > (_highWater ?? 0) ? maxId : _highWater;
      }
      _highWater ??= 0;
      if (_revision != null && (revision != _revision || incoming.isNotEmpty)) {
        onBusinessChange?.call();
      }
      _revision = revision;
      _page = 0;
      state = state.copyWith(
        items: (page['content'] as List)
            .map((j) => InboxNotification.fromJson(j as Map<String, dynamic>))
            .toList(),
        unreadCount: (snapshot['unreadCount'] as num).toInt(),
        loading: false,
        loadingMore: false,
        hasMore: !(page['last'] as bool? ?? true),
        preferences: prefs,
        alert: live && _foreground && alerts.isNotEmpty
            ? NotificationAlert(++_alertSequence, alerts.first, alerts.length)
            : null,
      );
      if (incoming.any((n) => n.type == 'CREATOR_DECISION')) {
        await onAccountChange?.call();
      }
    } catch (_) {
      if (mounted && generation == _fetchGeneration) {
        state = state.copyWith(
          loading: false,
          error:
              'Could not refresh notifications. Check your connection and try again.',
        );
      }
    }
  }

  Future<void> changeFilter(String filter) async {
    if (filter == state.filter) return;
    _fetchGeneration++;
    state = state.copyWith(
      filter: filter,
      items: [],
      loading: true,
      hasMore: false,
    );
    final pending = _refreshing;
    if (pending != null) await pending;
    if (mounted) await refresh();
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.loading) return;
    final generation = _fetchGeneration;
    final next = _page + 1;
    state = state.copyWith(loadingMore: true);
    try {
      final response = await api.getNotifications(
        filter: state.filter,
        page: next,
      );
      if (!mounted || generation != _fetchGeneration) return;
      final data = response.data as Map<String, dynamic>;
      final merged = {for (final n in state.items) n.id: n};
      for (final j in data['content'] as List) {
        final n = InboxNotification.fromJson(j as Map<String, dynamic>);
        merged[n.id] = n;
      }
      _page = next;
      state = state.copyWith(
        items: merged.values.toList(),
        loadingMore: false,
        hasMore: !(data['last'] as bool? ?? true),
      );
    } catch (_) {
      if (mounted && generation == _fetchGeneration) {
        state = state.copyWith(
          loadingMore: false,
          error: 'Could not load older notifications.',
        );
      }
    }
  }

  Future<void> _mutate(Future<dynamic> Function() action) async {
    if (state.busy) throw StateError('Please wait for the current change.');
    state = state.copyWith(busy: true);
    try {
      await action();
      final pending = _refreshing;
      if (pending != null) await pending;
      if (mounted) await refresh();
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> markRead(InboxNotification n, bool read) =>
      _mutate(() => api.setNotificationRead(n.id, read));
  Future<void> archive(InboxNotification n, bool archived) =>
      _mutate(() => api.setNotificationArchived(n.id, archived));
  Future<void> readAll() => _mutate(api.markAllNotificationsRead);
  Future<void> saveSettings(NotificationSettings settings) =>
      _mutate(() => api.saveNotificationPreferences(settings.toJson()));
  @override
  void dispose() {
    pause();
    _fetchGeneration++;
    super.dispose();
  }
}

final notificationInboxProvider =
    StateNotifierProvider.autoDispose<
      NotificationInboxController,
      NotificationInboxState
    >((ref) {
      // Token changes dispose the old connection and all user-specific state.
      ref.watch(authProvider.select((a) => (a.token, a.pid)));
      final controller = NotificationInboxController(
        ref.read(apiServiceProvider),
        onBusinessChange: () {
          ref.invalidate(myPromotionsProvider);
          ref.invalidate(notificationPromotionProvider);
          ref.invalidate(influencerRequestsProvider);
          ref.invalidate(myAccountsProvider);
          ref.invalidate(approvedAccountsProvider);
          ref.invalidate(accountDetailProvider);
          ref.invalidate(profileProvider);
          ref.invalidate(adminAccountsProvider);
          ref.invalidate(adminPromotionsProvider);
          ref.invalidate(adminUsersProvider);
          ref.invalidate(adminUsersByRoleProvider);
        },
        onAccountChange: () => ref.read(authProvider).isAdmin
            ? Future<void>.value()
            : ref.read(authProvider.notifier).refreshAccountRoles(),
      );
      return controller;
    });
