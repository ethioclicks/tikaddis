import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// Notifications list. Branded navy header (matching the detail screens),
/// grouped Today / Earlier, compact borderless rows with unread accents.
/// Currently shows demo data.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static final _items = <_Notif>[
    _Notif(
      icon: Icons.verified_rounded,
      tint: AppColors.primary,
      title: 'Promotion approved',
      body: 'Your request to “Addis Tech” was approved and is now running.',
      time: '2h ago',
      unread: true,
      today: true,
    ),
    _Notif(
      icon: Icons.campaign_rounded,
      tint: AppColors.accent,
      title: 'New promotion request',
      body: 'Abebe Kebede sent you a promotion request for 3 days.',
      time: '5h ago',
      unread: true,
      today: true,
    ),
    _Notif(
      icon: Icons.account_circle_rounded,
      tint: AppColors.primary,
      title: 'Welcome to Tikaddis 🎉',
      body: 'Your account is ready. Start by browsing creators.',
      time: 'Yesterday',
      unread: false,
      today: false,
    ),
    _Notif(
      icon: Icons.payments_rounded,
      tint: Color(0xFF047857),
      title: 'Promotion fulfilled',
      body: 'Your campaign with “Mereja News” was marked fulfilled.',
      time: '3 days ago',
      unread: false,
      today: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final today = _items.where((n) => n.today).toList();
    final earlier = _items.where((n) => !n.today).toList();
    final unreadCount = _items.where((n) => n.unread).length;

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Header: a top control row (back + mark all read) then the big
          // left-aligned title on its own line.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 6,
                left: 8,
                right: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.neutral900),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      if (unreadCount > 0)
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            textStyle: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Mark all read'),
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 2, 0, 10),
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.neutral900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList.list(
                children: [
                  if (today.isNotEmpty) ...[
                    const _SectionLabel('Today'),
                    ...today.map((n) => _NotifRow(n: n)),
                  ],
                  if (earlier.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const _SectionLabel('Earlier'),
                    ...earlier.map((n) => _NotifRow(n: n)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.neutral500,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Compact, borderless notification row. Unread rows get a faint tint + dot.
class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.n});
  final _Notif n;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: n.unread
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: n.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(n.icon, color: n.tint, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  n.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutral600,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                n.time,
                style: const TextStyle(
                  color: AppColors.neutral500,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              if (n.unread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.neutral100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: AppColors.neutral500, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(
              color: AppColors.neutral900,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "We'll let you know when something happens.",
            style: TextStyle(color: AppColors.neutral500, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _Notif {
  const _Notif({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
    required this.today,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;
  final String time;
  final bool unread;
  final bool today;
}
