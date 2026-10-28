import '../../widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/hex_pattern.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final name = auth.firstName?.trim().isNotEmpty == true
        ? auth.firstName!.trim()
        : 'there';
    final myPromos = ref.watch(myPromotionsProvider(null));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(myPromotionsProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(name: name, roles: auth.roles),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _StatsRow(
                      total: myPromos.maybeWhen(
                        data: (l) => l.length,
                        orElse: () => null,
                      ),
                      running: myPromos.maybeWhen(
                        data: (l) => l
                            .where(
                              (p) =>
                                  p.status?.wire == 'RUNNING' ||
                                  p.status?.wire == 'ACCOUNT_OWNER_APPROVED',
                            )
                            .length,
                        orElse: () => null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle('Quick actions'),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.search_rounded,
                      color: AppColors.primary,
                      title: 'Browse creators',
                      subtitle: 'Find channels to promote your business',
                      onTap: () => context.go('/browse'),
                    ),
                    _ActionCard(
                      icon: Icons.campaign_rounded,
                      color: AppColors.accent,
                      title: 'My promotions',
                      subtitle: 'Track the requests you have sent',
                      onTap: () => context.go('/my-promotions'),
                    ),
                    if (auth.isInfluencer)
                      _ActionCard(
                        icon: Icons.storefront_rounded,
                        color: AppColors.primaryHover,
                        title: 'Creator space',
                        subtitle: 'Manage channels and incoming requests',
                        onTap: () => context.go('/browse'),
                      )
                    else
                      _ActionCard(
                        icon: Icons.star_rounded,
                        color: AppColors.accentHover,
                        title: 'Become a creator',
                        subtitle: 'List your channels and earn',
                        onTap: () => context.go('/profile'),
                      ),
                    const SizedBox(height: 24),
                    _RecentPromotions(async: myPromos),
                    const SizedBox(height: 90), // clear floating nav
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

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.roles});
  final String name;
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: HexBackground(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        opacity: 0.1,
        radius: 44,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            MediaQuery.of(context).padding.top + 22,
            22,
            48,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hi, $name 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const NotificationBell(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.total, required this.running});
  final int? total;
  final int? running;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: total?.toString() ?? '—',
            label: 'Promotions',
            icon: Icons.campaign_outlined,
            tint: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: running?.toString() ?? '—',
            label: 'Active',
            icon: Icons.bolt_outlined,
            tint: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.tint,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: tint),
              ),
              const Spacer(),
              // Thin accent tick for a sharper, dashboard-y feel.
              Container(
                width: 22,
                height: 4,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.neutral500,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentPromotions extends StatelessWidget {
  const _RecentPromotions({required this.async});
  final AsyncValue async;

  @override
  Widget build(BuildContext context) {
    return async.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final recent = (list as List).take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle('Recent promotions'),
                TextButton(
                  onPressed: () => context.go('/my-promotions'),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...recent.map((r) => _MiniPromo(request: r)),
            const SizedBox(height: 12),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MiniPromo extends StatelessWidget {
  const _MiniPromo({required this.request});
  final dynamic request;

  @override
  Widget build(BuildContext context) {
    final account = request.influencerAccount;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Icon(
            Fmt.platformIcon(account?.accountType),
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              account?.title ?? 'Creator',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.neutral900,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          StatusBadge(status: request.status),
        ],
      ),
    );
  }
}
