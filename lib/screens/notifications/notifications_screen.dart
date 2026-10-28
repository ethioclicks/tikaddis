import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/notification_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_toast.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  Future<void> _action(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        AppToast.error(
          context,
          'Could not save this change. Please try again.',
        );
      }
    }
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    InboxNotification item,
  ) async {
    final auth = ref.read(authProvider);
    if (item.unread) {
      try {
        await ref.read(notificationInboxProvider.notifier).markRead(item, true);
      } catch (_) {
        if (context.mounted) {
          AppToast.error(context, 'Could not mark this notification as read.');
        }
      }
    }
    if (!context.mounted) return;
    final destination = notificationRoute(
      item,
      isAdmin: auth.isAdmin,
      isInfluencer: auth.isInfluencer,
    );
    if (destination != null) context.push(destination);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationInboxProvider);
    final controller = ref.read(notificationInboxProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Notification preferences',
            icon: const Icon(Icons.tune),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _PreferencesSheet(),
            ),
          ),
          if (state.unreadCount > 0)
            IconButton(
              tooltip: 'Mark all read',
              icon: const Icon(Icons.done_all),
              onPressed: state.busy
                  ? null
                  : () => _action(context, controller.readAll),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${state.unreadCount} unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.connected
                        ? 'Live updates connected'
                        : 'Connecting to live updates · pull down to refresh',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final filter in const ['ALL', 'UNREAD', 'ARCHIVED'])
                  ChoiceChip(
                    label: Text(switch (filter) {
                      'ALL' => 'All',
                      'UNREAD' => 'Unread',
                      _ => 'Archived',
                    }),
                    selected: state.filter == filter,
                    onSelected: state.busy
                        ? null
                        : (_) => controller.changeFilter(filter),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Text(
                      state.error!,
                      style: const TextStyle(color: AppColors.neutral600),
                    ),
                    TextButton.icon(
                      onPressed: () => controller.refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.items.isEmpty && state.error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 64),
                child: Column(
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      size: 54,
                      color: AppColors.neutral500,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      switch (state.filter) {
                        'UNREAD' => 'You’re all caught up',
                        'ARCHIVED' => 'No archived notifications',
                        _ => 'No notifications yet',
                      },
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your real account and promotion updates appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              for (final item in state.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: item.unread
                        ? AppColors.primary.withValues(alpha: .06)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.neutral200),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: state.busy
                          ? null
                          : () => _open(context, ref, item),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(switch (item.category) {
                              'PROMOTIONS' => Icons.campaign_outlined,
                              'CHANNELS' => Icons.storefront_outlined,
                              _ => Icons.person_outline,
                            }, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: item.unread
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.body,
                                    style: const TextStyle(
                                      color: AppColors.neutral700,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _time(item.createdAt),
                                    style: const TextStyle(
                                      color: AppColors.neutral500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              enabled: !state.busy,
                              tooltip: 'Manage notification',
                              onSelected: (action) => _action(
                                context,
                                () => action == 'read'
                                    ? controller.markRead(item, item.unread)
                                    : controller.archive(item, !item.archived),
                              ),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'read',
                                  child: Text(
                                    item.unread
                                        ? 'Mark as read'
                                        : 'Mark as unread',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text(
                                    item.archived
                                        ? 'Restore to inbox'
                                        : 'Archive',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            if (state.hasMore)
              OutlinedButton(
                onPressed: state.loadingMore ? null : controller.loadMore,
                child: Text(
                  state.loadingMore ? 'Loading…' : 'Load older notifications',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime at) {
    final local = at.toLocal();
    final ago = DateTime.now().difference(at);
    if (ago.inSeconds < 60) return 'Just now';
    if (ago.inMinutes < 60) return '${ago.inMinutes} min ago';
    if (ago.inHours < 24) return '${ago.inHours} hr ago';
    return '${Fmt.date(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _PreferencesSheet extends ConsumerWidget {
  const _PreferencesSheet();
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings settings,
  ) async {
    try {
      await ref.read(notificationInboxProvider.notifier).saveSettings(settings);
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'Could not save notification preferences.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationInboxProvider);
    final p = state.preferences;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notification preferences',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the live alerts shown while you use the app. All updates remain in your inbox.',
              ),
              SwitchListTile(
                title: const Text('Live in-app alerts'),
                value: p.liveAlerts,
                onChanged: state.busy
                    ? null
                    : (v) => _save(context, ref, p.copyWith(liveAlerts: v)),
              ),
              SwitchListTile(
                title: const Text('Promotions'),
                value: p.promotionAlerts,
                onChanged: state.busy
                    ? null
                    : (v) =>
                          _save(context, ref, p.copyWith(promotionAlerts: v)),
              ),
              SwitchListTile(
                title: const Text('Channels'),
                value: p.channelAlerts,
                onChanged: state.busy
                    ? null
                    : (v) => _save(context, ref, p.copyWith(channelAlerts: v)),
              ),
              SwitchListTile(
                title: const Text('Account updates'),
                value: p.accountAlerts,
                onChanged: state.busy
                    ? null
                    : (v) => _save(context, ref, p.copyWith(accountAlerts: v)),
              ),
              const SizedBox(height: 8),
              const Text(
                'These controls manage in-app alerts. Phone push alerts while the app is closed are not enabled.',
                style: TextStyle(color: AppColors.neutral500, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
