import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

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
                          data: (l) => l.length, orElse: () => null),
                      running: myPromos.maybeWhen(
                          data: (l) => l
                              .where((p) =>
                                  p.status?.wire == 'RUNNING' ||
                                  p.status?.wire == 'ACCOUNT_OWNER_APPROVED')
                              .length,
                          orElse: () => null),
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
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 20, 20, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryHover, AppColors.primary],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hi, $name 👋',
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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.neutral900,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
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
                Icon(Icons.chevron_right, color: AppColors.neutral300),
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
          Icon(Fmt.platformIcon(account?.accountType),
              size: 20, color: AppColors.primary),
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
