import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/creator_profile_card.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/platform_logo.dart';
import '../../widgets/sparkle.dart';

const Color _ink = Color(0xFF111111);

/// Home. Same design language as the launch and sign-in screens: a blue
/// gradient header that fades into a clean white page, soft grey rows and
/// one bold black primary action.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final myPromos = ref.watch(myPromotionsProvider(null));
    final isCreator = auth.isInfluencer || auth.roles.contains('CANDIDATE');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(myPromotionsProvider);
            ref.invalidate(profileProvider);
            ref.invalidate(myAccountsProvider);
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const _Header(),
              Transform.translate(
                offset: const Offset(0, -46),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Creators see their public profile, LinkedIn style;
                      // everyone else sees their promotion numbers.
                      if (isCreator)
                        const _CreatorSection()
                      else
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
                                      p.status?.wire ==
                                          'ACCOUNT_OWNER_APPROVED',
                                )
                                .length,
                            orElse: () => null,
                          ),
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      height: top + 160,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppGradients.hero),
      child: Stack(
        children: [
          Positioned(
            top: top + 70,
            right: 30,
            child: const Sparkle(size: 28, color: Colors.white),
          ),
          Positioned(
            top: top + 100,
            right: 76,
            child: const Sparkle(size: 14, color: AppColors.accentLight),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, top + 14, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(logoHeight: 34, fontSize: 19),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const NotificationBell(),
                    ),
                  ],
                ),
              ],
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
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryHover.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.neutral500,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _ink,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
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
              children: [
                const Expanded(child: _SectionTitle('Recent promotions')),
                TextButton(
                  onPressed: () => context.go('/my-promotions'),
                  child: const Text(
                    'See all',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: PlatformLogo(account?.accountType, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              account?.title ?? 'Creator',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
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

/// The creator's own public profile (what brands see), with their channels
/// underneath. Shown on Home for approved and pending creators.
class _CreatorSection extends ConsumerWidget {
  const _CreatorSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = ref.watch(profileProvider);
    final channels = ref.watch(myAccountsProvider);
    final pending = !auth.isInfluencer;

    final list = channels.maybeWhen(
      data: (l) => l.where((c) => c.accountPublicId != null).toList(),
      orElse: () => const <InfluencerAccount>[],
    );
    final audience = list.fold<int>(0, (sum, c) => sum + c.audienceCount);

    // Two headline numbers on top.
    final statsRow = Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${list.length}',
            label: list.length == 1 ? 'Channel' : 'Channels',
            icon: Icons.storefront_outlined,
            tint: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: Fmt.compact(audience),
            label: 'Total audience',
            icon: Icons.group_outlined,
            tint: AppColors.accent,
          ),
        ),
      ],
    );

    // Richer details for the profile card, drawn from the creator's channels.
    final topPost = list.fold<int>(
      0,
      (m, c) => (c.topViewedPost?.count ?? 0) > m ? c.topViewedPost!.count : m,
    );
    final bestReach = list.fold<int>(
      0,
      (m, c) => c.maxViewPerPostCount > m ? c.maxViewPerPostCount : m,
    );
    final prices = list.map((c) => c.lowestCost).whereType<double>().toList();
    final fromPrice = prices.isEmpty
        ? null
        : prices.reduce((a, b) => a < b ? a : b);
    final highlights = [
      if (topPost > 0)
        ProfileStat(
          Fmt.compact(topPost),
          'Top post',
          icon: Icons.visibility_outlined,
        ),
      if (bestReach > 0)
        ProfileStat(
          Fmt.compact(bestReach),
          'Best reach',
          icon: Icons.trending_up_rounded,
        ),
      if (fromPrice != null)
        ProfileStat(
          Fmt.birr(fromPrice),
          'From',
          icon: Icons.payments_outlined,
        ),
    ];

    final platformsSeen = <String>{};
    final categoriesSeen = <String>{};
    final chips = <ProfileChip>[];
    for (final c in list) {
      final t = c.accountType;
      if (t != null && platformsSeen.add(t.wire)) {
        chips.add(
          ProfileChip(
            t.label,
            leading: PlatformLogo(t, size: 14, color: Fmt.platformColor(t)),
          ),
        );
      }
    }
    for (final c in list) {
      final name = c.category?.categoryName;
      if (name != null && name.isNotEmpty && categoriesSeen.add(name)) {
        if (categoriesSeen.length > 3) break;
        chips.add(
          ProfileChip(
            name,
            leading: const Icon(
              Icons.sell_outlined,
              size: 14,
              color: AppColors.neutral500,
            ),
          ),
        );
      }
    }

    final badge = pending
        ? const _StatusChip(
            text: 'Pending approval',
            bg: Color(0xFFFFF7ED),
            fg: AppColors.accentHover,
            icon: Icons.schedule_rounded,
          )
        : const _StatusChip(
            text: 'Creator',
            bg: Color(0xFFEFF6FF),
            fg: AppColors.primary,
            icon: Icons.verified_rounded,
          );

    final card = profile.when(
      loading: () => const _ProfileSkeleton(),
      error: (e, _) => CreatorProfileCard(
        name: auth.displayName,
        style: CreatorCardStyle.gradient,
        badge: badge,
        chips: chips,
        stats: highlights,
        onEdit: () => context.push('/creator-profile'),
        emptyHint: 'Could not load your profile. Pull down to retry.',
      ),
      data: (p) => CreatorProfileCard(
        name: p.fullName.isNotEmpty ? p.fullName : auth.displayName,
        headline: p.headline,
        biography: p.biography,
        avatarUrl: p.profileImageUrl,
        gallery: p.galleryImages,
        style: CreatorCardStyle.gradient,
        chips: chips,
        stats: highlights,
        badge: badge,
        onEdit: () => context.push('/creator-profile'),
        emptyHint:
            'Add a short biography so brands know who you are. Tap Edit.',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        statsRow,
        const SizedBox(height: 16),
        card,
        if (auth.isInfluencer) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Your channels'),
          const SizedBox(height: 12),
          channels.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => const Text(
              'Could not load your channels.',
              style: TextStyle(color: AppColors.neutral500),
            ),
            data: (_) => list.isEmpty
                ? const Text(
                    'No channels yet. Add your first channel so brands can find you.',
                    style: TextStyle(color: AppColors.neutral500, height: 1.4),
                  )
                : Column(
                    children: [for (final c in list) _ChannelRow(account: c)],
                  ),
          ),
        ],
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final color = Fmt.platformColor(account.accountType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/channel/${account.accountPublicId}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: AppImage(
                      account.imageURL,
                      fallback: Container(
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: PlatformLogo(
                          account.accountType,
                          size: 20,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.title ?? 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${account.accountType?.label ?? 'Channel'} · ${Fmt.compact(account.audienceCount)} audience',
                        style: const TextStyle(
                          color: AppColors.neutral500,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  text: account.approved ? 'Approved' : 'Pending',
                  bg: account.approved
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFF7ED),
                  fg: account.approved
                      ? const Color(0xFF047857)
                      : AppColors.accentHover,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
  });
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Text(
          text,
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 280,
    decoration: BoxDecoration(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(24),
    ),
    alignment: Alignment.center,
    child: const CircularProgressIndicator(strokeWidth: 2),
  );
}
