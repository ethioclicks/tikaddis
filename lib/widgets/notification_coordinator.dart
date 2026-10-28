import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import 'app_toast.dart';

/// One stream per signed-in app session. Pause background network work and
/// dispose all inbox state when the authenticated identity changes.
class NotificationCoordinator extends ConsumerStatefulWidget {
  const NotificationCoordinator({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<NotificationCoordinator> createState() =>
      _NotificationCoordinatorState();
}

class _NotificationCoordinatorState
    extends ConsumerState<NotificationCoordinator>
    with WidgetsBindingObserver {
  bool _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      if (ref.read(authProvider).isLoggedIn) {
        ref.read(notificationInboxProvider.notifier).resume();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _active = false;
      ref.read(notificationInboxProvider.notifier).pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider.select((a) => (a.token, a.pid)));
    final controller = ref.watch(notificationInboxProvider.notifier);
    ref.listen(notificationInboxProvider.select((s) => s.alert), (
      previous,
      next,
    ) {
      if (next == null || previous?.sequence == next.sequence || !_active) {
        return;
      }
      final session = ref.read(authProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_active) return;
        final current = ref.read(authProvider);
        if (!current.isLoggedIn ||
            current.token != session.token ||
            current.pid != session.pid) {
          return;
        }
        AppToast.info(
          context,
          next.count > 1
              ? '${next.count} new notifications. ${next.item.title}'
              : next.item.title,
        );
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (auth.$1 != null &&
          auth.$2 != null &&
          _active &&
          identical(ref.read(notificationInboxProvider.notifier), controller)) {
        controller.resume();
      }
    });
    return widget.child;
  }
}
