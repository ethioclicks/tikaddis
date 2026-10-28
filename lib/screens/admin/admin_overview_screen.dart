import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/hex_pattern.dart';
import '../../widgets/notification_bell.dart';

/// Admin landing: at-a-glance counts of what needs attention + logout.
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAccounts = ref.watch(adminAccountsProvider('DISAPPROVED'));
    final requested = ref.watch(adminPromotionsProvider('REQUESTED'));
    final users = ref.watch(adminUsersProvider);
    final name = ref.watch(authProvider).firstName ?? 'Admin';

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(adminAccountsProvider);
          ref.invalidate(adminPromotionsProvider);
          ref.invalidate(adminUsersProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: HexBackground(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                opacity: 0.1,
                radius: 44,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 20,
                    20,
                    40,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin',
                              style: TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hi, $name',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const NotificationBell(color: Colors.white),
                      IconButton(
                        tooltip: 'Log out',
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.storefront_outlined,
                            tint: AppColors.accent,
                            label: 'Pending channels',
                            value: pendingAccounts.maybeWhen(
                              data: (l) => l.length.toString(),
                              orElse: () => '—',
                            ),
                            onTap: () => context.go('/admin/channels'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.campaign_outlined,
                            tint: AppColors.primary,
                            label: 'New requests',
                            value: requested.maybeWhen(
                              data: (l) => l.length.toString(),
                              orElse: () => '—',
                            ),
                            onTap: () => context.go('/admin/promotions'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _NavTile(
                      icon: Icons.storefront_rounded,
                      title: 'Review channels',
                      subtitle: 'Approve or disapprove influencer channels',
                      onTap: () => context.go('/admin/channels'),
                    ),
                    _NavTile(
                      icon: Icons.campaign_rounded,
                      title: 'Promotion requests',
                      subtitle: 'Approve, reject, run and fulfill promotions',
                      onTap: () => context.go('/admin/promotions'),
                    ),
                    _NavTile(
                      icon: Icons.people_rounded,
                      title: 'Users',
                      subtitle: users.maybeWhen(
                        data: (l) => '${l.length} users · approve creators',
                        orElse: () => 'Manage users and creators',
                      ),
                      onTap: () => context.go('/admin/users'),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.neutral500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.neutral900,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.neutral500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.neutral300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
