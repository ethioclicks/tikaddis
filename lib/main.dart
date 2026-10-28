import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'widgets/notification_coordinator.dart';

void main() {
  runApp(const ProviderScope(child: EthioPromoApp()));
}

class EthioPromoApp extends ConsumerWidget {
  const EthioPromoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Tikaddis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: _AppScrollBehavior(),
      routerConfig: router,
      builder: (context, child) =>
          NotificationCoordinator(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Hides scrollbars and removes the overscroll glow (which can leave a stray
/// edge sliver on some devices/emulators). Enables mouse+touch dragging.
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
