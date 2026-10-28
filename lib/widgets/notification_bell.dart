import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.color = AppColors.primary});
  final Color color;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      notificationInboxProvider.select((s) => s.unreadCount),
    );
    final admin = ref.watch(authProvider.select((s) => s.isAdmin));
    return IconButton(
      tooltip: count == 0 ? 'Notifications' : '$count unread notifications',
      onPressed: () =>
          context.push(admin ? '/admin/notifications' : '/notifications'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: AppColors.accent,
        child: Icon(Icons.notifications_outlined, color: color),
      ),
    );
  }
}
